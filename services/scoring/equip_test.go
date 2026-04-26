package main

import (
	"context"
	"testing"

	"go.mongodb.org/mongo-driver/v2/bson"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/coins/shop"
	pb "quiz-battle/proto"
)

// upsertFrame seeds a single avatar-frame catalog row. Reused across
// equip tests; kept here rather than in shopTestEnv so each test owns
// its full fixture.
func upsertFrame(t *testing.T, srv *scoringServer, id string, active bool) {
	t.Helper()
	if err := shop.Upsert(context.Background(), srv.mongoDB, []shop.Item{{
		ID: id, Kind: shop.KindAvatarFrame, Name: id, Active: active, PriceCoins: 1,
	}}); err != nil {
		t.Fatalf("upsert frame: %v", err)
	}
}

func TestEquipCosmetic_RejectsUnauthenticated(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	if _, err := srv.EquipCosmetic(context.Background(), &pb.EquipCosmeticRequest{ItemId: "x"}); status.Code(err) != codes.Unauthenticated {
		t.Fatalf("got %v, want Unauthenticated", err)
	}
}

func TestEquipCosmetic_RejectsEmptyItem(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)
	if _, err := srv.EquipCosmetic(authedCtx("alice"), &pb.EquipCosmeticRequest{ItemId: ""}); status.Code(err) != codes.InvalidArgument {
		t.Fatalf("got %v, want InvalidArgument", err)
	}
}

func TestEquipCosmetic_UnknownItem(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)
	resp, err := srv.EquipCosmetic(authedCtx("alice"), &pb.EquipCosmeticRequest{ItemId: "no.such.item"})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if resp.ErrorCode != "UNKNOWN" {
		t.Errorf("got %q, want UNKNOWN", resp.ErrorCode)
	}
}

func TestEquipCosmetic_NotOwned(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)
	upsertFrame(t, srv, "frame.gold", true)

	resp, err := srv.EquipCosmetic(authedCtx("alice"), &pb.EquipCosmeticRequest{ItemId: "frame.gold"})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if resp.ErrorCode != "NOT_OWNED" {
		t.Errorf("got %q, want NOT_OWNED", resp.ErrorCode)
	}
}

func TestEquipCosmetic_NotEquippable(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)
	if err := shop.Upsert(context.Background(), srv.mongoDB, []shop.Item{{
		ID: "streak_freeze.weekly", Kind: shop.KindStreakFreeze, Name: "Streak Freeze",
		Active: true, PriceCoins: 1,
	}}); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	// Even when ownership is hand-set, the kind switch rejects.
	_, _ = srv.mongoDB.Collection("users").UpdateOne(context.Background(),
		bson.M{"_id": "alice"},
		bson.M{"$set": bson.M{"ownedCosmetics": []string{"streak_freeze.weekly"}}},
	)

	resp, err := srv.EquipCosmetic(authedCtx("alice"), &pb.EquipCosmeticRequest{ItemId: "streak_freeze.weekly"})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if resp.ErrorCode != "NOT_EQUIPPABLE" {
		t.Errorf("got %q, want NOT_EQUIPPABLE", resp.ErrorCode)
	}
}

func TestEquipCosmetic_HappyPath(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)
	upsertFrame(t, srv, "frame.gold", true)
	_, _ = srv.mongoDB.Collection("users").UpdateOne(context.Background(),
		bson.M{"_id": "alice"},
		bson.M{"$set": bson.M{"ownedCosmetics": []string{"frame.gold"}}},
	)

	resp, err := srv.EquipCosmetic(authedCtx("alice"), &pb.EquipCosmeticRequest{ItemId: "frame.gold"})
	if err != nil || !resp.Success {
		t.Fatalf("got err=%v resp=%+v", err, resp)
	}

	var u struct {
		EquippedCosmeticID string `bson:"equippedCosmeticId"`
	}
	_ = srv.mongoDB.Collection("users").FindOne(context.Background(), bson.M{"_id": "alice"}).Decode(&u)
	if u.EquippedCosmeticID != "frame.gold" {
		t.Errorf("equippedCosmeticId=%q, want frame.gold", u.EquippedCosmeticID)
	}
}

func TestEquipCosmetic_NameColorWritesSeparateField(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)
	if err := shop.Upsert(context.Background(), srv.mongoDB, []shop.Item{{
		ID: "name.crimson", Kind: shop.KindNameColor, Name: "Crimson", Active: true, PriceCoins: 1,
	}}); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	_, _ = srv.mongoDB.Collection("users").UpdateOne(context.Background(),
		bson.M{"_id": "alice"},
		bson.M{"$set": bson.M{"ownedCosmetics": []string{"name.crimson"}}},
	)

	resp, err := srv.EquipCosmetic(authedCtx("alice"), &pb.EquipCosmeticRequest{ItemId: "name.crimson"})
	if err != nil || !resp.Success {
		t.Fatalf("err=%v resp=%+v", err, resp)
	}

	var u struct {
		EquippedNameColor  string `bson:"equippedNameColor"`
		EquippedCosmeticID string `bson:"equippedCosmeticId"`
	}
	_ = srv.mongoDB.Collection("users").FindOne(context.Background(), bson.M{"_id": "alice"}).Decode(&u)
	if u.EquippedNameColor != "name.crimson" {
		t.Errorf("equippedNameColor=%q, want name.crimson", u.EquippedNameColor)
	}
	if u.EquippedCosmeticID != "" {
		t.Errorf("name color leaked into equippedCosmeticId: %q", u.EquippedCosmeticID)
	}
}

