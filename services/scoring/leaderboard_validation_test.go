package main

import (
	"strings"
	"testing"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

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
