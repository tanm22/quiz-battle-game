package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/coins"
	pb "quiz-battle/proto"
)

// Referral reward amounts. Source: legacy in-line constants from before
// the ledger refactor; kept here so PR 2's earn-event payloads can reuse
// the same numbers without further drift.
const (
	referralReferrerCoins int64 = 100
	referralRefereeCoins  int64 = 50
)

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
		return fmt.Errorf("decode payload: %w", err)
	}
	if event.ReferrerID == "" || event.RefereeID == "" {
		return fmt.Errorf("missing referrerId or refereeId: %+v", event)
	}

	var ref struct {
		ID            string `bson:"_id"`
		RewardGranted bool   `bson:"rewardGranted"`
	}
	err := s.mongoDB.Collection("referrals").FindOne(ctx, bson.M{"refereeId": event.RefereeID}).Decode(&ref)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			log.Printf("[referral-consumer] skip — no referral row for refereeId=%s", event.RefereeID)
			return nil
		}
		return fmt.Errorf("load referral: %w", err)
	}
	if ref.RewardGranted {
		log.Printf("[referral-consumer] skip — already granted: %s", ref.ID)
		return nil
	}

	if _, err := s.ledger.Grant(ctx, event.ReferrerID, referralReferrerCoins,
		coins.ReasonReferralReferrer, "referral:"+ref.ID+":referrer", nil); err != nil {
		return fmt.Errorf("grant referrer: %w", err)
	}
	if _, err := s.ledger.Grant(ctx, event.RefereeID, referralRefereeCoins,
		coins.ReasonReferralReferee, "referral:"+ref.ID+":referee", nil); err != nil {
		return fmt.Errorf("grant referee: %w", err)
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
		log.Printf("[referral-consumer] publish notif failed: %v", err)
	}
	log.Printf("[referral-consumer] referral converted: %s referred %s, coins granted via ledger",
		event.ReferrerID, event.RefereeID)
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
