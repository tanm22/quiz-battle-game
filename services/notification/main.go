package main

import (
	"context"
	"encoding/json"
	"log"
	"os"

	amqp "github.com/rabbitmq/amqp091-go"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

type notificationService struct {
	amqpConn *amqp.Connection
	mongoDB  *mongo.Database
}

func (s *notificationService) newChannel() (*amqp.Channel, error) {
	return s.amqpConn.Channel()
}

// ---------------------------------------------------------------------------
// Consumer: push-notification-queue (notif.*)
// ---------------------------------------------------------------------------

func (s *notificationService) consumeNotifications(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[notification] failed to open channel: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("push-notification-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[notification] failed to consume push-notification-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			s.dispatchNotification(ctx, msg)
		}
	}
}

func (s *notificationService) dispatchNotification(ctx context.Context, msg amqp.Delivery) {
	var payload struct {
		Event  string `json:"event"`
		UserID string `json:"userId"`
	}
	if err := json.Unmarshal(msg.Body, &payload); err != nil {
		log.Printf("[notification] bad payload: %v", err)
		msg.Nack(false, false)
		return
	}

	// Look up FCM tokens from MongoDB
	var user bson.M
	if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": payload.UserID}).Decode(&user); err != nil {
		log.Printf("[notification] user %s not found: %v", payload.UserID, err)
		msg.Ack(false)
		return
	}

	tokens, _ := user["fcmTokens"].(bson.A)
	if len(tokens) == 0 {
		log.Printf("[notification] user %s has no FCM tokens, skipping", payload.UserID)
		msg.Ack(false)
		return
	}

	// TODO CP-7: Dispatch via Firebase Admin SDK with parallel goroutines per token.
	// For now, log the dispatch.
	log.Printf("[notification] would dispatch %s to user %s (%d tokens): %s",
		payload.Event, payload.UserID, len(tokens), string(msg.Body))

	msg.Ack(false)
}

// ---------------------------------------------------------------------------
// Consumer: premium-expiry-queue (premium.*)
// ---------------------------------------------------------------------------

func (s *notificationService) consumePremiumExpiry(ctx context.Context) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[notification] failed to open channel for premium-expiry: %v", err)
	}
	defer ch.Close()

	msgs, err := ch.Consume("premium-expiry-queue", "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[notification] failed to consume premium-expiry-queue: %v", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			// Route to the same dispatch logic
			s.dispatchNotification(ctx, msg)
		}
	}
}

// ---------------------------------------------------------------------------
// RabbitMQ setup
// ---------------------------------------------------------------------------

func setupRabbitMQ(ch *amqp.Channel) error {
	if err := ch.ExchangeDeclare("sx", "topic", true, false, false, false, nil); err != nil {
		return err
	}

	// push-notification-queue bound to notif.*
	if _, err := ch.QueueDeclare("push-notification-queue", true, false, false, false, nil); err != nil {
		return err
	}
	if err := ch.QueueBind("push-notification-queue", "notif.*", "sx", false, nil); err != nil {
		return err
	}
	// Also bind notif.*.* for multi-segment routing keys like notif.streak.warning
	if err := ch.QueueBind("push-notification-queue", "notif.#", "sx", false, nil); err != nil {
		return err
	}

	// premium-expiry-queue bound to premium.*
	if _, err := ch.QueueDeclare("premium-expiry-queue", true, false, false, false, nil); err != nil {
		return err
	}
	if err := ch.QueueBind("premium-expiry-queue", "premium.*", "sx", false, nil); err != nil {
		return err
	}

	return nil
}

// ---------------------------------------------------------------------------
// Main — RabbitMQ consumer only (no gRPC server, no port)
// ---------------------------------------------------------------------------

func main() {
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// RabbitMQ
	rabbitURL := os.Getenv("RABBITMQ_URL")
	if rabbitURL == "" {
		rabbitURL = "amqp://guest:guest@localhost:5672/"
	}
	conn, err := amqp.Dial(rabbitURL)
	if err != nil {
		log.Fatalf("rabbitmq connect failed: %v", err)
	}
	defer conn.Close()

	setupCh, err := conn.Channel()
	if err != nil {
		log.Fatalf("rabbitmq channel failed: %v", err)
	}
	if err := setupRabbitMQ(setupCh); err != nil {
		log.Fatalf("rabbitmq setup failed: %v", err)
	}
	setupCh.Close()
	log.Println("[notification] connected to RabbitMQ")

	// MongoDB (for FCM token lookups)
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017/quizbattle"
	}
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(mongoURI))
	if err != nil {
		log.Fatalf("mongo connect failed: %v", err)
	}
	defer mongoClient.Disconnect(ctx)
	log.Println("[notification] connected to MongoDB")

	svc := &notificationService{
		amqpConn: conn,
		mongoDB:  mongoClient.Database("quizbattle"),
	}

	// Start consumers
	go svc.consumeNotifications(ctx)
	go svc.consumePremiumExpiry(ctx)

	log.Println("[notification] consumers running (no gRPC port)")
	select {} // block forever
}
