package main

import (
	"context"

	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	pb "quiz-battle/proto"
)

// GetCoinBalance returns the authenticated user's cached balance from
// users.coins. The cache is kept consistent with coin_ledger by every
// Grant's transaction (ADR-0001), so this is a single-document read.
func (s *scoringServer) GetCoinBalance(ctx context.Context, _ *pb.GetCoinBalanceRequest) (*pb.GetCoinBalanceResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	bal, err := s.ledger.GetBalance(ctx, userID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load balance: %v", err)
	}
	return &pb.GetCoinBalanceResponse{Balance: bal}, nil
}

// GetCoinLedger returns the authenticated user's ledger entries newest-first.
// page_size is clamped to [1, 100] (default 25); page_token is the opaque
// cursor returned by the previous page. Empty next_page_token signals the
// end of history.
func (s *scoringServer) GetCoinLedger(ctx context.Context, req *pb.GetCoinLedgerRequest) (*pb.GetCoinLedgerResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	rows, next, err := s.ledger.GetLedger(ctx, userID, req.PageSize, req.PageToken)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load ledger: %v", err)
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
