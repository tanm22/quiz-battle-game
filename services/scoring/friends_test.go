package main

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/keys"
	pb "quiz-battle/proto"
)

// attachRedis points srv.rdb at a real local Redis. Friend RPCs read
// presence keys and SETNX challenge throttles, so we need a live
// instance — there's no in-memory Redis stand-in in this repo.
func attachRedis(t *testing.T, srv *scoringServer) {
	t.Helper()
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: addr})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis ping: %v", err)
	}
	// Wipe the keyspace so prior test runs don't bleed in: presence and
	// throttle keys are TTL-bounded but tests that assert FRIEND_OFFLINE
	// would still flake if a previous TouchPresence is alive.
	if err := rdb.FlushDB(context.Background()).Err(); err != nil {
		t.Fatalf("redis flush: %v", err)
	}
	srv.rdb = rdb
	t.Cleanup(func() { _ = rdb.Close() })
}

// seedFullUser inserts a users-collection row with everything friend lookups
// need (username, referralCode). seedScoringUser only writes coins, which
// isn't enough for SendFriendRequest's username/refCode resolve.
func seedFullUser(t *testing.T, srv *scoringServer, uid, username, refCode string) {
	t.Helper()
	_, err := srv.mongoDB.Collection("users").InsertOne(context.Background(), bson.M{
		"_id":          uid,
		"username":     username,
		"plan":         "free",
		"rating":       int32(1200),
		"referralCode": refCode,
	})
	if err != nil {
		t.Fatalf("seed user %s: %v", uid, err)
	}
}

// seedFriendRequestRow injects a friend_requests doc directly so tests can
// set up "already pending" / "already accepted" / "already rejected"
// scenarios without going through the SendFriendRequest path.
func seedFriendRequestRow(t *testing.T, srv *scoringServer, id, from, to, status string) {
	t.Helper()
	doc := bson.M{
		"_id":          id,
		"fromUserId":   from,
		"fromUsername": from,
		"toUserId":     to,
		"toUsername":   to,
		"status":       status,
		"createdAt":    time.Now().UTC(),
	}
	if status != "pending" {
		now := time.Now().UTC()
		doc["respondedAt"] = now
	}
	if _, err := srv.mongoDB.Collection(friendRequestsCollection).InsertOne(context.Background(), doc); err != nil {
		t.Fatalf("seed friend request: %v", err)
	}
}

// ensureFriendIndexes mirrors the unique compound index seed creates in
// seed/main.go. Required for TestSendFriendRequest_DuplicateReturnsExisting
// because the in-memory test DB starts indexless.
func ensureFriendIndexes(t *testing.T, srv *scoringServer) {
	t.Helper()
	_, err := srv.mongoDB.Collection(friendRequestsCollection).Indexes().CreateOne(
		context.Background(),
		mongo.IndexModel{
			Keys:    bson.D{{Key: "fromUserId", Value: 1}, {Key: "toUserId", Value: 1}},
			Options: options.Index().SetUnique(true).SetName("uniq_from_to"),
		},
	)
	if err != nil {
		t.Fatalf("create friend indexes: %v", err)
	}
}

// ---------------------------------------------------------------------------
// SendFriendRequest
// ---------------------------------------------------------------------------

func TestSendFriendRequest_RejectsUnauthenticated(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	_, err := srv.SendFriendRequest(context.Background(), &pb.SendFriendRequestRequest{TargetUsername: "x"})
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("got %v, want Unauthenticated", err)
	}
}

func TestSendFriendRequest_RejectsBothOrNeitherTarget(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	ensureFriendIndexes(t, srv)

	resp, err := srv.SendFriendRequest(authedCtx("alice"), &pb.SendFriendRequestRequest{})
	if err != nil || resp.ErrorCode != "INVALID_ARGUMENT" {
		t.Errorf("neither: got err=%v code=%q, want INVALID_ARGUMENT", err, resp.ErrorCode)
	}

	resp, err = srv.SendFriendRequest(authedCtx("alice"),
		&pb.SendFriendRequestRequest{TargetUsername: "bob", TargetReferralCode: "REFBB"})
	if err != nil || resp.ErrorCode != "INVALID_ARGUMENT" {
		t.Errorf("both: got err=%v code=%q, want INVALID_ARGUMENT", err, resp.ErrorCode)
	}
}

