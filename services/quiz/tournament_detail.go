package main

import (
	"context"
	"errors"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/validate"
	pb "quiz-battle/proto"
)

// leaderboardLimit caps entries returned by GetTournamentLeaderboard.
// The Flutter detail screen renders the top N; deeper pagination is
// deferred until evidence justifies a cursor-based RPC.
const leaderboardLimit = 100

// GetTournament returns the full tournament document for a single id.
// Backs the Rules tab on the Flutter detail screen.
//
// Time fields (startTime, endTime, entryDeadline) are stored as
// time.Time in MongoDB (see pkg/models/models.go::Tournament) and
// emitted as unix milliseconds so the Flutter client can pass them
// straight into DateTime.fromMillisecondsSinceEpoch.
func (s *quizServer) GetTournament(ctx context.Context, req *pb.GetTournamentRequest) (*pb.GetTournamentResponse, error) {
	if _, err := auth.UserIDFromContext(ctx); err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if req.TournamentId == "" {
		return nil, status.Error(codes.InvalidArgument, "tournament_id required")
	}
	if err := validate.MaxLen(req.TournamentId, 64); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "tournament_id: %v", err)
	}

	var doc struct {
		ID               string    `bson:"_id"`
		Name             string    `bson:"name"`
		StartTime        time.Time `bson:"startTime"`
		EndTime          time.Time `bson:"endTime"`
		EntryDeadline    time.Time `bson:"entryDeadline,omitempty"`
		Status           string    `bson:"status"`
		RequiredPlan     string    `bson:"requiredPlan"`
		PrizeDescription string    `bson:"prizeDescription"`
		PrizePool        []int64   `bson:"prizePool"`
		Participants     []string  `bson:"participants"`
	}
	err := s.mongoDB.Collection("tournaments").FindOne(ctx, bson.M{"_id": req.TournamentId}).Decode(&doc)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, status.Error(codes.NotFound, "tournament not found")
		}
		return nil, status.Errorf(codes.Internal, "load tournament: %v", err)
	}

	return &pb.GetTournamentResponse{
		Tournament: &pb.Tournament{
			Id:               doc.ID,
			Name:             doc.Name,
			StartTime:        unixMilliOrZero(doc.StartTime),
			EndTime:          unixMilliOrZero(doc.EndTime),
			EntryDeadline:    unixMilliOrZero(doc.EntryDeadline),
			Status:           doc.Status,
			RequiredPlan:     doc.RequiredPlan,
			PrizeDescription: doc.PrizeDescription,
			PrizePool:        doc.PrizePool,
			ParticipantCount: int32(len(doc.Participants)),
		},
	}, nil
}

// GetTournamentLeaderboard returns standings sorted by score desc with
// 1-based rank field. Capped at leaderboardLimit. Backs the Live tab
// on the Flutter detail screen, polled every 10s while foregrounded.
//
// We don't filter by an active-tournament status check here — viewing
// the standings of a just-finished tournament should still work (PR 2's
// results screen will reuse this RPC). The auth guard is intentionally
// lighter than JoinTournament's premium check: anyone authenticated
// can read the leaderboard, including users who never joined.
func (s *quizServer) GetTournamentLeaderboard(ctx context.Context, req *pb.GetTournamentLeaderboardRequest) (*pb.GetTournamentLeaderboardResponse, error) {
	if _, err := auth.UserIDFromContext(ctx); err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if req.TournamentId == "" {
		return nil, status.Error(codes.InvalidArgument, "tournament_id required")
	}
	if err := validate.MaxLen(req.TournamentId, 64); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "tournament_id: %v", err)
	}

	// Sort by score desc; on ties, the player who reached that score
	// first ranks higher. updatedAt is set by scoring's upsert in
	// services/scoring/main.go:1689 on every standings write, so the
	// secondary key is reliably present in production. Without it, two
	// players with identical scores would receive arbitrary ranks N and
	// N+1 on every poll — and ranks drive prize payouts.
	cursor, err := s.mongoDB.Collection("tournament_standings").Find(ctx,
		bson.M{"tournamentId": req.TournamentId},
		options.Find().
			SetSort(bson.D{{Key: "score", Value: -1}, {Key: "updatedAt", Value: 1}}).
			SetLimit(leaderboardLimit))
	if err != nil {
		return nil, status.Errorf(codes.Internal, "find standings: %v", err)
	}
	defer cursor.Close(ctx)

	var docs []struct {
		UserID   string `bson:"userId"`
		Username string `bson:"username"`
		Score    int64  `bson:"score"`
		Plan     string `bson:"plan,omitempty"`
	}
	if err := cursor.All(ctx, &docs); err != nil {
		return nil, status.Errorf(codes.Internal, "decode standings: %v", err)
	}

	out := &pb.GetTournamentLeaderboardResponse{
		Entries: make([]*pb.TournamentStandingEntry, 0, len(docs)),
	}
	for i, d := range docs {
		out.Entries = append(out.Entries, &pb.TournamentStandingEntry{
			UserId:   d.UserID,
			Username: d.Username,
			Score:    d.Score,
			Rank:     int32(i + 1),
			Plan:     d.Plan,
		})
	}
	return out, nil
}

// unixMilliOrZero returns t.UnixMilli() for non-zero times, and 0 for
// the time.Time zero value. Lets callers leave optional fields like
// entryDeadline unset in seed docs without serialising a misleading
// 1970-01-01 timestamp to the client.
func unixMilliOrZero(t time.Time) int64 {
	if t.IsZero() {
		return 0
	}
	return t.UnixMilli()
}
