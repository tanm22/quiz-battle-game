package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	pb "quiz-battle/proto"
)

// newTestQuizServer wires up a minimal quizServer backed by a real Mongo
// database scoped to this single test. Mirrors the pattern in
// services/auth/testhelpers_test.go::newTestAuthServer — the §4.2 detail
// + leaderboard handlers only touch mongoDB, so the other quizServer
// fields (rdb, AMQP, etc.) can stay nil.
//
// Returns nil + skips the test when Mongo isn't reachable so unit-only
// runs (CI without docker compose) stay green.
func newTestQuizServer(t *testing.T) *quizServer {
	t.Helper()

	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		uri = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	client, err := mongo.Connect(options.Client().ApplyURI(uri))
	if err != nil {
		t.Skipf("mongo.Connect: %v (is docker compose up?)", err)
	}
	if err := client.Ping(ctx, nil); err != nil {
		t.Skipf("mongo.Ping: %v (is docker compose up?)", err)
	}

	suffix := strings.ReplaceAll(t.Name(), "/", "_")
	if len(suffix) > 24 {
		suffix = suffix[:24]
	}
	dbName := fmt.Sprintf("quiztest_%d_%s", time.Now().UnixNano(), suffix)
	db := client.Database(dbName)

	t.Cleanup(func() {
		_ = db.Drop(context.Background())
		_ = client.Disconnect(context.Background())
	})

	return &quizServer{mongoDB: db}
}

// authedCtx returns a context with the given user id attached, mirroring
// what the gRPC interceptor would inject in production. We don't need a
// real JWT because the handler reads the userId via auth.UserIDFromContext.
func authedCtx(userID string) context.Context {
	return auth.ContextWithClaims(context.Background(),
		&auth.Claims{UserID: userID, Username: userID})
}

func TestGetTournament_ReturnsFullDoc(t *testing.T) {
	srv := newTestQuizServer(t)
	id := bson.NewObjectID().Hex()
	now := time.Now().UTC()
	if _, err := srv.mongoDB.Collection("tournaments").InsertOne(context.Background(), bson.M{
		"_id":              id,
		"name":             "Weekend Warriors",
		"startTime":        now.Add(time.Hour),
		"endTime":          now.Add(24 * time.Hour),
		"entryDeadline":    now.Add(30 * time.Minute),
		"status":           "upcoming",
		"requiredPlan":     "free",
		"prizeDescription": "Top 3 win 500/300/100 coins",
		"prizePool":        []int64{500, 300, 100},
		"participants":     []string{"alice", "bob"},
	}); err != nil {
		t.Fatalf("seed: %v", err)
	}

	resp, err := srv.GetTournament(authedCtx("alice"),
		&pb.GetTournamentRequest{TournamentId: id})
	if err != nil {
		t.Fatalf("GetTournament: %v", err)
	}
	if resp.Tournament == nil {
		t.Fatal("Tournament nil")
	}
	if resp.Tournament.Name != "Weekend Warriors" {
		t.Errorf("name = %q, want Weekend Warriors", resp.Tournament.Name)
	}
	if resp.Tournament.Status != "upcoming" {
		t.Errorf("status = %q, want upcoming", resp.Tournament.Status)
	}
	if resp.Tournament.RequiredPlan != "free" {
		t.Errorf("requiredPlan = %q, want free", resp.Tournament.RequiredPlan)
	}
	if resp.Tournament.PrizeDescription != "Top 3 win 500/300/100 coins" {
		t.Errorf("prizeDescription = %q", resp.Tournament.PrizeDescription)
	}
	if len(resp.Tournament.PrizePool) != 3 {
		t.Errorf("prize pool len = %d, want 3", len(resp.Tournament.PrizePool))
	}
	if resp.Tournament.ParticipantCount != 2 {
		t.Errorf("participant count = %d, want 2", resp.Tournament.ParticipantCount)
	}
	// Time fields are emitted as unix milliseconds. Sanity-check they
	// round-trip near the seeded values (exact equality breaks because
	// Mongo stores millisecond precision and Go time.Time is nanosecond).
	if resp.Tournament.StartTime <= 0 {
		t.Errorf("startTime = %d, want > 0", resp.Tournament.StartTime)
	}
	if resp.Tournament.EndTime <= resp.Tournament.StartTime {
		t.Errorf("endTime (%d) should be after startTime (%d)",
			resp.Tournament.EndTime, resp.Tournament.StartTime)
	}
}