func TestSendFriendRequest_UserNotFound(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	ensureFriendIndexes(t, srv)

	resp, _ := srv.SendFriendRequest(authedCtx("alice"),
		&pb.SendFriendRequestRequest{TargetUsername: "ghost"})
	if resp.ErrorCode != "USER_NOT_FOUND" {
		t.Errorf("got %q, want USER_NOT_FOUND", resp.ErrorCode)
	}
}

func TestSendFriendRequest_RejectsSelf(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	ensureFriendIndexes(t, srv)

	resp, _ := srv.SendFriendRequest(authedCtx("alice"),
		&pb.SendFriendRequestRequest{TargetUsername: "alice"})
	if resp.ErrorCode != "SELF" {
		t.Errorf("got %q, want SELF", resp.ErrorCode)
	}
}

func TestSendFriendRequest_HappyPathByUsername(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	ensureFriendIndexes(t, srv)

	resp, err := srv.SendFriendRequest(authedCtx("alice"),
		&pb.SendFriendRequestRequest{TargetUsername: "bob"})
	if err != nil || !resp.Success || resp.RequestId == "" {
		t.Fatalf("got err=%v resp=%+v", err, resp)
	}

	count, _ := srv.mongoDB.Collection(friendRequestsCollection).CountDocuments(context.Background(),
		bson.M{"fromUserId": "alice", "toUserId": "bob", "status": "pending"})
	if count != 1 {
		t.Errorf("expected 1 pending row, got %d", count)
	}
}

func TestSendFriendRequest_HappyPathByReferralCode(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBOB1")
	ensureFriendIndexes(t, srv)

	resp, _ := srv.SendFriendRequest(authedCtx("alice"),
		&pb.SendFriendRequestRequest{TargetReferralCode: "REFBOB1"})
	if !resp.Success {
		t.Errorf("got %+v", resp)
	}
}

func TestSendFriendRequest_AutoAcceptsReversePending(t *testing.T) {
	// Bob → Alice was already pending. Alice "sends" to Bob → the
	// existing reverse request flips to accepted; no new row written.
	// Bob (the original sender) gets a notif.friend.request_accepted push
	// so he learns about it without polling.
	srv, _, _ := scoringTestEnv(t)
	// Redis required: the auto-accept-reverse path TouchPresences the
	// caller (Alice here) for the same reason the explicit accept path
	// does — Bob's UI refresh after the push should see Alice as Online,
	// not Offline.
	attachRedis(t, srv)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	ensureFriendIndexes(t, srv)
	seedFriendRequestRow(t, srv, "req-1", "bob", "alice", "pending")
	captured := publishCapture(srv)

	resp, _ := srv.SendFriendRequest(authedCtx("alice"),
		&pb.SendFriendRequestRequest{TargetUsername: "bob"})
	if !resp.Success || resp.RequestId != "req-1" {
		t.Errorf("got %+v, want auto-accept of req-1", resp)
	}

	var r struct {
		Status string `bson:"status"`
	}
	_ = srv.mongoDB.Collection(friendRequestsCollection).FindOne(context.Background(),
		bson.M{"_id": "req-1"}).Decode(&r)
	if r.Status != "accepted" {
		t.Errorf("reverse pending not flipped: status=%q", r.Status)
	}

	// No second row should have been created for the forward direction.
	count, _ := srv.mongoDB.Collection(friendRequestsCollection).CountDocuments(context.Background(),
		bson.M{"fromUserId": "alice", "toUserId": "bob"})
	if count != 0 {
		t.Errorf("forward row created during auto-accept: %d", count)
	}

	// Bob receives the accept push. Without this he wouldn't know his
	// pending request just became a friendship until he next polled.
	accepted := 0
	for _, p := range captured() {
		if p.Routing == "notif.friend.request_accepted" {
			accepted++
		}
	}
	if accepted != 1 {
		t.Errorf("notif.friend.request_accepted: got %d, want 1", accepted)
	}

	// Alice's presence must be hot after the auto-accept so Bob's UI
	// refresh renders her as Online. Same guarantee as the explicit
	// accept-path test.
	online, err := keys.IsOnline(context.Background(), srv.rdb, "alice")
	if err != nil {
		t.Fatalf("IsOnline(alice): %v", err)
	}
	if !online {
		t.Errorf("auto-accepter presence should be hot; got online=false")
	}
}

