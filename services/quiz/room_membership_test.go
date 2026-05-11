package main

import (
	"bytes"
	"context"
	"encoding/json"
	"log/slog"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/metadata"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/ratelimit"
	pb "quiz-battle/proto"
)

// captureWarnLogs swaps slog.Default with a JSON-handler-backed buffer
// for the duration of the test, returning the buffer the test can read
// after the gate fires. log.FromContext derives from slog.Default, so
// this captures both warn paths in requireRoomMember.
func captureWarnLogs(t *testing.T) *bytes.Buffer {
	t.Helper()
	var buf bytes.Buffer
	prev := slog.Default()
	t.Cleanup(func() { slog.SetDefault(prev) })
	slog.SetDefault(slog.New(slog.NewJSONHandler(&buf, &slog.HandlerOptions{Level: slog.LevelDebug})))
	return &buf
}

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

	if err := srv.requireRoomMember(ctx, roomID, userID, "test"); err != nil {
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

	err := srv.requireRoomMember(ctx, roomID, outsider, "test")
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

	err := srv.requireRoomMember(ctx, "r-does-not-exist", "u-any", "test")
	if got := status.Code(err); got != codes.PermissionDenied {
		t.Fatalf("want PermissionDenied for unknown room, got %v (%v)", got, err)
	}
}

// TestRequireRoomMember_LogsOpDiscriminator asserts that the warn line
// emitted on the deny path carries the op identifier passed by the
// caller. Without it, ops can't distinguish a denial from
// StreamGameEvents vs SubmitAnswer vs GetRoomQuestions by log message
// alone — the discriminator is what makes greppable alerting possible.
func TestRequireRoomMember_LogsOpDiscriminator(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{rdb: rdb}
	buf := captureWarnLogs(t)
	ctx := context.Background()

	err := srv.requireRoomMember(ctx, "r-unknown-for-op-test", "u-outsider", "submit")
	if got := status.Code(err); got != codes.PermissionDenied {
		t.Fatalf("want PermissionDenied, got %v (%v)", got, err)
	}

	// One warn line per gate call; parse the last JSON object emitted.
	lines := strings.Split(strings.TrimSpace(buf.String()), "\n")
	if len(lines) == 0 || lines[0] == "" {
		t.Fatalf("expected warn log output, got none")
	}
	var entry map[string]any
	if err := json.Unmarshal([]byte(lines[len(lines)-1]), &entry); err != nil {
		t.Fatalf("warn log was not JSON: %v\n%s", err, buf.String())
	}
	if entry["op"] != "submit" {
		t.Fatalf("op = %v, want \"submit\" (full entry: %v)", entry["op"], entry)
	}
}

// ---------------------------------------------------------------------------
// RPC call-site regression tests. The helper tests above prove
// requireRoomMember does the right thing in isolation; these prove the
// three RPCs actually wire it in. Without these, a refactor that
// silently drops a `requireRoomMember(...)` call would still pass
// `go test ./services/quiz/...` — the call site IS the security control.
// ---------------------------------------------------------------------------

// seedMemberRoom registers one legitimate member in roomID's players
// hash and returns a context carrying outsider's claims, ready to feed
// into an RPC. Centralises the boilerplate shared by the three RPC
// regression tests.
func seedMemberRoom(t *testing.T, rdb *redis.Client, roomID, member, outsider string) context.Context {
	t.Helper()
	if err := keys.SetPlayer(context.Background(), rdb, roomID, member, `{"username":"alice","plan":"free"}`); err != nil {
		t.Fatalf("seed player: %v", err)
	}
	return auth.ContextWithClaims(context.Background(), &auth.Claims{
		UserID:   outsider,
		Username: "intruder",
	})
}

func TestSubmitAnswer_DeniesNonMember(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{
		rdb:           rdb,
		answerLimiter: ratelimit.New(rdb, "submit_answer_test", 60, time.Minute),
	}
	ctx := seedMemberRoom(t, rdb, "r-rpc-submit", "u-member", "u-outsider")

	_, err := srv.SubmitAnswer(ctx, &pb.SubmitAnswerRequest{
		RoomId:      "r-rpc-submit",
		Round:       1,
		OptionIndex: 0,
	})
	if got := status.Code(err); got != codes.PermissionDenied {
		t.Fatalf("SubmitAnswer outsider: want PermissionDenied, got %v (%v)", got, err)
	}
}

func TestGetRoomQuestions_DeniesNonMember(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{rdb: rdb}
	ctx := seedMemberRoom(t, rdb, "r-rpc-questions", "u-member", "u-outsider")

	_, err := srv.GetRoomQuestions(ctx, &pb.GetRoomQuestionsRequest{RoomId: "r-rpc-questions"})
	if got := status.Code(err); got != codes.PermissionDenied {
		t.Fatalf("GetRoomQuestions outsider: want PermissionDenied, got %v (%v)", got, err)
	}
}

// fakeStreamGameEventsServer is a minimal pb.QuizService_StreamGameEventsServer
// (which aliases grpc.ServerStreamingServer[pb.GameEvent]). Only Context() is
// exercised by the gate — Send and the metadata accessors are unreachable
// because requireRoomMember returns the error before reaching the channel
// loop. If a future refactor lets a non-member past the gate, those methods
// would start being called and the test would fail with a more obvious mode
// (e.g., panic on nil send chan).
type fakeStreamGameEventsServer struct {
	ctx context.Context
}

func (f *fakeStreamGameEventsServer) Send(*pb.GameEvent) error     { return nil }
func (f *fakeStreamGameEventsServer) SetHeader(metadata.MD) error  { return nil }
func (f *fakeStreamGameEventsServer) SendHeader(metadata.MD) error { return nil }
func (f *fakeStreamGameEventsServer) SetTrailer(metadata.MD)       {}
func (f *fakeStreamGameEventsServer) Context() context.Context     { return f.ctx }
func (f *fakeStreamGameEventsServer) SendMsg(any) error            { return nil }
func (f *fakeStreamGameEventsServer) RecvMsg(any) error            { return nil }

func TestStreamGameEvents_DeniesNonMember(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{rdb: rdb}
	ctx := seedMemberRoom(t, rdb, "r-rpc-stream", "u-member", "u-outsider")

	err := srv.StreamGameEvents(
		&pb.StreamGameEventsRequest{RoomId: "r-rpc-stream"},
		&fakeStreamGameEventsServer{ctx: ctx},
	)
	if got := status.Code(err); got != codes.PermissionDenied {
		t.Fatalf("StreamGameEvents outsider: want PermissionDenied, got %v (%v)", got, err)
	}
}
