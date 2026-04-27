package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/coins"
	"quiz-battle/pkg/log"
	pb "quiz-battle/proto"
)

// Referral reward amounts. Source: legacy in-line constants from before
// the ledger refactor; kept here so PR 2's earn-event payloads can reuse
// the same numbers without further drift.
const (
	referralReferrerCoins int64 = 100
	referralRefereeCoins  int64 = 50
)

// errBadReferralPayload marks unrecoverable parse / shape errors on a
// referral message so the consumer can dead-letter it instead of looping
// the same broken payload forever.
var errBadReferralPayload = errors.New("bad referral payload")

// GetCoinBalance returns the authenticated user's cached balance from
// users.coins. The cache is kept consistent with coin_ledger by every
// Grant's transaction (ADR-0001), so this is a single-document read.
func (s *scoringServer) GetCoinBalance(ctx context.Context, _ *pb.GetCoinBalanceRequest) (*pb.GetCoinBalanceResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	bal, err := s.ledger.GetBalance(ctx, userID)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		return nil, status.Errorf(codes.Internal, "load balance: %v", err)
	}
	return &pb.GetCoinBalanceResponse{Balance: bal}, nil
}

// handleReferralEvent processes one referral.applied / first-quiz-completed
// message. Coin grants flow through pkg/coins.Ledger.Grant for the §4.3
// invariant (no balance change without a ledger row); the referrals row is
// flipped to "converted" AFTER both grants succeed so that a crash between
// the two retries safely (Grant is idempotent on (userId, refId, reason)).
//
// Concurrent / redelivered messages are safe: both grants short-circuit on
// the unique index, and the rewardGranted flag deduplicates the notification
// publish (best-effort — a rare double-publish is preferable to a missed one).
func (s *scoringServer) handleReferralEvent(ctx context.Context, body []byte) error {
	var event struct {
		ReferrerID  string `json:"referrerId"`
		RefereeID   string `json:"refereeId"`
		RefereeName string `json:"refereeName"`
	}
	if err := json.Unmarshal(body, &event); err != nil {
		return fmt.Errorf("%w: decode: %v", errBadReferralPayload, err)
	}
	if event.ReferrerID == "" || event.RefereeID == "" {
		return fmt.Errorf("%w: missing referrerId or refereeId: %+v", errBadReferralPayload, event)
	}

	var ref struct {
		ID            string `bson:"_id"`
		RewardGranted bool   `bson:"rewardGranted"`
	}
	err := s.mongoDB.Collection("referrals").FindOne(ctx, bson.M{"refereeId": event.RefereeID}).Decode(&ref)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			log.FromContext(ctx).Info("skip — no referral row",
				"consumer", "referral", "referee_id", event.RefereeID)
			return nil
		}
		return fmt.Errorf("load referral: %w", err)
	}
	if ref.RewardGranted {
		log.FromContext(ctx).Info("skip — already granted",
			"consumer", "referral", "referral_id", ref.ID)
		return nil
	}

	// §4.3: publish to the unified earn pipeline instead of calling
	// Grant directly. The earn-consumer in this same service drains
	// coin-earn-queue and writes the ledger row + balance update via
	// Ledger.Grant. RefIDs are stable across redeliveries so a duplicate
	// publish (e.g. retried after rewardGranted flip failed) is a no-op
	// at the consumer's unique-index check.
	publishEarn := func(source string, ev coins.EarnEvent) error {
		ev.Event = coins.EarnRoutingKey(source)
		body, err := json.Marshal(ev)
		if err != nil {
			return fmt.Errorf("marshal %s: %w", ev.Event, err)
		}
		if err := s.publish(ctx, ev.Event, body); err != nil {
			return fmt.Errorf("publish %s: %w", ev.Event, err)
		}
		return nil
	}
	if err := publishEarn(coins.EarnSourceReferralReferrer, coins.EarnEvent{
		UserID: event.ReferrerID,
		Amount: referralReferrerCoins,
		Reason: coins.ReasonReferralReferrer,
		RefID:  "referral:" + ref.ID + ":referrer",
	}); err != nil {
		return err
	}
	if err := publishEarn(coins.EarnSourceReferralReferee, coins.EarnEvent{
		UserID: event.RefereeID,
		Amount: referralRefereeCoins,
		Reason: coins.ReasonReferralReferee,
		RefID:  "referral:" + ref.ID + ":referee",
	}); err != nil {
		return err
	}

	if _, err := s.mongoDB.Collection("referrals").UpdateOne(ctx,
		bson.M{"_id": ref.ID},
		bson.M{"$set": bson.M{
			"status":        "converted",
			"rewardGranted": true,
			"convertedAt":   time.Now(),
		}},
	); err != nil {
		return fmt.Errorf("flip referral status: %w", err)
	}

	notifJSON, _ := json.Marshal(map[string]interface{}{
		"event":       "notif.referral.converted",
		"userId":      event.ReferrerID,
		"refereeName": event.RefereeName,
		"coinsEarned": referralReferrerCoins,
	})
	if err := s.publish(ctx, "notif.referral.converted", notifJSON); err != nil {
		// Notification is best-effort — log and move on rather than redelivering
		// the whole message (which would re-grant via Grant's idempotency but
		// also potentially re-fire the notification twice on the next attempt).
		log.FromContext(ctx).Warn("publish notif failed",
			"consumer", "referral", "err", err)
	}
	log.FromContext(ctx).Info("referral converted; earn events published",
		"consumer", "referral", "referrer_id", event.ReferrerID, "referee_id", event.RefereeID)
	return nil
}

// GetCoinLedger returns the authenticated user's ledger entries newest-first.
// page_size is clamped to [1, 100] (default 25); page_token is the opaque
// cursor returned by the previous page. Empty next_page_token signals the
// end of history.
func (s *scoringServer) GetCoinLedger(ctx context.Context, req *pb.GetCoinLedgerRequest) (*pb.GetCoinLedgerResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	rows, next, err := s.ledger.GetLedger(ctx, userID, req.PageSize, req.PageToken)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load ledger: %v", err)
	}
	out := make([]*pb.CoinLedgerEntry, 0, len(rows))
	for _, r := range rows {
		out = append(out, &pb.CoinLedgerEntry{
			Id:              r.ID,
			Delta:           r.Delta,
			Reason:          r.Reason,
			RefId:           r.RefID,
			BalanceAfter:    r.BalanceAfter,
			CreatedAtUnixMs: r.CreatedAt.UnixMilli(),
			Metadata:        r.Metadata,
		})
	}
	return &pb.GetCoinLedgerResponse{Entries: out, NextPageToken: next}, nil
}
