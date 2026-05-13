package main

import (
	"context"
	"testing"
	"time"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/ratelimit"
	pb "quiz-battle/proto"
)

// §4.7 PR-B/C1 — current-round gate tests.
//
// Without this gate, a malicious / buggy client could submit answers
// for rounds 1..N at t=0 because the per-round Answers key
// (room:{id}:answers:{round}) is HSETNX-locked on first write and
// questions are pre-loaded into Redis at match-create. These tests
// drive SubmitAnswer with three round permutations against a room
// seeded at round=1 and assert the gate rejects future rounds while
// accepting the active one. Reuses attachRedisForMembership /
// seedRoom from the sibling test files.

// TestSubmitAnswer_RejectsFutureRound asserts that a member trying
// to pre-commit to round 2 while the room is still on round 1 is
// rejected with codes.InvalidArgument. This is the headline B/C1
// scenario — without the gate, the answer would be HSETNX-locked
// into room:{id}:answers:2 and applied for real once round 2 began.
func TestSubmitAnswer_RejectsFutureRound(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{
		rdb:           rdb,
		answerLimiter: ratelimit.New(rdb, "submit_answer_test_future_round", 60, time.Minute),
	}
	const (
		roomID = "r-current-round-future"
		member = "u-precommit"
	)
	seedRoom(t, rdb, roomID, member)
	if err := keys.SetRoomRound(context.Background(), rdb, roomID, 1); err != nil {
		t.Fatalf("seed round: %v", err)
	}

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{
		UserID: member, Username: member,
	})
	_, err := srv.SubmitAnswer(ctx, &pb.SubmitAnswerRequest{
		RoomId:      roomID,
		Round:       2, // ahead of the room's active round
		OptionIndex: 0,
	})
	if err == nil {
		t.Fatalf("SubmitAnswer accepted a future round; want InvalidArgument")
	}
	if got := status.Code(err); got != codes.InvalidArgument {
		t.Fatalf("got %v (%v), want InvalidArgument", got, err)
	}
}

// TestSubmitAnswer_RejectsPastRound covers the other half of the
// gate: a lagging client that finally surfaces an answer for round
// 1 while the room has advanced to round 2 must be rejected. Without
// the gate, that delayed write would land in room:{id}:answers:1 —
// which scoring has already processed — and the leaderboard.updated
// fan-out would emit a stale score event.
func TestSubmitAnswer_RejectsPastRound(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{
		rdb:           rdb,
		answerLimiter: ratelimit.New(rdb, "submit_answer_test_past_round", 60, time.Minute),
	}
	const (
		roomID = "r-current-round-past"
		member = "u-laggard"
	)
	seedRoom(t, rdb, roomID, member)
	if err := keys.SetRoomRound(context.Background(), rdb, roomID, 2); err != nil {
		t.Fatalf("seed round: %v", err)
	}

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{
		UserID: member, Username: member,
	})
	_, err := srv.SubmitAnswer(ctx, &pb.SubmitAnswerRequest{
		RoomId:      roomID,
		Round:       1, // already-closed round
		OptionIndex: 0,
	})
	if err == nil {
		t.Fatalf("SubmitAnswer accepted a past round; want InvalidArgument")
	}
	if got := status.Code(err); got != codes.InvalidArgument {
		t.Fatalf("got %v (%v), want InvalidArgument", got, err)
	}
}

// TestSubmitAnswer_AcceptsCurrentRound is the happy-path regression:
// a submission that DOES match the room's active round must still
// succeed end-to-end. Without this, an overly-strict gate (e.g.,
// req.Round > currentRound instead of !=) could pass the rejection
// tests above while silently breaking real matches.
func TestSubmitAnswer_AcceptsCurrentRound(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{
		rdb:           rdb,
		answerLimiter: ratelimit.New(rdb, "submit_answer_test_current_round", 60, time.Minute),
	}
	const (
		roomID = "r-current-round-ok"
		member = "u-good-faith"
	)
	seedRoom(t, rdb, roomID, member)
	if err := keys.SetRoomRound(context.Background(), rdb, roomID, 3); err != nil {
		t.Fatalf("seed round: %v", err)
	}

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{
		UserID: member, Username: member,
	})
	resp, err := srv.SubmitAnswer(ctx, &pb.SubmitAnswerRequest{
		RoomId:      roomID,
		Round:       3,
		OptionIndex: 1,
	})
	if err != nil {
		t.Fatalf("SubmitAnswer rejected active-round submission: %v", err)
	}
	if resp == nil || !resp.Accepted {
		t.Fatalf("SubmitAnswer returned non-accepted response: %+v", resp)
	}
}

// TestSubmitAnswer_RejectsWhenRoundMissing asserts the gate also
// catches the "match not active" edge: if the round key never got
// set (e.g., room cleanup raced ahead of a straggling submission, or
// the user is trying a freshly-fabricated roomID that somehow passed
// the membership check), the RPC must fail FailedPrecondition rather
// than silently treating round-zero as a legit answer slot.
func TestSubmitAnswer_RejectsWhenRoundMissing(t *testing.T) {
	rdb := attachRedisForMembership(t)
	srv := &quizServer{
		rdb:           rdb,
		answerLimiter: ratelimit.New(rdb, "submit_answer_test_no_round", 60, time.Minute),
	}
	const (
		roomID = "r-current-round-missing"
		member = "u-ghost"
	)
	seedRoom(t, rdb, roomID, member) // member present, but no SetRoomRound

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{
		UserID: member, Username: member,
	})
	_, err := srv.SubmitAnswer(ctx, &pb.SubmitAnswerRequest{
		RoomId:      roomID,
		Round:       1,
		OptionIndex: 0,
	})
	if err == nil {
		t.Fatalf("SubmitAnswer accepted submission with no room round set")
	}
	if got := status.Code(err); got != codes.FailedPrecondition {
		t.Fatalf("got %v (%v), want FailedPrecondition", got, err)
	}
}
