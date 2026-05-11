package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log/slog"
	"os"
	"strconv"
	"sync"
	"time"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"

	"quiz-battle/pkg/config"
	"quiz-battle/pkg/lifecycle"
	"quiz-battle/pkg/log"
	"quiz-battle/pkg/metrics"
)

type notificationService struct {
	amqpConn *amqp.Connection
	mongoDB  *mongo.Database
	rdb      *redis.Client     // §4.6: cap, dedup, metrics counters
	fcm      *messaging.Client // nil => stub mode (logs only, no FCM delivery)
	policy   *policy           // §4.6: mute/quiet/dedup/cap gate; nil disables all gates
	metrics  *metrics.Metrics  // nil in tests; non-nil in main()
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
		log.Fatal(ctx, "open channel failed", "queue", queue, "err", err)
	}
	defer ch.Close()

	// prefetch=16 gives backpressure when FCM is slow without choking
	// throughput on the happy path. Matches pkg/coins earn-consumer; bound
	// here is identical because the notification dispatcher's hot dep
	// (FCM HTTP send) has comparable tail latency to Mongo.
	if err := ch.Qos(16, 0, false); err != nil {
		log.Fatal(ctx, "qos failed", "queue", queue, "err", err)
	}

	msgs, err := ch.Consume(queue, "", false, false, false, false, nil)
	if err != nil {
		log.Fatal(ctx, "consume failed", "queue", queue, "err", err)
	}

	for {
		select {
		case <-ctx.Done():
			return
		case msg, ok := <-msgs:
			if !ok {
				return
			}
			s.dispatchNotification(log.ContextFromDelivery(ctx, msg), msg)
			if s.metrics != nil {
				s.metrics.RecordDispatched(queue)
			}
		}
	}
}

// dispatchNotification parses the payload, resolves target user(s), builds the
// title/body for the event, and sends via Firebase Admin SDK in parallel.
// Invalid tokens are cleaned up asynchronously (ISSUE-11 fix).
func (s *notificationService) dispatchNotification(ctx context.Context, msg amqp.Delivery) {
	var payload map[string]any
	if err := json.Unmarshal(msg.Body, &payload); err != nil {
		log.FromContext(ctx).Warn("bad payload", "err", err)
		msg.Nack(false, false)
		return
	}

	event, _ := payload["event"].(string)
	if event == "" {
		log.FromContext(ctx).Warn("missing event field", "body", string(msg.Body))
		msg.Ack(false)
		return
	}

	userIDs := extractUserIDs(payload)
	if len(userIDs) == 0 {
		log.FromContext(ctx).Warn("no target user(s)", "event", event, "body", string(msg.Body))
		msg.Ack(false)
		return
	}

	title, body, data := buildMessage(event, payload)
	for _, uid := range userIDs {
		// §4.6 policy gate. The gate runs per-recipient because mutes,
		// timezone, and the daily cap are all user-scoped — a fan-out to
		// 100 users for a tournament reminder gates each recipient
		// independently.
		if s.policy != nil {
			res := s.policy.allow(ctx, uid, event)
			if !res.Allowed {
				log.FromContext(ctx).Info("dropped",
					"event", event, "user_id", uid, "reason", res.Reason)
				continue
			}
			// Embed the resolved category so the Flutter client can
			// echo it back via MarkNotificationOpened without having
			// to redo the routing-key→category mapping.
			data["category"] = res.Category
		}
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
		log.FromContext(ctx).Warn("user not found", "user_id", userID, "err", err)
		return
	}
	tokens, _ := user["fcmTokens"].(bson.A)
	if len(tokens) == 0 {
		log.FromContext(ctx).Info("user has no FCM tokens; skipping", "user_id", userID)
		return
	}

	// Stub mode: Firebase not configured. Log and return so local dev without
	// credentials still works end-to-end on the queue side.
	if s.fcm == nil {
		log.FromContext(ctx).Info("(stub) would dispatch",
			"user_id", userID, "tokens", len(tokens), "title", title, "body", body)
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
				// waiting on a MongoDB round trip. DetachContext keeps the
				// originating request_id (and any ctx attrs) so the cleanup
				// log line correlates to the dispatch that triggered it,
				// without inheriting the parent's cancellation.
				go s.pullInvalidToken(log.DetachContext(ctx), userID, token)
				log.FromContext(ctx).Info("removing invalid token", "user_id", userID, "err", err)
				return
			}
			log.FromContext(ctx).Error("fcm send failed", "user_id", userID, "err", err)
		}(tok)
	}
	wg.Wait()
}

