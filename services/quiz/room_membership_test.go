package main

import (
	"context"
	"os"
	"testing"

	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/keys"
)

// attachRedisForMembership returns a flushed Redis client for tests that
// exercise the room-membership gate. Mirrors the skip-on-no-Redis pattern
// already used by services/scoring/friends_test.go so CI without a live
// Redis service still passes (the tests just skip).
func attachRedisForMembership(t *testing.T) *redis.Client {
	t.Helper()
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: addr})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis ping: %v", err)
	}
	if err := rdb.FlushDB(context.Background()).Err(); err != nil {
		t.Fatalf("redis flush: %v", err)
	}
	t.Cleanup(func() { _ = rdb.Close() })
	return rdb
}

func TestRequireRoomMember_AllowsRegisteredPlayer(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{rdb: rdb}
	ctx := context.Background()
	const roomID, userID = "r-membership-allow", "u-member"

	if err := keys.SetPlayer(ctx, rdb, roomID, userID, `{"username":"alice","plan":"free"}`); err != nil {
		t.Fatalf("seed player: %v", err)
	}

	if err := srv.requireRoomMember(ctx, roomID, userID); err != nil {
		t.Fatalf("member rejected: %v", err)
	}
}

func TestRequireRoomMember_DeniesOutsider(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{rdb: rdb}
	ctx := context.Background()
	const roomID, member, outsider = "r-membership-deny", "u-member", "u-outsider"

	if err := keys.SetPlayer(ctx, rdb, roomID, member, `{"username":"alice","plan":"free"}`); err != nil {
		t.Fatalf("seed player: %v", err)
	}

	err := srv.requireRoomMember(ctx, roomID, outsider)
	if err == nil {
		t.Fatalf("outsider was allowed in")
	}
	if got := status.Code(err); got != codes.PermissionDenied {
		t.Fatalf("want PermissionDenied, got %v (%v)", got, err)
	}
}

func TestRequireRoomMember_DeniesUnknownRoom(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{rdb: rdb}
	ctx := context.Background()

	err := srv.requireRoomMember(ctx, "r-does-not-exist", "u-any")
	if got := status.Code(err); got != codes.PermissionDenied {
		t.Fatalf("want PermissionDenied for unknown room, got %v (%v)", got, err)
	}
}
