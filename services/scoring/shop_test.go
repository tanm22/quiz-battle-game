package main

import (
	"context"
	"fmt"
	"os"
	"strings"
	"testing"
	"time"

	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/coins"
	"quiz-battle/pkg/coins/shop"
	"quiz-battle/pkg/ratelimit"
	pb "quiz-battle/proto"
)

// shopTestEnv extends the scoringTestEnv from coins_test.go with the
// purchase orchestrator + mongoClient handle the shop RPCs require, and
// upserts a small fixture catalog so tests can buy without re-declaring
// the rows in every assertion.
func shopTestEnv(t *testing.T) (*scoringServer, string) {
	t.Helper()
	srv, c, db := scoringTestEnv(t)
	srv.mongoClient = c
	srv.purchase = shop.NewPurchase(c, srv.mongoDB, srv.ledger)

	if err := shop.Upsert(context.Background(), srv.mongoDB, []shop.Item{
		{ID: "frame.gold", Kind: shop.KindAvatarFrame, Name: "Gold Frame", PriceCoins: 500, Active: true},
		{ID: "frame.retired", Kind: shop.KindAvatarFrame, Name: "Retired", PriceCoins: 100, Active: false},
		{ID: "streak_freeze.weekly", Kind: shop.KindStreakFreeze, Name: "Streak Freeze", PriceCoins: 200, Active: true},
	}); err != nil {
		t.Fatalf("seed catalog: %v", err)
	}
	return srv, db
}

func authedCtx(uid string) context.Context {
	return auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: uid})
}

func TestGetShopCatalog_RequiresAuth(t *testing.T) {
	srv, _ := shopTestEnv(t)
	_, err := srv.GetShopCatalog(context.Background(), &pb.GetShopCatalogRequest{})
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("got %v, want Unauthenticated", err)
	}
}

func TestGetShopCatalog_OmitsInactive(t *testing.T) {
	srv, db := shopTestEnv(t)
	seedScoringUser(t, srv.mongoClient, db, "alice", 0)

	resp, err := srv.GetShopCatalog(authedCtx("alice"), &pb.GetShopCatalogRequest{})
	if err != nil {
		t.Fatalf("catalog: %v", err)
	}
	for _, it := range resp.Items {
		if it.Id == "frame.retired" {
			t.Errorf("inactive item leaked into catalog: %+v", it)
		}
	}
	// Sanity: at least one item present.
	if len(resp.Items) == 0 {
		t.Errorf("catalog empty")
	}
}

func TestGetShopInventory_MissingUserReturnsNotFound(t *testing.T) {
	srv, _ := shopTestEnv(t)
	// JWT for a user that doesn't exist (rare but possible — DeleteAccount
	// races against a cached client token). Should map to NotFound, not
	// Internal, so the client can render a clean message.
	_, err := srv.GetShopInventory(authedCtx("ghost"), &pb.GetShopInventoryRequest{})
	if status.Code(err) != codes.NotFound {
		t.Fatalf("got %v, want NotFound", err)
	}
}

func TestGetShopInventory_ReturnsUserState(t *testing.T) {
	srv, db := shopTestEnv(t)
	seedScoringUser(t, srv.mongoClient, db, "alice", 750)
	if _, err := srv.mongoDB.Collection("users").UpdateOne(
		context.Background(),
		bson.M{"_id": "alice"},
		bson.M{"$set": bson.M{
			"ownedCosmetics":      []string{"frame.gold"},
			"equippedCosmeticId":  "frame.gold",
			"rerollCharges":       int32(2),
			"streakFreezeHeld":    true,
			"streakFreezeWeekISO": "2026-W17",
		}},
	); err != nil {
		t.Fatalf("seed inventory: %v", err)
	}

	resp, err := srv.GetShopInventory(authedCtx("alice"), &pb.GetShopInventoryRequest{})
	if err != nil {
		t.Fatalf("inventory: %v", err)
	}
	if resp.Balance != 750 {
		t.Errorf("balance=%d, want 750", resp.Balance)
	}
	if resp.RerollCharges != 2 {
		t.Errorf("rerollCharges=%d, want 2", resp.RerollCharges)
	}
	if !resp.StreakFreezeHeld || resp.StreakFreezeWeekIso != "2026-W17" {
		t.Errorf("streakFreeze fields wrong: %+v", resp)
	}
	if len(resp.OwnedCosmetics) != 1 || resp.EquippedCosmeticId != "frame.gold" {
		t.Errorf("cosmetic state wrong: %+v", resp)
	}
}