func TestSendFriendRequest_AlreadyFriendsViaReverseAccepted(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	ensureFriendIndexes(t, srv)
	seedFriendRequestRow(t, srv, "req-2", "bob", "alice", "accepted")

	resp, _ := srv.SendFriendRequest(authedCtx("alice"),
		&pb.SendFriendRequestRequest{TargetUsername: "bob"})
	if resp.ErrorCode != "ALREADY_FRIENDS" || resp.RequestId != "req-2" {
		t.Errorf("got %+v, want ALREADY_FRIENDS for req-2", resp)
	}
}

func TestSendFriendRequest_DuplicateForwardReturnsExisting(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	ensureFriendIndexes(t, srv)

	first, _ := srv.SendFriendRequest(authedCtx("alice"),
		&pb.SendFriendRequestRequest{TargetUsername: "bob"})
	if !first.Success {
		t.Fatalf("first send: %+v", first)
	}

	second, _ := srv.SendFriendRequest(authedCtx("alice"),
		&pb.SendFriendRequestRequest{TargetUsername: "bob"})
	if second.RequestId != first.RequestId || second.ErrorCode != "ALREADY_PENDING" {
		t.Errorf("dup send: got %+v, want same id with ALREADY_PENDING", second)
	}

	count, _ := srv.mongoDB.Collection(friendRequestsCollection).CountDocuments(context.Background(),
		bson.M{"fromUserId": "alice", "toUserId": "bob"})
	if count != 1 {
		t.Errorf("dup created %d rows, want 1", count)
	}
}

// ---------------------------------------------------------------------------
// RespondToFriendRequest
// ---------------------------------------------------------------------------

func TestRespondToFriendRequest_NotFound(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	resp, _ := srv.RespondToFriendRequest(authedCtx("bob"),
		&pb.RespondToFriendRequestRequest{RequestId: "no-such", Accept: true})
	if resp.ErrorCode != "NOT_FOUND" {
		t.Errorf("got %q, want NOT_FOUND", resp.ErrorCode)
	}
}

func TestRespondToFriendRequest_NotRecipient(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	seedFullUser(t, srv, "eve", "eve", "REFEE")
	seedFriendRequestRow(t, srv, "req-3", "alice", "bob", "pending")

	resp, _ := srv.RespondToFriendRequest(authedCtx("eve"),
		&pb.RespondToFriendRequestRequest{RequestId: "req-3", Accept: true})
	if resp.ErrorCode != "NOT_RECIPIENT" {
		t.Errorf("got %q, want NOT_RECIPIENT", resp.ErrorCode)
	}
}