func TestGetTournament_NotFoundReturnsNotFound(t *testing.T) {
	srv := newTestQuizServer(t)
	_, err := srv.GetTournament(authedCtx("alice"),
		&pb.GetTournamentRequest{TournamentId: bson.NewObjectID().Hex()})
	if status.Code(err) != codes.NotFound {
		t.Errorf("err code = %v, want NotFound", status.Code(err))
	}
}

// Auth + arg-validation tests use a bare zero-value server because the
// guards short-circuit before any Mongo access — no need to require a
// live database for these.
func TestGetTournament_RequiresAuth(t *testing.T) {
	srv := &quizServer{}
	_, err := srv.GetTournament(context.Background(),
		&pb.GetTournamentRequest{TournamentId: "anything"})
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("err code = %v, want Unauthenticated", status.Code(err))
	}
}

func TestGetTournament_RejectsEmptyID(t *testing.T) {
	srv := &quizServer{}
	_, err := srv.GetTournament(authedCtx("alice"),
		&pb.GetTournamentRequest{TournamentId: ""})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("err code = %v, want InvalidArgument", status.Code(err))
	}
}

func TestGetTournamentLeaderboard_ReturnsTopSortedByScore(t *testing.T) {
	srv := newTestQuizServer(t)
	tid := bson.NewObjectID().Hex()
	if _, err := srv.mongoDB.Collection("tournament_standings").InsertMany(context.Background(), []any{
		bson.M{"_id": tid + ":alice", "tournamentId": tid, "userId": "alice", "username": "alice", "score": int64(500)},
		bson.M{"_id": tid + ":bob", "tournamentId": tid, "userId": "bob", "username": "bob", "score": int64(900)},
		bson.M{"_id": tid + ":carol", "tournamentId": tid, "userId": "carol", "username": "carol", "score": int64(700)},
	}); err != nil {
		t.Fatalf("seed: %v", err)
	}

	resp, err := srv.GetTournamentLeaderboard(authedCtx("alice"),
		&pb.GetTournamentLeaderboardRequest{TournamentId: tid})
	if err != nil {
		t.Fatalf("GetTournamentLeaderboard: %v", err)
	}
	if len(resp.Entries) != 3 {
		t.Fatalf("entries len = %d, want 3", len(resp.Entries))
	}
	if resp.Entries[0].UserId != "bob" || resp.Entries[0].Rank != 1 || resp.Entries[0].Score != 900 {
		t.Errorf("rank 1 = %+v, want bob/rank=1/score=900", resp.Entries[0])
	}
	if resp.Entries[1].UserId != "carol" || resp.Entries[1].Rank != 2 {
		t.Errorf("rank 2 = %+v", resp.Entries[1])
	}
	if resp.Entries[2].UserId != "alice" || resp.Entries[2].Rank != 3 {
		t.Errorf("rank 3 = %+v", resp.Entries[2])
	}
}

func TestGetTournamentLeaderboard_EmptyTournamentReturnsEmpty(t *testing.T) {
	srv := newTestQuizServer(t)
	resp, err := srv.GetTournamentLeaderboard(authedCtx("alice"),
		&pb.GetTournamentLeaderboardRequest{TournamentId: bson.NewObjectID().Hex()})
	if err != nil {
		t.Fatalf("GetTournamentLeaderboard: %v", err)
	}
	if len(resp.Entries) != 0 {
		t.Errorf("entries len = %d, want 0", len(resp.Entries))
	}
}

func TestGetTournamentLeaderboard_RequiresAuth(t *testing.T) {
	srv := &quizServer{}
	_, err := srv.GetTournamentLeaderboard(context.Background(),
		&pb.GetTournamentLeaderboardRequest{TournamentId: "anything"})
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("err code = %v, want Unauthenticated", status.Code(err))
	}
}

func TestGetTournamentLeaderboard_RejectsEmptyID(t *testing.T) {
	srv := &quizServer{}
	_, err := srv.GetTournamentLeaderboard(authedCtx("alice"),
		&pb.GetTournamentLeaderboardRequest{TournamentId: ""})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("err code = %v, want InvalidArgument", status.Code(err))
	}
}