func (s *notificationService) pullInvalidToken(ctx context.Context, userID, token string) {
	_, err := s.mongoDB.Collection("users").UpdateOne(ctx,
		bson.M{"_id": userID},
		bson.M{"$pull": bson.M{"fcmTokens": token}},
	)
	if err != nil {
		log.FromContext(ctx).Error("pull invalid token failed", "user_id", userID, "err", err)
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
			fmt.Sprintf("%s begins in %d minutes.", tname, mins),
			data

	case "notif.tournament.finished":
		// Phase 3 (4.2): emitted by scoring service after the quiz finalization
		// worker publishes per-winner tournament.finished events. Every
		// participant we awarded (top-N) gets one of these — top of the
		// payload table when it's a coin win, polite "thanks for playing"
		// when coinsAwarded == 0 (participant outside the prize pool).
		tname := strField(payload, "tournamentName")
		rank := intField(payload, "rank")
		coins := intField(payload, "coinsAwarded")
		if tname == "" {
			tname = "Your tournament"
		}
		data["tournamentName"] = tname
		data["rank"] = strconv.FormatInt(rank, 10)
		data["coinsAwarded"] = strconv.FormatInt(coins, 10)
		if coins > 0 {
			medal := "🏆"
			if rank == 2 {
				medal = "🥈"
			} else if rank == 3 {
				medal = "🥉"
			} else if rank > 3 {
				medal = "🎖️"
			}
			return fmt.Sprintf("%s Tournament finished", medal),
				fmt.Sprintf("You finished #%d in %s and earned %d coins!", rank, tname, coins),
				data
		}
		return "🏁 Tournament finished",
			fmt.Sprintf("%s wrapped up. You finished #%d — better luck next round!", tname, rank),
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

	case "notif.friend.request_received":
		// Phase 3 (4.4): emitted by scoring's SendFriendRequest. Payload
		// carries the sender's display name so the recipient sees who's
		// asking before they open the app.
		name := strField(payload, "fromUsername")
		if name == "" {
			name = "Someone"
		}
		if reqID := strField(payload, "requestId"); reqID != "" {
			data["requestId"] = reqID
		}
		return "🤝 New friend request",
			fmt.Sprintf("%s wants to be your friend.", name),
			data

	case "notif.friend.request_accepted":
		// Phase 3 (4.4): emitted by scoring when a pending request flips to
		// accepted (RespondToFriendRequest accept path, or the auto-accept-
		// reverse path inside SendFriendRequest). Tells the original sender
		// in real time so they don't have to poll GetFriendsList.
		name := strField(payload, "accepterUsername")
		if name == "" {
			name = "Someone"
		}
		if reqID := strField(payload, "requestId"); reqID != "" {
			data["requestId"] = reqID
		}
		return "🤝 Friend request accepted",
			fmt.Sprintf("%s accepted your friend request.", name),
			data

	case "notif.friend.challenge":
		// Phase 3 (4.4): emitted by scoring's ChallengeFriend. roomId is
		// the active 1v1 room — the client routes the tap straight into
		// the game flow rather than the friends list.
		name := strField(payload, "fromUsername")
		if name == "" {
			name = "A friend"
		}
		if roomID := strField(payload, "roomId"); roomID != "" {
			data["roomId"] = roomID
		}
		return "⚔️ Friend challenge",
			fmt.Sprintf("%s challenged you to a quick quiz!", name),
			data

	case "notif.premium.activated":
		return "💎 Premium activated",
			"Enjoy unlimited quizzes, tournament access, and premium perks.",
			data

	case "notif.premium.expired", "premium.expired":
		return "Premium expired",
			"Your premium plan has ended. Renew to keep unlimited access.",
			data

	case "notif.premium.expiry":
		// 3-day pre-warning fired by payment service's expiry-warning worker.
		return "⏳ Premium expires soon",
			"Your premium plan ends in 3 days. Renew now to keep unlimited access.",
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
	slog.SetDefault(log.Init("notification"))
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	cfg := config.MustCommon(ctx)

	// RabbitMQ
	conn, err := amqp.Dial(cfg.RabbitMQURL)
	if err != nil {
		log.Fatal(ctx, "rabbitmq connect failed", "err", err)
	}

	setupCh, err := conn.Channel()
	if err != nil {
		log.Fatal(ctx, "rabbitmq channel failed", "err", err)
	}
	if err := setupRabbitMQ(setupCh); err != nil {
		log.Fatal(ctx, "rabbitmq setup failed", "err", err)
	}
	setupCh.Close()
	log.FromContext(ctx).Info("connected to RabbitMQ")

	// MongoDB (for FCM token lookups and invalid-token cleanup)
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(cfg.MongoURI))
	if err != nil {
		log.Fatal(ctx, "mongodb connect failed", "err", err)
	}
	log.FromContext(ctx).Info("connected to MongoDB")

	// Redis: §4.6 policy gate stores cap/dedup/metric counters here.
	// Co-located with the rest of the platform (single redis container in
	// docker-compose) so we don't need a separate connection budget.
	rdb := redis.NewClient(&redis.Options{Addr: cfg.RedisAddr})
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.FromContext(ctx).Warn("redis ping failed; policy gate disabled", "err", err)
		rdb = nil
	} else {
		log.FromContext(ctx).Info("connected to Redis")
	}

	svc := &notificationService{
		amqpConn: conn,
		mongoDB:  mongoClient.Database("quizbattle"),
		rdb:      rdb,
	}

	// §4.6 policy gate. Disabled when Redis isn't reachable — better to
	// dispatch unfiltered than swallow every push because of an infra
	// outage. NOTIF_DAILY_CAP overrides the per-user push ceiling;
	// 0 means "use the package default" (newPolicy substitutes notifDailyCap).
	if rdb != nil {
		dailyCap := config.OptionalInt("NOTIF_DAILY_CAP", 0)
		svc.policy = newPolicy(rdb, svc.mongoDB, dailyCap)
		log.FromContext(ctx).Info("policy gate enabled", "daily_cap", svc.policy.dailyCap)
	}

	// Firebase Admin SDK — optional. When GOOGLE_APPLICATION_CREDENTIALS is
	// unset or init fails, the service runs in stub mode (logs only). This
	// keeps local dev workable without Firebase service-account keys and makes
	// the failure mode observable in the service logs rather than crashing.
	//
	// The Admin SDK picks up GOOGLE_APPLICATION_CREDENTIALS automatically via
	// Application Default Credentials. FIREBASE_PROJECT_ID is only needed
	// when the service-account JSON lacks a project_id field — the Go SDK
	// doesn't read that env var itself, so we forward it via firebase.Config.
	if os.Getenv("GOOGLE_APPLICATION_CREDENTIALS") != "" {
		cfg := &firebase.Config{}
		if pid := os.Getenv("FIREBASE_PROJECT_ID"); pid != "" {
			cfg.ProjectID = pid
		}
		app, err := firebase.NewApp(ctx, cfg)
		if err != nil {
			log.FromContext(ctx).Warn("firebase init failed; running in stub mode", "err", err)
		} else {
			msgClient, err := app.Messaging(ctx)
			if err != nil {
				log.FromContext(ctx).Warn("firebase messaging init failed; running in stub mode", "err", err)
			} else {
				svc.fcm = msgClient
				log.FromContext(ctx).Info("Firebase Admin SDK initialized")
			}
		}
	} else {
		log.FromContext(ctx).Warn("GOOGLE_APPLICATION_CREDENTIALS not set; running in stub mode (logs only)")
	}

	m := metrics.New("notification")
	metricsSrv := m.Serve(ctx, ":2112")
	svc.metrics = m

	// Start consumers — one goroutine per queue. Each select on
	// ctx.Done() so the cancel() below unblocks them.
	go svc.consume(ctx, "push-notification-queue")
	go svc.consume(ctx, "premium-expiry-queue")
	log.FromContext(ctx).Info("consumers running")

	lifecycle.WaitForSignal(ctx)
	log.FromContext(ctx).Info("graceful shutdown starting")

	cancel()

	shutdownCtx, shutdownCancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer shutdownCancel()

	if err := metricsSrv.Shutdown(shutdownCtx); err != nil {
		log.FromContext(ctx).Warn("metrics shutdown", "err", err)
	}
	if err := conn.Close(); err != nil {
		log.FromContext(ctx).Warn("amqp conn close", "err", err)
	}
	if err := mongoClient.Disconnect(shutdownCtx); err != nil {
		log.FromContext(ctx).Warn("mongo disconnect", "err", err)
	}
	log.FromContext(ctx).Info("graceful shutdown complete")
}