func TestRespondToFriendRequest_Accept(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	// Redis is required: the accept path TouchPresences the responder
	// so the original sender's UI sees them as Online on the very next
	// GetFriendsList — see the assertion at the bottom of this test.
	attachRedis(t, srv)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	seedFriendRequestRow(t, srv, "req-4", "alice", "bob", "pending")
	captured := publishCapture(srv)

	resp, _ := srv.RespondToFriendRequest(authedCtx("bob"),
		&pb.RespondToFriendRequestRequest{RequestId: "req-4", Accept: true})
	if !resp.Success {
		t.Errorf("got %+v", resp)
	}
	var r struct {
		Status      string     `bson:"status"`
		RespondedAt *time.Time `bson:"respondedAt"`
	}
	_ = srv.mongoDB.Collection(friendRequestsCollection).FindOne(context.Background(),
		bson.M{"_id": "req-4"}).Decode(&r)
	if r.Status != "accepted" || r.RespondedAt == nil {
		t.Errorf("post-state: %+v", r)
	}

	// Original sender (alice) receives the accept push. Reject path is
	// silent on purpose — see TestRespondToFriendRequest_Reject below.
	accepted := 0
	for _, p := range captured() {
		if p.Routing == "notif.friend.request_accepted" {
			accepted++
		}
	}
	if accepted != 1 {
		t.Errorf("notif.friend.request_accepted: got %d, want 1", accepted)
	}

	// Presence must be hot for the acceptor immediately after accept,
	// so the original sender's friends-list refresh (triggered by the
	// notif.friend.request_accepted FCM tap) renders the brand-new
	// friend as Online rather than Offline. Without this guarantee the
	// sender sees a fresh friend with a stale presence flag.
	online, err := keys.IsOnline(context.Background(), srv.rdb, "bob")
	if err != nil {
		t.Fatalf("IsOnline(bob): %v", err)
	}
	if !online {
		t.Errorf("acceptor presence should be hot after accept; got online=false")
	}
}

func TestRespondToFriendRequest_Reject(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	seedFriendRequestRow(t, srv, "req-5", "alice", "bob", "pending")

	resp, _ := srv.RespondToFriendRequest(authedCtx("bob"),
		&pb.RespondToFriendRequestRequest{RequestId: "req-5", Accept: false})
	if !resp.Success {
		t.Errorf("got %+v", resp)
	}
	var r struct {
		Status string `bson:"status"`
	}
	_ = srv.mongoDB.Collection(friendRequestsCollection).FindOne(context.Background(),
		bson.M{"_id": "req-5"}).Decode(&r)
	if r.Status != "rejected" {
		t.Errorf("status=%q, want rejected", r.Status)
	}
}

func TestRespondToFriendRequest_AlreadyResponded(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	seedFriendRequestRow(t, srv, "req-6", "alice", "bob", "accepted")

	resp, _ := srv.RespondToFriendRequest(authedCtx("bob"),
		&pb.RespondToFriendRequestRequest{RequestId: "req-6", Accept: true})
	if resp.ErrorCode != "ALREADY_RESPONDED" {
		t.Errorf("got %q, want ALREADY_RESPONDED", resp.ErrorCode)
	}
}

// ---------------------------------------------------------------------------
// GetFriendsList + GetFriendRequests
// ---------------------------------------------------------------------------

func TestGetFriendsList_Symmetric(t *testing.T) {
	// Direction shouldn't matter for accepted friendships.
	srv, _, _ := scoringTestEnv(t)
	attachRedis(t, srv)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	seedFullUser(t, srv, "carol", "carol", "REFCC")
	// alice → bob (accepted, alice is fromUser)
	seedFriendRequestRow(t, srv, "req-a", "alice", "bob", "accepted")
	// carol → alice (accepted, alice is toUser)
	seedFriendRequestRow(t, srv, "req-b", "carol", "alice", "accepted")
	// alice → eve (pending — should NOT appear in friends list)
	seedFullUser(t, srv, "eve", "eve", "REFEE")
	seedFriendRequestRow(t, srv, "req-c", "alice", "eve", "pending")

	resp, err := srv.GetFriendsList(authedCtx("alice"), &pb.GetFriendsListRequest{})
	if err != nil {
		t.Fatalf("GetFriendsList: %v", err)
	}
	if len(resp.Friends) != 2 {
		t.Fatalf("got %d friends, want 2", len(resp.Friends))
	}
	got := map[string]bool{}
	for _, f := range resp.Friends {
		got[f.UserId] = true
	}
	if !got["bob"] || !got["carol"] {
		t.Errorf("missing friends: got=%v", got)
	}
}