func TestPurchaseShopItem_HappyPath(t *testing.T) {
	srv, db := shopTestEnv(t)
	seedScoringUser(t, srv.mongoClient, db, "alice", 1000)

	resp, err := srv.PurchaseShopItem(authedCtx("alice"), &pb.PurchaseShopItemRequest{
		ItemId: "frame.gold", IdempotencyKey: "idem-1",
	})
	if err != nil {
		t.Fatalf("purchase: %v", err)
	}
	if !resp.Success || resp.ErrorCode != "" {
		t.Errorf("expected success, got %+v", resp)
	}
	if resp.NewBalance != 500 || resp.LedgerEntryId == "" {
		t.Errorf("response shape unexpected: %+v", resp)
	}
}

func TestPurchaseShopItem_Insufficient(t *testing.T) {
	srv, db := shopTestEnv(t)
	seedScoringUser(t, srv.mongoClient, db, "alice", 50)

	resp, err := srv.PurchaseShopItem(authedCtx("alice"), &pb.PurchaseShopItemRequest{
		ItemId: "frame.gold", IdempotencyKey: "idem-1",
	})
	if err != nil {
		t.Fatalf("expected nil error with ErrorCode set, got %v", err)
	}
	if resp.Success || resp.ErrorCode != "INSUFFICIENT" {
		t.Errorf("got %+v, want ErrorCode=INSUFFICIENT", resp)
	}
}

func TestPurchaseShopItem_WeeklyCap(t *testing.T) {
	srv, db := shopTestEnv(t)
	seedScoringUser(t, srv.mongoClient, db, "alice", 1000)

	// First buy succeeds; second hits the same-week cap.
	if _, err := srv.PurchaseShopItem(authedCtx("alice"), &pb.PurchaseShopItemRequest{
		ItemId: "streak_freeze.weekly", IdempotencyKey: "idem-1",
	}); err != nil {
		t.Fatalf("first buy: %v", err)
	}
	resp, err := srv.PurchaseShopItem(authedCtx("alice"), &pb.PurchaseShopItemRequest{
		ItemId: "streak_freeze.weekly", IdempotencyKey: "idem-2",
	})
	if err != nil {
		t.Fatalf("expected nil error with ErrorCode, got %v", err)
	}
	if resp.Success || resp.ErrorCode != "WEEKLY_CAP" {
		t.Errorf("got %+v, want ErrorCode=WEEKLY_CAP", resp)
	}
}

func TestPurchaseShopItem_UnknownItemReturnsErrorCode(t *testing.T) {
	srv, db := shopTestEnv(t)
	seedScoringUser(t, srv.mongoClient, db, "alice", 1000)

	resp, err := srv.PurchaseShopItem(authedCtx("alice"), &pb.PurchaseShopItemRequest{
		ItemId: "no.such.item", IdempotencyKey: "idem-1",
	})
	if err != nil {
		t.Fatalf("got err=%v, want nil with ErrorCode=UNKNOWN", err)
	}
	if resp.Success || resp.ErrorCode != "UNKNOWN" {
		t.Errorf("got %+v, want ErrorCode=UNKNOWN", resp)
	}
}

func TestPurchaseShopItem_RequiresAuth(t *testing.T) {
	srv, _ := shopTestEnv(t)
	_, err := srv.PurchaseShopItem(context.Background(), &pb.PurchaseShopItemRequest{
		ItemId: "frame.gold", IdempotencyKey: "idem-1",
	})
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("got %v, want Unauthenticated", err)
	}
}

