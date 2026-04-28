package metrics

// RecordPublish bumps amqp_publishes_total with the given routing key
// and outcome. Wrap the actual publish call in a function that calls
// this with OutcomeOK on nil error and OutcomeError otherwise — see
// the per-service publish helpers.
func (m *Metrics) RecordPublish(routingKey string, err error) {
	outcome := OutcomeOK
	if err != nil {
		outcome = OutcomeError
	}
	m.AMQPPublishesTotal.WithLabelValues(routingKey, outcome).Inc()
}

// RecordConsume bumps amqp_consumes_total with the queue name and
// the disposition. Call this after every msg.Ack / msg.Nack so the
// metric mirrors the actual broker disposition. Use the Status*
// constants for the second arg to keep label cardinality bounded —
// the metric's docstring promises exactly three values, and "let the
// caller pass anything" silently widens that contract.
func (m *Metrics) RecordConsume(queue, status string) {
	m.AMQPConsumesTotal.WithLabelValues(queue, status).Inc()
}

// RecordDispatched bumps amqp_dispatched_total with the queue name.
// Call this after the per-message handler returns, regardless of
// disposition — it counts "we received and handed off this message,"
// which is a different signal from "we acked/nacked." Useful when the
// handler does its own ack/nack internally (e.g., scoring's
// persistMatch + processAnswer) and the consume loop can't observe
// the disposition without restructuring the handler signature.
//
// Operators can compute amqp_dispatched_total - amqp_consumes_total
// per queue to spot handlers that don't disposition properly.
func (m *Metrics) RecordDispatched(queue string) {
	m.AMQPDispatchedTotal.WithLabelValues(queue).Inc()
}

// RecordWebhook bumps webhook_events_total — payment.razorpay is the
// current sole source. Outcome is OutcomeOK / OutcomeError.
func (m *Metrics) RecordWebhook(source string, err error) {
	outcome := OutcomeOK
	if err != nil {
		outcome = OutcomeError
	}
	m.WebhookEventsTotal.WithLabelValues(source, outcome).Inc()
}
