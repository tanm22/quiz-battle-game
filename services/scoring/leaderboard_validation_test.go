package main

import (
	"context"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/ratelimit"
	pb "quiz-battle/proto"
)

// §4.7 PR-A1: GetLeaderboard reads from Redis using req.RoomId as part
// of the key. A multi-MB room id would blow the per-keylength budget
// — bound it at the edge.
func TestGetLeaderboard_RejectsLongRoomID(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	_, err := srv.GetLeaderboard(authedCtx("u-leaderboard-roomtoolong"), &pb.GetLeaderboardRequest{
		RoomId: strings.Repeat("x", 129),
	})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("err=%v, want InvalidArgument", err)
	}
}

// §4.7 PR-A1: TimeFilter is a closed set — anything outside the four
// known values must reject rather than silently fall through to a
// default the user didn't ask for.
func TestGetGlobalLeaderboard_RejectsUnknownTimeFilter(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	_, err := srv.GetGlobalLeaderboard(authedCtx("u-global-lb-bad-filter"), &pb.GetGlobalLeaderboardRequest{
		TimeFilter: "lastdecade",
	})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("err=%v, want InvalidArgument", err)
	}
}

// §4.7 PR-A1: UpdateFCMToken caps at 10/h/user. A misbehaving client
// can't bloat fcmTokens with $addToSet noise past that.
func TestUpdateFCMToken_RateLimited(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	// Mongo: seed a user so $addToSet has a target.
	seedScoringUser(t, c, db, "u-fcm-rate", 0)

	// Redis: real instance, fresh keyspace, freshly-built limiter so
	// the test asserts the actual counter rather than a nil-safe no-op.
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: addr})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis ping: %v", err)
	}
	_ = rdb.FlushDB(context.Background())
	t.Cleanup(func() { _ = rdb.Close() })
	srv.rdb = rdb
	srv.fcmTokenLimiter = ratelimit.New(rdb, "fcm_token", 10, time.Hour)

	ctx := authedCtx("u-fcm-rate")
	for i := 0; i < 10; i++ {
		if _, err := srv.UpdateFCMToken(ctx, &pb.UpdateFCMTokenRequest{Token: "tok"}); err != nil {
			t.Fatalf("attempt %d: unexpected error: %v", i, err)
		}
	}
	_, err := srv.UpdateFCMToken(ctx, &pb.UpdateFCMTokenRequest{Token: "tok"})
	if status.Code(err) != codes.ResourceExhausted {
		t.Errorf("11th call err=%v, want ResourceExhausted", err)
	}
}
