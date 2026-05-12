package main

import (
	"context"
	"errors"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"quiz-battle/pkg/coins/shop"
	"quiz-battle/pkg/log"
)

// outboxWatchInterval throttles the watcher sweep. 30s is loose enough
// that the watcher itself isn't a meaningful load on Mongo (two cheap
// covered-index reads per kind per tick), tight enough that a stuck
// consumer is caught within a single tick of the stuckThreshold.
const outboxWatchInterval = 30 * time.Second

// outboxStuckThreshold is the age at which the oldest unprocessed row
// is loud-logged as "stuck." Five minutes is well past the normal apply
// latency (the premium-trial consumer polls at 1s); anything older
// almost certainly means the consumer goroutine is wedged or its Mongo
// session is broken, and an operator needs to look.
const outboxStuckThreshold = 5 * time.Minute

// startOutboxWatcher launches a background goroutine that refreshes the
// outbox_pending_total / outbox_oldest_age_seconds gauges every 30s for
// the given kind, and emits a loud error log when the oldest row exceeds
// outboxStuckThreshold. The watcher is scoped to a single kind so the
// caller wires one goroutine per kind currently in flight (today only
// "premium_trial"); the goroutine exits cleanly on ctx.Done().
//
// This closes the §4.3 PR 5 visibility gap: the transactional-outbox
// pattern means a stuck consumer silently strands paid-for purchases,
// and previously there was no metric and no alert to surface it.
func (s *paymentServer) startOutboxWatcher(ctx context.Context, kind string) {
	go func() {
		t := time.NewTicker(outboxWatchInterval)
		defer t.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-t.C:
				s.tickOutboxWatcher(ctx, kind)
			}
		}
	}()
}

// tickOutboxWatcher samples the outbox once, publishes the gauges, and
// emits a stuck-row error log when applicable. Split out so the ticker
// loop body is one self-contained call — easier to reason about and
// (with sampleOutbox below) makes the watcher unit-testable without a
// real ticker.
func (s *paymentServer) tickOutboxWatcher(ctx context.Context, kind string) {
	pending, oldestAge, err := s.sampleOutbox(ctx, kind)
	if err != nil {
		// Transient Mongo errors (replica election, connection blip)
		// shouldn't crash the watcher — log at Warn and skip the tick.
		// The next tick will pick up the new state once Mongo recovers.
		log.FromContext(ctx).Warn("outbox watcher sample failed", "kind", kind, "err", err)
		return
	}

	if s.metrics != nil {
		s.metrics.RecordOutboxPending(kind, float64(pending))
		s.metrics.RecordOutboxOldestAge(kind, oldestAge)
	}

	if oldestAge > outboxStuckThreshold.Seconds() {
		// Floor signal until a Prometheus alert rule lands. See
		// docs/runbook-coins.md "Outbox watcher metrics" — operator
		// is expected to inspect coin_effect_outbox immediately.
		log.FromContext(ctx).Error("outbox stuck",
			"kind", kind,
			"pending", pending,
			"oldest_age_seconds", oldestAge,
		)
	}
}

// sampleOutbox runs the two cheap reads the watcher needs against the
// coin_effect_outbox collection: the pending count and the oldest
// unprocessed row's age in seconds (0 when the queue is empty).
//
// Both queries are scoped to a single kind so per-kind gauge updates
// don't accidentally mix queue depths across unrelated consumers. The
// {kind, processedAt} index in seed/main.go (added with the outbox
// schema) makes both filters covered scans.
//
// Exposed as a method so the unit test can drive the watcher
// deterministically — insert fixtures, call sampleOutbox, assert the
// returned tuple — without spinning up a real ticker.
func (s *paymentServer) sampleOutbox(ctx context.Context, kind string) (pending int64, oldestAge float64, err error) {
	coll := s.mongoClient.Database(s.dbName).Collection(shop.EffectOutboxCollection)
	filter := bson.M{"kind": kind, "processedAt": nil}

	pending, err = coll.CountDocuments(ctx, filter)
	if err != nil {
		return 0, 0, err
	}
	if pending == 0 {
		return 0, 0, nil
	}

	var oldest shop.OutboxRow
	err = coll.FindOne(ctx, filter,
		options.FindOne().SetSort(bson.D{{Key: "createdAt", Value: 1}}),
	).Decode(&oldest)
	if err != nil {
		// CountDocuments said pending > 0 but the oldest row vanished
		// between calls — race with the consumer marking the last row
		// processed. Report pending=0, age=0 rather than propagate; the
		// next tick gets the consistent state.
		if errors.Is(err, mongo.ErrNoDocuments) {
			return 0, 0, nil
		}
		return 0, 0, err
	}

	oldestAge = time.Since(oldest.CreatedAt).Seconds()
	if oldestAge < 0 {
		// Clock skew between this process and the writer: cap at 0 so a
		// negative age doesn't mask a real stuck-row condition or
		// produce a confusing gauge value.
		oldestAge = 0
	}
	return pending, oldestAge, nil
}
