package main

import (
	"context"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	pb "quiz-battle/proto"
)

// GetCoinBalance returns the authenticated user's current coin balance.
// Reads from users.coins, which is consistent-by-construction with the
// ledger because every $inc on that field happens inside the same Mongo
// transaction as the matching coin_ledger insert (see pkg/coins/ledger.go).
func (s *scoringServer) GetCoinBalance(ctx context.Context, _ *pb.GetCoinBalanceRequest) (*pb.GetCoinBalanceResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	bal, err := s.ledger.GetBalance(ctx, userID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "balance: %v", err)
	}
	return &pb.GetCoinBalanceResponse{Balance: bal}, nil
}

// GetCoinLedger returns the user's ledger entries newest-first, paged.
// Empty page_token requests page 1; the returned next_page_token is empty
// when there are no further entries. page_size is clamped to [1, 100]
// (default 25) inside the ledger primitive.
func (s *scoringServer) GetCoinLedger(ctx context.Context, req *pb.GetCoinLedgerRequest) (*pb.GetCoinLedgerResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	rows, next, err := s.ledger.GetLedger(ctx, userID, req.PageSize, req.PageToken)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "ledger: %v", err)
	}
	out := make([]*pb.CoinLedgerEntry, 0, len(rows))
	for _, r := range rows {
		out = append(out, &pb.CoinLedgerEntry{
			Id:              r.ID,
			Delta:           r.Delta,
			Reason:          r.Reason,
			RefId:           r.RefID,
			BalanceAfter:    r.BalanceAfter,
			CreatedAtUnixMs: r.CreatedAt.UnixMilli(),
			Metadata:        r.Metadata,
		})
	}
	return &pb.GetCoinLedgerResponse{Entries: out, NextPageToken: next}, nil
}
