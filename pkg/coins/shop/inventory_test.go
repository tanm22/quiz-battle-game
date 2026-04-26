package shop_test

import (
	"context"
	"errors"
	"testing"

	"go.mongodb.org/mongo-driver/v2/bson"

	"quiz-battle/pkg/coins/shop"
)

func TestAddCosmetic_HappyPath(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 0)
	inv := shop.NewInventory(c.Database(db))

	if err := inv.AddCosmetic(context.Background(), uid, "frame.gold"); err != nil {
		t.Fatalf("first add: %v", err)
	}

	var u struct {
		OwnedCosmetics []string `bson:"ownedCosmetics"`
	}
	if err := c.Database(db).Collection("users").FindOne(context.Background(), bson.M{"_id": uid}).Decode(&u); err != nil {
		t.Fatalf("read user: %v", err)
	}
	if len(u.OwnedCosmetics) != 1 || u.OwnedCosmetics[0] != "frame.gold" {
		t.Errorf("ownedCosmetics=%v, want [frame.gold]", u.OwnedCosmetics)
	}
}

func TestAddCosmetic_RejectsDuplicate(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 0)
	inv := shop.NewInventory(c.Database(db))

	if err := inv.AddCosmetic(context.Background(), uid, "frame.gold"); err != nil {
		t.Fatalf("first add: %v", err)
	}
	if err := inv.AddCosmetic(context.Background(), uid, "frame.gold"); !errors.Is(err, shop.ErrAlreadyOwned) {
		t.Errorf("second add err=%v, want ErrAlreadyOwned", err)
	}
}

func TestIncrementReroll_AddsCharges(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 0)
	inv := shop.NewInventory(c.Database(db))

	if err := inv.IncrementReroll(context.Background(), uid, 1); err != nil {
		t.Fatalf("first: %v", err)
	}
	if err := inv.IncrementReroll(context.Background(), uid, 2); err != nil {
		t.Fatalf("second: %v", err)
	}

	var u struct {
		RerollCharges int32 `bson:"rerollCharges"`
	}
	if err := c.Database(db).Collection("users").FindOne(context.Background(), bson.M{"_id": uid}).Decode(&u); err != nil {
		t.Fatalf("read user: %v", err)
	}
	if u.RerollCharges != 3 {
		t.Errorf("rerollCharges=%d, want 3", u.RerollCharges)
	}
}

func TestStreakFreeze_OncePerWeek(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 0)
	inv := shop.NewInventory(c.Database(db))

	if err := inv.ClaimStreakFreezeForWeek(context.Background(), uid); err != nil {
		t.Fatalf("first claim: %v", err)
	}
	if err := inv.ClaimStreakFreezeForWeek(context.Background(), uid); !errors.Is(err, shop.ErrStreakFreezeAlreadyHeldThisWeek) {
		t.Errorf("second claim err=%v, want ErrStreakFreezeAlreadyHeldThisWeek", err)
	}
}

func TestStreakFreeze_PreviousWeekAllowsClaim(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 0)
	// Pre-set the user's stored week to a definite past ISO label so the
	// $ne predicate matches and the claim should succeed.
	if _, err := c.Database(db).Collection("users").UpdateOne(
		context.Background(),
		bson.M{"_id": uid},
		bson.M{"$set": bson.M{"streakFreezeHeld": false, "streakFreezeWeekISO": "2024-W01"}},
	); err != nil {
		t.Fatalf("backdate: %v", err)
	}

	inv := shop.NewInventory(c.Database(db))
	if err := inv.ClaimStreakFreezeForWeek(context.Background(), uid); err != nil {
		t.Fatalf("claim after prior week: %v", err)
	}

	var u struct {
		StreakFreezeHeld    bool   `bson:"streakFreezeHeld"`
		StreakFreezeWeekISO string `bson:"streakFreezeWeekISO"`
	}
	if err := c.Database(db).Collection("users").FindOne(context.Background(), bson.M{"_id": uid}).Decode(&u); err != nil {
		t.Fatalf("read user: %v", err)
	}
	if !u.StreakFreezeHeld {
		t.Errorf("expected freeze held, got %+v", u)
	}
	if u.StreakFreezeWeekISO == "2024-W01" {
		t.Errorf("week ISO not advanced from %q", u.StreakFreezeWeekISO)
	}
}
