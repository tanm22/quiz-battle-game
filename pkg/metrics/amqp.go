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
// the disposition (ack / nack_requeue / nack_drop). Call this after
// every msg.Ack / msg.Nack so the metric mirrors the actual broker
// disposition. Use the Status* constants for the second arg to keep
// label cardinality bounded.
func (m *Metrics) RecordConsume(queue, status string) {
	m.AMQPConsumesTotal.WithLabelValues(queue, status).Inc()
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