func TestGetFriendsList_OnlineFlag(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	attachRedis(t, srv)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	seedFullUser(t, srv, "carol", "carol", "REFCC")
	seedFriendRequestRow(t, srv, "req-x", "alice", "bob", "accepted")
	seedFriendRequestRow(t, srv, "req-y", "alice", "carol", "accepted")

	// Bob is online, Carol is not.
	if err := keys.TouchPresence(context.Background(), srv.rdb, "bob"); err != nil {
		t.Fatalf("touch presence: %v", err)
	}

	resp, _ := srv.GetFriendsList(authedCtx("alice"), &pb.GetFriendsListRequest{})
	flags := map[string]bool{}
	for _, f := range resp.Friends {
		flags[f.UserId] = f.Online
	}
	if !flags["bob"] {
		t.Errorf("bob should be online")
	}
	if flags["carol"] {
		t.Errorf("carol should be offline")
	}
}

func TestGetFriendRequests_OnlyIncomingPending(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	seedFullUser(t, srv, "carol", "carol", "REFCC")
	// Incoming pending — should appear.
	seedFriendRequestRow(t, srv, "req-in", "bob", "alice", "pending")
	// Outgoing pending — should NOT appear.
	seedFriendRequestRow(t, srv, "req-out", "alice", "carol", "pending")
	// Accepted — should NOT appear.
	seedFriendRequestRow(t, srv, "req-done", "carol", "alice", "accepted")

	resp, err := srv.GetFriendRequests(authedCtx("alice"), &pb.GetFriendRequestsRequest{})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if len(resp.Incoming) != 1 || resp.Incoming[0].Id != "req-in" {
		t.Errorf("got %+v, want only req-in", resp.Incoming)
	}
}

// ---------------------------------------------------------------------------
// Heartbeat
// ---------------------------------------------------------------------------

func TestHeartbeat_TouchesPresence(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	attachRedis(t, srv)
	seedFullUser(t, srv, "alice", "alice", "REFAA")

	// Pre-state: no presence key.
	online, _ := keys.IsOnline(context.Background(), srv.rdb, "alice")
	if online {
		t.Errorf("expected offline pre-heartbeat")
	}

	if _, err := srv.Heartbeat(authedCtx("alice"), &pb.HeartbeatRequest{}); err != nil {
		t.Fatalf("Heartbeat: %v", err)
	}

	online, _ = keys.IsOnline(context.Background(), srv.rdb, "alice")
	if !online {
		t.Errorf("expected online post-heartbeat")
	}
}

// ---------------------------------------------------------------------------
// ChallengeFriend
// ---------------------------------------------------------------------------

func TestChallengeFriend_NotFriends(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")

	resp, _ := srv.ChallengeFriend(authedCtx("alice"),
		&pb.ChallengeFriendRequest{FriendUserId: "bob"})
	if resp.ErrorCode != "NOT_FRIENDS" {
		t.Errorf("got %q, want NOT_FRIENDS", resp.ErrorCode)
	}
}

func TestChallengeFriend_RejectsSelf(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	resp, _ := srv.ChallengeFriend(authedCtx("alice"),
		&pb.ChallengeFriendRequest{FriendUserId: "alice"})
	if resp.ErrorCode != "NOT_FRIENDS" {
		t.Errorf("got %q, want NOT_FRIENDS for self-challenge", resp.ErrorCode)
	}
}

