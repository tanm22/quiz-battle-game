package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"strconv"
	"sync"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	amqp "github.com/rabbitmq/amqp091-go"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

type notificationService struct {
	amqpConn *amqp.Connection
	mongoDB  *mongo.Database
	fcm      *messaging.Client // nil => stub mode (logs only, no FCM delivery)
}

func (s *notificationService) newChannel() (*amqp.Channel, error) {
	return s.amqpConn.Channel()
}

// ---------------------------------------------------------------------------
// Consumer loop — shared by push-notification-queue and premium-expiry-queue.
// Both queues deliver to the same dispatch logic; the event string in the
// payload drives title/body formatting.
// ---------------------------------------------------------------------------

func (s *notificationService) consume(ctx context.Context, queue string) {
	ch, err := s.newChannel()
	if err != nil {
		log.Fatalf("[notification] failed to open channel for %s: %v", queue, err)
	}
	defer ch.Close()

	msgs, err := ch.Consume(queue, "", false, false, false, false, nil)
	if err != nil {
		log.Fatalf("[notification] failed to consume %s: %v", queue, err)
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

// dispatchNotification parses the payload, resolves target user(s), builds the
// title/body for the event, and sends via Firebase Admin SDK in parallel.
// Invalid tokens are cleaned up asynchronously (ISSUE-11 fix).
func (s *notificationService) dispatchNotification(ctx context.Context, msg amqp.Delivery) {
	var payload map[string]any
	if err := json.Unmarshal(msg.Body, &payload); err != nil {
		log.Printf("[notification] bad payload: %v", err)
		msg.Nack(false, false)
		return
	}

	event, _ := payload["event"].(string)
	if event == "" {
		log.Printf("[notification] missing event field: %s", string(msg.Body))
		msg.Ack(false)
		return
	}

	userIDs := extractUserIDs(payload)
	if len(userIDs) == 0 {
		log.Printf("[notification] no target user(s) for %s: %s", event, string(msg.Body))
		msg.Ack(false)
		return
	}

	title, body, data := buildMessage(event, payload)
	for _, uid := range userIDs {
		s.deliverToUser(ctx, uid, title, body, data)
	}
	msg.Ack(false)
}

// extractUserIDs supports both `userId: string` (preferred, per-user payloads)
// and `userIds: []string` (legacy tournament reminder payload) so the worker is
// robust to either shape.
func extractUserIDs(payload map[string]any) []string {
	if s, ok := payload["userId"].(string); ok && s != "" {
		return []string{s}
	}
	if arr, ok := payload["userIds"].([]any); ok {
		out := make([]string, 0, len(arr))
		for _, v := range arr {
			if s, ok := v.(string); ok && s != "" {
				out = append(out, s)
			}
		}
		return out
	}
	return nil
}

func (s *notificationService) deliverToUser(ctx context.Context, userID, title, body string, data map[string]string) {
	var user bson.M
	if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		log.Printf("[notification] user %s not found: %v", userID, err)
		return
	}
	tokens, _ := user["fcmTokens"].(bson.A)
	if len(tokens) == 0 {
		log.Printf("[notification] user %s has no FCM tokens, skipping", userID)
		return
	}

	// Stub mode: Firebase not configured. Log and return so local dev without
	// credentials still works end-to-end on the queue side.
	if s.fcm == nil {
		log.Printf("[notification] (stub) would dispatch to user %s (%d tokens): %s / %s",
			userID, len(tokens), title, body)
		return
	}

	var wg sync.WaitGroup
	for _, t := range tokens {
		tok, ok := t.(string)
		if !ok || tok == "" {
			continue
		}
		wg.Add(1)
		go func(token string) {
			defer wg.Done()
			m := &messaging.Message{
				Token: token,
				Notification: &messaging.Notification{
					Title: title,
					Body:  body,
				},
				Data: data,
				Android: &messaging.AndroidConfig{
					Priority: "high",
					Notification: &messaging.AndroidNotification{
						ChannelID: "default_channel",
					},
				},
			}
			_, err := s.fcm.Send(ctx, m)
			if err == nil {
				return
			}
			if messaging.IsUnregistered(err) || messaging.IsInvalidArgument(err) {
				// Async cleanup so we don't extend the per-message dispatch window
				// waiting on a MongoDB round trip.
				go s.pullInvalidToken(userID, token)
				log.Printf("[notification] removing invalid token for user %s: %v", userID, err)
				return
			}
			log.Printf("[notification] fcm send failed for user %s: %v", userID, err)
		}(tok)
	}
	wg.Wait()
}

func (s *notificationService) pullInvalidToken(userID, token string) {
	_, err := s.mongoDB.Collection("users").UpdateOne(context.Background(),
		bson.M{"_id": userID},
		bson.M{"$pull": bson.M{"fcmTokens": token}},
	)
	if err != nil {
		log.Printf("[notification] failed to pull invalid token for %s: %v", userID, err)
	}
}

// ---------------------------------------------------------------------------
// buildMessage maps each event key to a user-facing title and body, plus a
// data map the Flutter app can route on when the notification is tapped.
// ---------------------------------------------------------------------------

func buildMessage(event string, payload map[string]any) (string, string, map[string]string) {
	data := map[string]string{"event": event}

	switch event {
	case "notif.streak.warning":
		streak := intField(payload, "currentStreak")
		data["streak"] = strconv.FormatInt(streak, 10)
		return "🔥 Your streak is at risk!",
			fmt.Sprintf("Play 1 quiz before midnight to keep your %d-day streak alive.", streak),
			data

	case "notif.referral.converted":
		name := strField(payload, "refereeName")
		coins := intField(payload, "coinsEarned")
		if name == "" {
			name = "A friend"
		}
		data["coins"] = strconv.FormatInt(coins, 10)
		return "🎉 Referral reward!",
			fmt.Sprintf("%s just played their first quiz. You earned %d coins.", name, coins),
			data

	case "notif.tournament.remind":
		tname := strField(payload, "tournamentName")
		mins := intField(payload, "startsInMinutes")
		if tname == "" {
			tname = "Your tournament"
		}
		if mins == 0 {
			mins = 30
		}
		data["tournamentName"] = tname
		return "⏰ Tournament starting soon",
			fmt.Sprintf("%q begins in %d minutes.", tname, mins),
			data

	case "notif.match.invite":
		name := strField(payload, "inviterName")
		rating := intField(payload, "inviterRating")
		if name == "" {
			name = "A player"
		}
		if rating > 0 {
			data["inviterRating"] = strconv.FormatInt(rating, 10)
			return "⚔️ Match invite",
				fmt.Sprintf("%s (rating %d) is looking for a match. Join now?", name, rating),
				data
		}
		return "⚔️ Match invite",
			fmt.Sprintf("%s is looking for a match. Join now?", name),
			data

	case "notif.premium.activated":
		return "💎 Premium activated",
			"Enjoy unlimited quizzes, tournament access, and premium perks.",
			data

	case "notif.premium.expired", "premium.expired":
		return "Premium expired",
			"Your premium plan has ended. Renew to keep unlimited access.",
			data

	case "notif.daily.reward":
		return "🎁 Your daily reward is ready",
			"Claim your daily coins before midnight.",
			data

	default:
		return "Quiz Battle",
			fmt.Sprintf("You have a new %s update.", event),
			data
	}
}

// strField returns payload[key] as a string, or "" if missing / wrong type.
func strField(m map[string]any, key string) string {
	s, _ := m[key].(string)
	return s
}

// intField tolerates the various numeric types JSON unmarshal and bson decode
// can produce (float64 is the JSON default; int32/int64 appear in bson docs).
func intField(m map[string]any, key string) int64 {
	switch v := m[key].(type) {
	case float64:
		return int64(v)
	case int:
		return int64(v)
	case int32:
		return int64(v)
	case int64:
		return v
	}
	return 0
}

// ---------------------------------------------------------------------------
// RabbitMQ setup
// ---------------------------------------------------------------------------

func setupRabbitMQ(ch *amqp.Channel) error {
	if err := ch.ExchangeDeclare("sx", "topic", true, false, false, false, nil); err != nil {
		return err
	}

	// push-notification-queue bound to notif.*  (single-segment)
	if _, err := ch.QueueDeclare("push-notification-queue", true, false, false, false, nil); err != nil {
		return err
	}
	if err := ch.QueueBind("push-notification-queue", "notif.*", "sx", false, nil); err != nil {
		return err
	}
	// Also bind notif.# so multi-segment routing keys like notif.streak.warning are caught.
	if err := ch.QueueBind("push-notification-queue", "notif.#", "sx", false, nil); err != nil {
		return err
	}

	// premium-expiry-queue bound to premium.*  (for premium.expired routing key)
	if _, err := ch.QueueDeclare("premium-expiry-queue", true, false, false, false, nil); err != nil {
		return err
	}
	if err := ch.QueueBind("premium-expiry-queue", "premium.*", "sx", false, nil); err != nil {
		return err
	}

	return nil
}

// ---------------------------------------------------------------------------
// Main — RabbitMQ consumer + Firebase Admin SDK dispatch (no gRPC server)
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

	// MongoDB (for FCM token lookups and invalid-token cleanup)
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

	// Firebase Admin SDK — optional. When GOOGLE_APPLICATION_CREDENTIALS is
	// unset or init fails, the service runs in stub mode (logs only). This
	// keeps local dev workable without Firebase service-account keys and makes
	// the failure mode observable in the service logs rather than crashing.
	//
	// The Admin SDK picks up GOOGLE_APPLICATION_CREDENTIALS automatically via
	// Application Default Credentials, so we don't need to pass it explicitly.
	if os.Getenv("GOOGLE_APPLICATION_CREDENTIALS") != "" {
		app, err := firebase.NewApp(ctx, nil)
		if err != nil {
			log.Printf("[notification] WARN firebase init failed: %v — running in stub mode", err)
		} else {
			msgClient, err := app.Messaging(ctx)
			if err != nil {
				log.Printf("[notification] WARN firebase messaging init failed: %v — running in stub mode", err)
			} else {
				svc.fcm = msgClient
				log.Println("[notification] Firebase Admin SDK initialized")
			}
		}
	} else {
		log.Println("[notification] WARN GOOGLE_APPLICATION_CREDENTIALS not set — running in stub mode (logs only)")
	}

	// Start consumers — one goroutine per queue.
	go svc.consume(ctx, "push-notification-queue")
	go svc.consume(ctx, "premium-expiry-queue")

	log.Println("[notification] consumers running")
	select {} // block forever
}