func TestConsumeReroll_RejectsUnauthenticated(t *testing.T) {
	srv, _, _ := scoringTestEnv(t)
	_, err := srv.ConsumeReroll(context.Background(), &pb.ConsumeRerollRequest{RoomId: "r", RoundId: "1"})
	if status.Code(err) != codes.Unauthenticated {
		t.Errorf("got %v, want Unauthenticated", err)
	}
}

func TestConsumeReroll_NoCharges(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)
	resp, err := srv.ConsumeReroll(authedCtx("alice"), &pb.ConsumeRerollRequest{RoomId: "r1", RoundId: "1"})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if resp.ErrorCode != "NO_CHARGES" {
		t.Errorf("got %q, want NO_CHARGES", resp.ErrorCode)
	}
}

func TestConsumeReroll_AcceptsEmptyRoomAndRound(t *testing.T) {
	// Review feedback (PR #15): roomId/roundId aren't required by the
	// server today; the audit-trail use case is forward-compat. Empty
	// values must take the same code path as populated ones.
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)
	_, _ = srv.mongoDB.Collection("users").UpdateOne(context.Background(),
		bson.M{"_id": "alice"},
		bson.M{"$set": bson.M{"rerollCharges": int32(1)}},
	)
	resp, err := srv.ConsumeReroll(authedCtx("alice"), &pb.ConsumeRerollRequest{})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if !resp.Success || resp.ChargesRemaining != 0 {
		t.Errorf("empty room/round: success=%v remaining=%d, want true/0", resp.Success, resp.ChargesRemaining)
	}
}

func TestConsumeReroll_DistinguishesUserNotFoundFromNoCharges(t *testing.T) {
	// Review feedback (PR #15): a deleted user with a stale-but-valid
	// JWT used to surface as NO_CHARGES — same client copy as "you've
	// used all your re-rolls." Now the FindOneAndUpdate miss is
	// disambiguated by a follow-up _id probe so a missing user gets
	// codes.NotFound and a real out-of-charges user gets NO_CHARGES.
	srv, _, _ := scoringTestEnv(t)
	// No seed — the user doesn't exist.
	_, err := srv.ConsumeReroll(authedCtx("ghost-user"), &pb.ConsumeRerollRequest{RoomId: "r1", RoundId: "1"})
	if status.Code(err) != codes.NotFound {
		t.Errorf("got %v, want codes.NotFound", err)
	}
}

func TestConsumeReroll_DecrementsAndReturnsRemaining(t *testing.T) {
	srv, c, db := scoringTestEnv(t)
	seedScoringUser(t, c, db, "alice", 0)
	_, _ = srv.mongoDB.Collection("users").UpdateOne(context.Background(),
		bson.M{"_id": "alice"},
		bson.M{"$set": bson.M{"rerollCharges": int32(3)}},
	)

	resp, err := srv.ConsumeReroll(authedCtx("alice"), &pb.ConsumeRerollRequest{RoomId: "r1", RoundId: "1"})
	if err != nil {
		t.Fatalf("err: %v", err)
	}
	if !resp.Success || resp.ChargesRemaining != 2 {
		t.Errorf("first consume: success=%v remaining=%d, want true/2", resp.Success, resp.ChargesRemaining)
	}

	resp2, _ := srv.ConsumeReroll(authedCtx("alice"), &pb.ConsumeRerollRequest{RoomId: "r1", RoundId: "2"})
	if resp2.ChargesRemaining != 1 {
		t.Errorf("second consume remaining=%d, want 1", resp2.ChargesRemaining)
	}
	resp3, _ := srv.ConsumeReroll(authedCtx("alice"), &pb.ConsumeRerollRequest{RoomId: "r1", RoundId: "3"})
	if resp3.ChargesRemaining != 0 {
		t.Errorf("third consume remaining=%d, want 0", resp3.ChargesRemaining)
	}
	resp4, _ := srv.ConsumeReroll(authedCtx("alice"), &pb.ConsumeRerollRequest{RoomId: "r1", RoundId: "4"})
	if resp4.ErrorCode != "NO_CHARGES" {
		t.Errorf("fourth consume errCode=%q, want NO_CHARGES", resp4.ErrorCode)
	}

	var u struct {
		RerollCharges int32 `bson:"rerollCharges"`
	}
	_ = srv.mongoDB.Collection("users").FindOne(context.Background(), bson.M{"_id": "alice"}).Decode(&u)
	if u.RerollCharges != 0 {
		t.Errorf("post-state rerollCharges=%d, want 0", u.RerollCharges)
	}
}