func TestChallengeFriend_HappyPath(t *testing.T) {
	// Wires the full flow: friendship check passes, throttle SETNX, room
	// state in Redis, match.created + notif.friend.challenge published.
	srv, _, _ := scoringTestEnv(t)
	attachRedis(t, srv)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	seedFriendRequestRow(t, srv, "fr-1", "alice", "bob", "accepted")
	if err := keys.TouchPresence(context.Background(), srv.rdb, "bob"); err != nil {
		t.Fatalf("touch presence: %v", err)
	}

	captured := publishCapture(srv)

	resp, err := srv.ChallengeFriend(authedCtx("alice"),
		&pb.ChallengeFriendRequest{FriendUserId: "bob"})
	if err != nil {
		t.Fatalf("ChallengeFriend: %v", err)
	}
	if !resp.Success || resp.RoomId == "" {
		t.Fatalf("got %+v", resp)
	}

	// Redis: room:{id}:players hash has both users.
	players, err := srv.rdb.HGetAll(context.Background(), keys.Players(resp.RoomId)).Result()
	if err != nil {
		t.Fatalf("HGetAll players: %v", err)
	}
	if _, ok := players["alice"]; !ok {
		t.Errorf("missing alice in players: %v", players)
	}
	if _, ok := players["bob"]; !ok {
		t.Errorf("missing bob in players: %v", players)
	}

	// Both events published: match.created and notif.friend.challenge.
	pubs := captured()
	matchCreated := 0
	notif := 0
	for _, p := range pubs {
		switch p.Routing {
		case "match.created":
			matchCreated++
		case "notif.friend.challenge":
			notif++
		}
	}
	if matchCreated != 1 {
		t.Errorf("match.created publishes: got %d, want 1 (pubs=%+v)", matchCreated, pubs)
	}
	if notif != 1 {
		t.Errorf("notif.friend.challenge publishes: got %d, want 1", notif)
	}

	// Outbox row exists and is marked processed (the inline publish
	// succeeded, so the drainer won't redeliver).
	var rows []challengeNotifOutboxRow
	cur, err := srv.mongoDB.Collection(challengeNotifOutboxCollection).Find(context.Background(), bson.M{})
	if err != nil {
		t.Fatalf("outbox find: %v", err)
	}
	if err := cur.All(context.Background(), &rows); err != nil {
		t.Fatalf("outbox decode: %v", err)
	}
	if len(rows) != 1 {
		t.Fatalf("outbox rows: got %d, want 1", len(rows))
	}
	if rows[0].ProcessedAt == nil {
		t.Errorf("outbox row not marked processed: %+v", rows[0])
	}
	if rows[0].RoomID != resp.RoomId || rows[0].RecipientID != "bob" || rows[0].FromUserID != "alice" {
		t.Errorf("outbox row payload mismatch: %+v", rows[0])
	}
}

func TestChallengeFriend_OfflineHint(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	attachRedis(t, srv)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	seedFriendRequestRow(t, srv, "fr-2", "alice", "bob", "accepted")

	// Bob hasn't heartbeat'd.
	resp, _ := srv.ChallengeFriend(authedCtx("alice"),
		&pb.ChallengeFriendRequest{FriendUserId: "bob"})
	if !resp.Success || resp.ErrorCode != "FRIEND_OFFLINE" {
		t.Errorf("got %+v, want success + FRIEND_OFFLINE hint", resp)
	}
}

func TestChallengeFriend_Throttled(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	attachRedis(t, srv)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFullUser(t, srv, "bob", "bob", "REFBB")
	seedFriendRequestRow(t, srv, "fr-3", "alice", "bob", "accepted")

	if _, err := srv.ChallengeFriend(authedCtx("alice"),
		&pb.ChallengeFriendRequest{FriendUserId: "bob"}); err != nil {
		t.Fatalf("first challenge: %v", err)
	}
	resp, _ := srv.ChallengeFriend(authedCtx("alice"),
		&pb.ChallengeFriendRequest{FriendUserId: "bob"})
	if resp.ErrorCode != "THROTTLED" {
		t.Errorf("got %q, want THROTTLED", resp.ErrorCode)
	}
}

func TestChallengeFriend_DeletedUserMapsToNotFound(t *testing.T) {
	// resolvePlayer must surface mongo.ErrNoDocuments as codes.NotFound,
	// not codes.Internal — a stale JWT or deleted account is a 404, not a
	// server bug. This was issue #4 from the PR review.
	srv, _, _ := scoringTestEnv(t)
	attachRedis(t, srv)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	// Friendship row references a friend user that doesn't exist in users
	// collection — simulates a deleted account whose row was orphaned.
	seedFriendRequestRow(t, srv, "fr-deleted", "alice", "ghost", "accepted")

	_, err := srv.ChallengeFriend(authedCtx("alice"),
		&pb.ChallengeFriendRequest{FriendUserId: "ghost"})
	if status.Code(err) != codes.NotFound {
		t.Errorf("got code=%v err=%v, want NotFound", status.Code(err), err)
	}
}

