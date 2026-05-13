package main

import (
	"context"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	pb "quiz-battle/proto"
)

// TestQuizServiceEnforcement_RejectsUnauthenticated proves every
// authenticated quiz-service RPC rejects calls without a JWT. The
// unary interceptor is wired in main.go without any skip-method
// entries; this test exists so a refactor that drops the wiring
// surfaces immediately, and because GetTournamentList specifically
// is a tempting "browse before login" RPC where future re-listing
// onto a skip list would silently expose premium tournaments to
// anonymous callers.
func TestQuizServiceEnforcement_RejectsUnauthenticated(t *testing.T) {
	srv := newTestQuizServer(t)
	ctx := context.Background() // no JWT

	cases := []struct {
		method string
		call   func() error
	}{
		{"GetTournamentList", func() error {
			_, err := srv.GetTournamentList(ctx, &pb.GetTournamentListRequest{})
			return err
		}},
		{"GetRoomQuestions", func() error {
			_, err := srv.GetRoomQuestions(ctx, &pb.GetRoomQuestionsRequest{RoomId: "r"})
			return err
		}},
		{"SubmitAnswer", func() error {
			_, err := srv.SubmitAnswer(ctx, &pb.SubmitAnswerRequest{RoomId: "r"})
			return err
		}},
		{"JoinTournament", func() error {
			_, err := srv.JoinTournament(ctx, &pb.JoinTournamentRequest{TournamentId: "t"})
			return err
		}},
	}
	for _, tc := range cases {
		t.Run(tc.method, func(t *testing.T) {
			err := tc.call()
			if status.Code(err) != codes.Unauthenticated {
				t.Errorf("%s without JWT: got code=%v err=%v, want Unauthenticated",
					tc.method, status.Code(err), err)
			}
		})
	}
}