func TestPurchaseShopItem_RejectsEmptyArgs(t *testing.T) {
	srv, db := shopTestEnv(t)
	seedScoringUser(t, srv.mongoClient, db, "alice", 1000)

	_, err := srv.PurchaseShopItem(authedCtx("alice"), &pb.PurchaseShopItemRequest{ItemId: "", IdempotencyKey: ""})
	if status.Code(err) != codes.InvalidArgument {
		t.Fatalf("got %v, want InvalidArgument", err)
	}
}

func TestPurchaseShopItem_RejectsOversizeItemId(t *testing.T) {
	srv, db := shopTestEnv(t)
	seedScoringUser(t, srv.mongoClient, db, "alice", 1000)
	_, err := srv.PurchaseShopItem(authedCtx("alice"),
		&pb.PurchaseShopItemRequest{
			ItemId:         strings.Repeat("x", 200),
			IdempotencyKey: "k-1",
		})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("err code = %v, want InvalidArgument", status.Code(err))
	}
}

func TestPurchaseShopItem_RejectsOversizeIdempotencyKey(t *testing.T) {
	srv, db := shopTestEnv(t)
	seedScoringUser(t, srv.mongoClient, db, "alice", 1000)
	_, err := srv.PurchaseShopItem(authedCtx("alice"),
		&pb.PurchaseShopItemRequest{
			ItemId:         "frame.gold",
			IdempotencyKey: strings.Repeat("k", 300),
		})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("err code = %v, want InvalidArgument", status.Code(err))
	}
}

// Compile-time assert: shop handlers must keep the coin reasons importable
// so reviewers can grep from this test file to the canonical constants.
var _ = coins.ReasonShopPurchase

func TestPurchaseShopItem_RateLimitedAfterBurst(t *testing.T) {
	// Mirror pkg/ratelimit/limiter_test.go::testRedis so this test
	// self-skips on machines without Redis. DB 13 is reserved for
	// scoring-side rate-limit tests (separate from DB 14 in
	// pkg/ratelimit) so a parallel run doesn't trample co-tenant keys.
	addr := os.Getenv("REDIS_ADDR")
	if addr == "" {
		addr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: addr, DB: 13})
	if err := rdb.Ping(context.Background()).Err(); err != nil {
		t.Skipf("redis ping: %v", err)
	}
	if err := rdb.FlushDB(context.Background()).Err(); err != nil {
		t.Fatalf("flushdb: %v", err)
	}
	t.Cleanup(func() { _ = rdb.Close() })

	srv, db := shopTestEnv(t)
	seedScoringUser(t, srv.mongoClient, db, "alice", 100000)
	srv.purchaseLimiter = ratelimit.New(rdb, "purchase_shop_item", 3, time.Minute)

	// Use frame.gold with distinct idempotency keys. The first call
	// succeeds and debits 500 coins; the 2nd and 3rd see ALREADY_OWNED
	// (the txn aborts cleanly, balance unchanged) and return as a
	// successful gRPC response with ErrorCode set — not a transport
	// error. Either way the limiter counter advances per call, so 3
	// calls in any business outcome exhaust the per-minute budget.
	for i := 0; i < 3; i++ {
		_, err := srv.PurchaseShopItem(authedCtx("alice"),
			&pb.PurchaseShopItemRequest{
				ItemId:         "frame.gold",
				IdempotencyKey: fmt.Sprintf("k-%d", i),
			})
		if err != nil {
			t.Fatalf("purchase %d: unexpected err: %v", i, err)
		}
	}

	// 4th request in the window should be rejected with ResourceExhausted.
	_, err := srv.PurchaseShopItem(authedCtx("alice"),
		&pb.PurchaseShopItemRequest{
			ItemId:         "frame.gold",
			IdempotencyKey: "k-overlimit",
		})
	if status.Code(err) != codes.ResourceExhausted {
		t.Errorf("over-limit purchase err code = %v, want ResourceExhausted", status.Code(err))
	}
}
