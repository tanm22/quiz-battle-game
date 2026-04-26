package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log"
	"time"

	"quiz-battle/pkg/coins"
)

// errBadEarnPayload marks unrecoverable parse / shape errors on a
// coins.earn.* message. The consumer goroutine dead-letters such messages
// (Nack with requeue=false) so a single broken payload doesn't loop the
// queue forever and starve healthy events.
var errBadEarnPayload = errors.New("bad earn payload")

// handleEarnEvent is the single dispatch point for every coins.earn.*
// message. It validates the envelope, calls Ledger.Grant, and lets the
// (userId, refId, reason) unique index handle idempotency on redelivery.
//
// Negative-amount events are rejected: the earn pipeline is for credits
// only. Spend (shop purchase, refund) goes through a synchronous Purchase
// RPC in PR 4 — keeping the two paths separate avoids the consumer
// accidentally letting a malformed message debit a balance.
func (s *scoringServer) handleEarnEvent(ctx context.Context, body []byte) error {
	var ev coins.EarnEvent
	if err := json.Unmarshal(body, &ev); err != nil {
		return fmt.Errorf("%w: decode: %v", errBadEarnPayload, err)
	}
	if ev.UserID == "" || ev.Reason == "" || ev.RefID == "" {
		return fmt.Errorf("%w: missing required field: %+v", errBadEarnPayload, ev)
	}
	if ev.Amount <= 0 {
		return fmt.Errorf("%w: amount must be positive (got %d)", errBadEarnPayload, ev.Amount)
	}

	entry, err := s.ledger.Grant(ctx, ev.UserID, ev.Amount, ev.Reason, ev.RefID, ev.Metadata)
	if err != nil {
		return fmt.Errorf("grant: %w", err)
	}
	log.Printf("[earn-consumer] user=%s reason=%s delta=%d balance=%d ref=%s",
		ev.UserID, ev.Reason, entry.Delta, entry.BalanceAfter, ev.RefID)
	return nil
}

// consumeCoinEarn is the goroutine that drains coin-earn-queue and routes
// each delivery through handleEarnEvent. Bad-payload errors dead-letter
// (Nack false,false) so a single broken producer can't head-of-line-block
// healthy traffic; transient errors (Grant/Mongo failures) requeue
// (Nack false,true) so the message retries until success or DLQ via the
// queue's x-max-delivery-count.
func (s *scoringServer) consumeCoinEarn(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[earn-consumer] open channel: %v", err)
	}
	defer ch.Close()

	// prefetch=16 gives backpressure when Mongo is slow without choking
	// throughput on the happy path. Tune later via metrics if needed.
	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatalf("[earn-consumer] qos: %v", err)
	}

	msgs, err := ch.Consume(coins.EarnQueueName, "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[earn-consumer] consume %s: %v", coins.EarnQueueName, err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			dispatchCtx, cancel := context.WithTimeout(ctx, 10*time.Second)
			err := s.handleEarnEvent(dispatchCtx, msg.Body)
			cancel()

			switch {
			case err == nil:
				_ = msg.Ack(false)
			case errors.Is(err, errBadEarnPayload):
				log.Printf("[earn-consumer] dead-letter: %v body=%s", err, string(msg.Body))
				_ = msg.Nack(false, false) // → coin-earn-dlq
			default:
				log.Printf("[earn-consumer] transient (will requeue): %v", err)
				_ = msg.Nack(false, true)
			}
		}
	}
}