func TestChallengeFriend_ReleasesThrottleOnErrorPath(t *testing.T) {
	// On any error return after the SETNX, the throttle key must be
	// released so the caller isn't locked out for 30s when no room ever
	// existed. Issue #1 from the PR review.
	srv, _, _ := scoringTestEnv(t)
	attachRedis(t, srv)
	seedFullUser(t, srv, "alice", "alice", "REFAA")
	seedFriendRequestRow(t, srv, "fr-err", "alice", "ghost", "accepted")

	_, err := srv.ChallengeFriend(authedCtx("alice"),
		&pb.ChallengeFriendRequest{FriendUserId: "ghost"})
	if status.Code(err) != codes.NotFound {
		t.Fatalf("setup precondition: want NotFound, got %v", err)
	}
	// Throttle key must be gone so a second attempt isn't blocked.
	exists, err := srv.rdb.Exists(context.Background(),
		keys.ChallengeThrottle("alice", "ghost")).Result()
	if err != nil {
		t.Fatalf("EXISTS: %v", err)
	}
	if exists != 0 {
		t.Errorf("throttle key still set after error path; want released")
	}
}

// ---------------------------------------------------------------------------
// Outbox drain worker
// ---------------------------------------------------------------------------

func TestDrainChallengeNotifOnce_RepublishesPending(t *testing.T) {
	// A row stuck without processedAt should get republished and marked
	// processed in one drain pass.
	srv, _, _ := scoringTestEnv(t)
	captured := publishCapture(srv)

	row := challengeNotifOutboxRow{
		ID:           "outbox-1",
		RecipientID:  "bob",
		FromUserID:   "alice",
		FromUsername: "alice",
		RoomID:       "room-stuck",
		CreatedAt:    time.Now().UTC().Add(-1 * time.Minute),
	}
	if _, err := srv.mongoDB.Collection(challengeNotifOutboxCollection).
		InsertOne(context.Background(), row); err != nil {
		t.Fatalf("seed outbox row: %v", err)
	}

	srv.drainChallengeNotifOnce(context.Background())

	// Republish landed.
	pubs := captured()
	got := 0
	for _, p := range pubs {
		if p.Routing == "notif.friend.challenge" {
			got++
		}
	}
	if got != 1 {
		t.Errorf("republish count: got %d, want 1", got)
	}
	// Row marked processed.
	var after challengeNotifOutboxRow
	_ = srv.mongoDB.Collection(challengeNotifOutboxCollection).
		FindOne(context.Background(), bson.M{"_id": "outbox-1"}).Decode(&after)
	if after.ProcessedAt == nil {
		t.Errorf("row not marked processed after successful republish: %+v", after)
	}
}

func TestDrainChallengeNotifOnce_SkipsProcessedRows(t *testing.T) {
	// Already-processed rows must be skipped — otherwise a healthy publish
	// would fan out duplicate FCMs every drain tick.
	srv, _, _ := scoringTestEnv(t)
	captured := publishCapture(srv)

	processed := time.Now().UTC()
	row := challengeNotifOutboxRow{
		ID:           "outbox-done",
		RecipientID:  "bob",
		FromUserID:   "alice",
		FromUsername: "alice",
		RoomID:       "room-done",
		CreatedAt:    processed.Add(-1 * time.Minute),
		ProcessedAt:  &processed,
	}
	if _, err := srv.mongoDB.Collection(challengeNotifOutboxCollection).
		InsertOne(context.Background(), row); err != nil {
		t.Fatalf("seed outbox row: %v", err)
	}

	srv.drainChallengeNotifOnce(context.Background())

	for _, p := range captured() {
		if p.Routing == "notif.friend.challenge" {
			t.Errorf("processed row was republished: %+v", p)
		}
	}
}
