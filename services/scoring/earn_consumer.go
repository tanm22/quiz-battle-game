package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"time"

	"quiz-battle/pkg/coins"
)

// consumeCoinEarn binds a dedicated AMQP channel to coin-earn-queue and
// dispatches each delivery through handleEarnEvent. The queue declaration
// + binding live in setupRabbitMQ (one channel for all setup work); this
// goroutine just opens its own channel for the actual consumption so the
// publish-mutex'd channel isn't blocked.
//
// Backpressure: prefetch=16 caps in-flight messages per consumer. A
// failed grant (Mongo down, transient transaction abort) is requeued
// once via Nack(false, true). Persistent failures pile up on the queue
// and get visible in the RabbitMQ UI; problem-03 §4.7 calls out a real
// DLQ as production work, not demo scope.
func (s *scoringServer) consumeCoinEarn(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[coin-earn] open channel: %v", err)
	}
	defer ch.Close()

	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatalf("[coin-earn] qos: %v", err)
	}
	deliveries, err := ch.Consume(coins.EarnQueueName, "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[coin-earn] consume %s: %v", coins.EarnQueueName, err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case d, ok := <-deliveries:
			if !ok {
				return
			}
			ectx, cancel := context.WithTimeout(ctx, 10*time.Second)
			if err := s.handleEarnEvent(ectx, d.Body); err != nil {
				log.Printf("[coin-earn] dispatch failed: %v body=%s", err, string(d.Body))
				_ = d.Nack(false, true)
			} else {
				_ = d.Ack(false)
			}
			cancel()
		}
	}
}

// handleEarnEvent dispatches one coin-earn message to ledger.Grant. The
// (userId, refId, reason) compound unique index in coin_ledger is the
// idempotency guarantee — a redelivered message hits the ledger fast-path
// and returns the existing entry, so we only log "double-grant" once.
//
// Argument validation here is strict because the cost of accepting a
// malformed event (zero amount, missing refID, negative amount) is a row
// in the ledger that misrepresents reality. Invalid messages get returned
// as errors; the queue consumer in main.go decides whether to requeue or
// nack-without-requeue based on that error type.
func (s *scoringServer) handleEarnEvent(ctx context.Context, body []byte) error {
	var ev coins.EarnEvent
	if err := json.Unmarshal(body, &ev); err != nil {
		return fmt.Errorf("decode earn event: %w", err)
	}
	if ev.UserID == "" || ev.Amount == 0 || ev.Reason == "" || ev.RefID == "" {
		return fmt.Errorf("invalid earn event: %+v", ev)
	}
	if ev.Amount < 0 {
		return fmt.Errorf("earn events may not have negative amount; got %d", ev.Amount)
	}
	entry, err := s.ledger.Grant(ctx, ev.UserID, ev.Amount, ev.Reason, ev.RefID, ev.Metadata)
	if err != nil {
		return fmt.Errorf("grant: %w", err)
	}
	log.Printf("[scoring] coin earn user=%s reason=%s delta=%d balance=%d ref=%s",
		ev.UserID, ev.Reason, entry.Delta, entry.BalanceAfter, ev.RefID)
	return nil
}
