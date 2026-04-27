package main

import (
	"context"
	"encoding/json"
	"errors"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"quiz-battle/pkg/log"
)

// challengeNotifOutboxCollection is the durable queue for
// notif.friend.challenge pushes. The room itself lives in Redis the
// instant ChallengeFriend's pipe.Exec returns; this outbox protects the
// fire-and-forget RabbitMQ publish from a transient broker outage.
//
// Pattern mirrors quiz/main.go's tournament_payouts drain: write a
// pending row, try the publish inline, mark processed on success.
// drainChallengeNotifOutbox retries unprocessed rows on a 30s tick.
const challengeNotifOutboxCollection = "friend_challenge_outbox"

// challengeNotifOutboxBatchSize bounds how many rows a single drain tick
// republishes. Caps the recovery blast on the publish channel after a
// long broker outage; subsequent ticks pick up the rest.
const challengeNotifOutboxBatchSize = 200

// challengeNotifOutboxTick is short on purpose: the user-visible delay
// between sending a challenge and the recipient seeing the push during
// a broker outage is bounded by this interval plus the broker's recovery
// time. 30s is a comfortable balance.
const challengeNotifOutboxTick = 30 * time.Second

// challengeNotifOutboxRow is the durable record of one pending push.
// processedAt nil → drainer will retry; non-nil → the publish landed.
type challengeNotifOutboxRow struct {
	ID           string     `bson:"_id"`
	RecipientID  string     `bson:"recipientUserId"`
	FromUserID   string     `bson:"fromUserId"`
	FromUsername string     `bson:"fromUsername"`
	RoomID       string     `bson:"roomId"`
	Attempts     int        `bson:"attempts"`
	CreatedAt    time.Time  `bson:"createdAt"`
	ProcessedAt  *time.Time `bson:"processedAt,omitempty"`
}

// enqueueChallengeNotifOutbox writes the pending row before any publish
// is attempted. Idempotent on _id: a retry through the same path would
// hit DuplicateKey and surface as success at the call site (the row is
// already queued).
func (s *scoringServer) enqueueChallengeNotifOutbox(ctx context.Context, row challengeNotifOutboxRow) error {
	_, err := s.mongoDB.Collection(challengeNotifOutboxCollection).InsertOne(ctx, row)
	if err != nil && mongo.IsDuplicateKeyError(err) {
		return nil
	}
	return err
}

// markChallengeNotifProcessed flips processedAt on a successfully
// published row so the drainer skips it. Best-effort: a failure here
// just means the drainer republishes once. The push consumer is
// idempotent on (recipientId, roomId), so duplicate FCMs are
// harmless beyond a possible double-buzz on the device.
func (s *scoringServer) markChallengeNotifProcessed(ctx context.Context, id string) error {
	now := time.Now().UTC()
	_, err := s.mongoDB.Collection(challengeNotifOutboxCollection).UpdateOne(ctx,
		bson.M{"_id": id},
		bson.M{"$set": bson.M{"processedAt": now}})
	return err
}

// drainChallengeNotifOutbox loops until ctx is cancelled, draining any
// unprocessed rows on each tick. Wired into main.go alongside the
// tournament-payout drainer.
func (s *scoringServer) drainChallengeNotifOutbox(ctx context.Context) {
	// First pass on startup so a service restart immediately reprocesses
	// rows stranded by a crash mid-publish. Subsequent passes happen on
	// the ticker.
	s.drainChallengeNotifOnce(ctx)

	ticker := time.NewTicker(challengeNotifOutboxTick)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			s.drainChallengeNotifOnce(ctx)
		}
	}
}

func (s *scoringServer) drainChallengeNotifOnce(ctx context.Context) {
	cur, err := s.mongoDB.Collection(challengeNotifOutboxCollection).Find(ctx,
		bson.M{"processedAt": nil},
		options.Find().
			SetLimit(challengeNotifOutboxBatchSize).
			SetSort(bson.D{{Key: "createdAt", Value: 1}}),
	)
	if err != nil {
		if !errors.Is(err, context.Canceled) {
			log.FromContext(ctx).Error("find pending failed",
				"component", "friends_outbox", "err", err)
		}
		return
	}
	defer cur.Close(ctx)

	for cur.Next(ctx) {
		var row challengeNotifOutboxRow
		if err := cur.Decode(&row); err != nil {
			log.FromContext(ctx).Error("decode failed",
				"component", "friends_outbox", "err", err)
			continue
		}
		s.republishChallengeNotif(ctx, row)
	}
}

func (s *scoringServer) republishChallengeNotif(ctx context.Context, row challengeNotifOutboxRow) {
	body, _ := json.Marshal(map[string]any{
		"event":        "notif.friend.challenge",
		"userId":       row.RecipientID,
		"fromUserId":   row.FromUserID,
		"fromUsername": row.FromUsername,
		"roomId":       row.RoomID,
		"outboxId":     row.ID,
	})
	if err := s.publish(ctx, "notif.friend.challenge", body); err != nil {
		// Bump the attempts counter so an operator can spot rows stuck
		// in a doom loop. The next tick will retry.
		_, _ = s.mongoDB.Collection(challengeNotifOutboxCollection).UpdateOne(ctx,
			bson.M{"_id": row.ID},
			bson.M{"$inc": bson.M{"attempts": 1}})
		log.FromContext(ctx).Warn("republish failed",
			"component", "friends_outbox", "outbox_id", row.ID, "attempts", row.Attempts+1, "err", err)
		return
	}
	if err := s.markChallengeNotifProcessed(ctx, row.ID); err != nil {
		log.FromContext(ctx).Warn("mark processed after republish failed",
			"component", "friends_outbox", "outbox_id", row.ID, "err", err)
	}
}
