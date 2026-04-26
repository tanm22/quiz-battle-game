package shop

import (
	"context"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// EffectOutboxCollection is the Mongo collection name. Exported so the seed
// binary and the consuming worker (services/payment in PR 5) can reach it
// without re-declaring the literal.
const EffectOutboxCollection = "coin_effect_outbox"

// OutboxRow durably defers a side-effect that has to fire after a successful
// purchase but lives in another service's domain. PR 4 only writes
// premium_trial rows here; PR 5 introduces the consumer in services/payment
// that drains them and extends users.planExpiresAt.
//
// The row is inserted inside Purchase.Buy's transaction so debit + outbox
// commit together: a successful Buy guarantees the effect is queued, and a
// rolled-back Buy guarantees no effect is queued. ProcessedAt is nil while
// the row is waiting and gets set once the consumer finishes its side
// effect — that flip is the consumer's idempotency point.
type OutboxRow struct {
	ID          string            `bson:"_id"`
	UserID      string            `bson:"userId"`
	Kind        string            `bson:"kind"`
	Payload     map[string]string `bson:"payload"`
	Attempts    int               `bson:"attempts"`
	ProcessedAt *time.Time        `bson:"processedAt,omitempty"`
	CreatedAt   time.Time         `bson:"createdAt"`
}

// EnqueueOutbox inserts a row inside the caller's session context. The
// caller must run inside Purchase.Buy's WithTransaction so the row commits
// atomically with the matching ledger entry. Idempotent on _id: callers
// that retry through the replay fast-path see DuplicateKey and treat it
// as success.
func EnqueueOutbox(sc context.Context, db *mongo.Database, row OutboxRow) error {
	row.CreatedAt = time.Now().UTC()
	_, err := db.Collection(EffectOutboxCollection).InsertOne(sc, row)
	return err
}

// DequeueDue returns up to `limit` unprocessed rows of the given kind,
// oldest first. The (processedAt asc, kind asc) index in seed/main.go
// makes the filter a covered scan. The consumer is expected to mark each
// row processed via MarkProcessed once its side effect succeeds.
func DequeueDue(ctx context.Context, db *mongo.Database, kind string, limit int) ([]OutboxRow, error) {
	cur, err := db.Collection(EffectOutboxCollection).Find(ctx,
		bson.M{"kind": kind, "processedAt": nil},
		options.Find().SetLimit(int64(limit)).SetSort(bson.D{{Key: "createdAt", Value: 1}}),
	)
	if err != nil {
		return nil, err
	}
	var rows []OutboxRow
	if err := cur.All(ctx, &rows); err != nil {
		return nil, err
	}
	return rows, nil
}

// MarkProcessed sets processedAt = now on the row, marking the effect as
// consumed. Re-running on an already-processed row is a no-op (the
// timestamp is overwritten with the new value, but the row stays in the
// processed state).
func MarkProcessed(ctx context.Context, db *mongo.Database, id string) error {
	now := time.Now().UTC()
	_, err := db.Collection(EffectOutboxCollection).UpdateOne(ctx, bson.M{"_id": id},
		bson.M{"$set": bson.M{"processedAt": now}})
	return err
}
