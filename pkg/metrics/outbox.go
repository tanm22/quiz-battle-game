package metrics

// RecordOutboxPending sets outbox_pending_total{kind=...} to the given
// count. Call from the payment-service outbox watcher each tick so the
// gauge reflects the current queue depth per kind. `kind` must be from a
// bounded set (currently only "premium_trial") to keep cardinality safe.
func (m *Metrics) RecordOutboxPending(kind string, count float64) {
	m.OutboxPendingTotal.WithLabelValues(kind).Set(count)
}

// RecordOutboxOldestAge sets outbox_oldest_age_seconds{kind=...} to the
// age in seconds of the oldest unprocessed row of `kind`. Callers pass 0
// when the queue is empty so the gauge collapses to a known floor rather
// than reporting a stale max from the last non-empty tick.
func (m *Metrics) RecordOutboxOldestAge(kind string, ageSeconds float64) {
	m.OutboxOldestAgeSeconds.WithLabelValues(kind).Set(ageSeconds)
}
