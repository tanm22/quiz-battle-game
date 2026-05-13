package main

import (
	"context"
	"errors"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/coins"
	"quiz-battle/pkg/coins/shop"
	"quiz-battle/pkg/validate"
	pb "quiz-battle/proto"
)

// GetShopCatalog returns every active row in coin_catalog. Authenticated
// only — anonymous storefront browsing is not supported, since the Flutter
// client always carries a JWT (guest or otherwise) by the time it reaches
// this service.
func (s *scoringServer) GetShopCatalog(ctx context.Context, _ *pb.GetShopCatalogRequest) (*pb.GetShopCatalogResponse, error) {
	if _, err := auth.UserIDFromContext(ctx); err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	items, err := shop.GetActiveItems(ctx, s.mongoDB)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "catalog: %v", err)
	}
	out := &pb.GetShopCatalogResponse{Items: make([]*pb.ShopItem, 0, len(items))}
	for _, it := range items {
		out.Items = append(out.Items, &pb.ShopItem{
			Id:          it.ID,
			Kind:        it.Kind,
			Name:        it.Name,
			Description: it.Description,
			PriceCoins:  it.PriceCoins,
			Active:      it.Active,
			Metadata:    it.Metadata,
		})
	}
	return out, nil
}

// GetShopInventory returns the authenticated user's owned cosmetics, equipped
// selections, reroll charges, streak-freeze state, and current coin balance
// in a single round-trip so the storefront can render owned-vs-buyable
// without an N+1 fetch per tile.
func (s *scoringServer) GetShopInventory(ctx context.Context, _ *pb.GetShopInventoryRequest) (*pb.GetShopInventoryResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	var u struct {
		OwnedCosmetics      []string `bson:"ownedCosmetics"`
		EquippedCosmeticID  string   `bson:"equippedCosmeticId"`
		EquippedNameColor   string   `bson:"equippedNameColor"`
		RerollCharges       int32    `bson:"rerollCharges"`
		StreakFreezeHeld    bool     `bson:"streakFreezeHeld"`
		StreakFreezeWeekISO string   `bson:"streakFreezeWeekISO"`
		Coins               int64    `bson:"coins"`
	}
	if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": uid}).Decode(&u); err != nil {
		// A JWT can outlive the user it was issued for (DeleteAccount races
		// against a cached token). Map ErrNoDocuments to NotFound so the
		// client renders "account missing" instead of a generic crash banner,
		// matching what GetCoinBalance does.
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		return nil, status.Errorf(codes.Internal, "user: %v", err)
	}
	return &pb.GetShopInventoryResponse{
		OwnedCosmetics:      u.OwnedCosmetics,
		EquippedCosmeticId:  u.EquippedCosmeticID,
		EquippedNameColor:   u.EquippedNameColor,
		RerollCharges:       u.RerollCharges,
		StreakFreezeHeld:    u.StreakFreezeHeld,
		StreakFreezeWeekIso: u.StreakFreezeWeekISO,
		Balance:             u.Coins,
	}, nil
}

// PurchaseShopItem is the spend-side of the §4.3 ledger. Hybrid error model:
// auth and argument errors come back as gRPC status errors so the Flutter
// client's interceptor can short-circuit on them; domain errors (insufficient
// balance, weekly cap, unknown/inactive item) come back as a successful
// response with ErrorCode set so the client can show the right copy without
// catching an exception. Documented in docs/api.md (PR 7).
func (s *scoringServer) PurchaseShopItem(ctx context.Context, req *pb.PurchaseShopItemRequest) (*pb.PurchaseShopItemResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	// §4.7 hardening: cap shop-purchase calls per user per minute. Same
	// pattern as referralLimiter — fail-open on Redis errors (matches
	// AllowWithLog behavior), per-subject (userId) so one user's burst
	// doesn't starve others. Idempotency keys debounce same-key spam,
	// but a fresh-key purchase loop is unbounded without this. The
	// limiter is nil-safe at the package level (pkg/ratelimit.Allow
	// returns true on nil receiver) so shopTestEnv-built servers without
	// a wired limiter pass through unchanged.
	if !s.purchaseLimiter.AllowWithLog(ctx, uid) {
		return nil, status.Error(codes.ResourceExhausted, "too many purchases; slow down")
	}
	if req.ItemId == "" || req.IdempotencyKey == "" {
		return nil, status.Error(codes.InvalidArgument, "itemId and idempotencyKey required")
	}
	if err := validate.MaxLen(req.ItemId, 64); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "item_id: %v", err)
	}
	if err := validate.MaxLen(req.IdempotencyKey, 128); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "idempotency_key: %v", err)
	}
	res, err := s.purchase.Buy(ctx, uid, req.ItemId, req.IdempotencyKey)
	if err != nil {
		switch {
		case errors.Is(err, coins.ErrInsufficientBalance):
			return &pb.PurchaseShopItemResponse{ErrorCode: "INSUFFICIENT"}, nil
		case errors.Is(err, shop.ErrInactiveItem):
			return &pb.PurchaseShopItemResponse{ErrorCode: "INACTIVE"}, nil
		case errors.Is(err, shop.ErrUnknownItem):
			return &pb.PurchaseShopItemResponse{ErrorCode: "UNKNOWN"}, nil
		case errors.Is(err, shop.ErrStreakFreezeAlreadyHeldThisWeek):
			return &pb.PurchaseShopItemResponse{ErrorCode: "WEEKLY_CAP"}, nil
		case errors.Is(err, shop.ErrAlreadyOwned):
			return &pb.PurchaseShopItemResponse{ErrorCode: "ALREADY_OWNED"}, nil
		}
		return nil, status.Errorf(codes.Internal, "purchase: %v", err)
	}
	return &pb.PurchaseShopItemResponse{
		Success:       true,
		LedgerEntryId: res.LedgerEntryID,
		NewBalance:    res.NewBalance,
	}, nil
}
