package shop_test

import (
	"context"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"go.mongodb.org/mongo-driver/v2/bson"

	"quiz-battle/pkg/coins/shop"
)

func TestUpsertAndGetActive(t *testing.T) {
	c, db := mongoForTest(t)
	d := c.Database(db)

	items := []shop.Item{
		{ID: "a", Kind: shop.KindAvatarFrame, Name: "A", PriceCoins: 100, Active: true},
		{ID: "b", Kind: shop.KindAvatarFrame, Name: "B", PriceCoins: 100, Active: false},
	}
	if err := shop.Upsert(context.Background(), d, items); err != nil {
		t.Fatalf("upsert: %v", err)
	}

	out, err := shop.GetActiveItems(context.Background(), d)
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	if len(out) != 1 || out[0].ID != "a" {
		t.Errorf("got %+v, want only active item a", out)
	}
}

func TestUpsertIsIdempotent(t *testing.T) {
	c, db := mongoForTest(t)
	d := c.Database(db)

	items := []shop.Item{
		{ID: "a", Kind: shop.KindAvatarFrame, Name: "A", PriceCoins: 100, Active: true},
	}
	if err := shop.Upsert(context.Background(), d, items); err != nil {
		t.Fatalf("first upsert: %v", err)
	}
	// Re-run with a different name — second Upsert should overwrite, not duplicate.
	items[0].Name = "Renamed"
	if err := shop.Upsert(context.Background(), d, items); err != nil {
		t.Fatalf("second upsert: %v", err)
	}

	got, err := shop.GetItem(context.Background(), d, "a")
	if err != nil {
		t.Fatalf("get item: %v", err)
	}
	if got.Name != "Renamed" {
		t.Errorf("upsert didn't overwrite: name=%q", got.Name)
	}
	count, _ := d.Collection(shop.CatalogCollection).CountDocuments(context.Background(), bson.M{})
	if count != 1 {
		t.Errorf("upsert duplicated rows: count=%d", count)
	}
}

func TestLoadFromFile_RejectsInvalid(t *testing.T) {
	dir := t.TempDir()
	path := filepath.Join(dir, "items.json")

	// Missing PriceCoins (zero) should fail validation.
	bad := []map[string]any{{"id": "x", "kind": "cosmetic.avatar_frame", "name": "X"}}
	raw, _ := json.Marshal(bad)
	if err := os.WriteFile(path, raw, 0o600); err != nil {
		t.Fatalf("write fixture: %v", err)
	}
	if _, err := shop.LoadFromFile(path); err == nil {
		t.Errorf("expected error for zero price item")
	}
}

func TestLoadFromFile_ParsesShippedCatalog(t *testing.T) {
	// Smoke test: the JSON we ship in seed/shop_items.json must round-trip
	// through LoadFromFile. Walks up two dirs because tests run from the
	// package's working directory (pkg/coins/shop).
	repoRoot, err := filepath.Abs(filepath.Join("..", "..", ".."))
	if err != nil {
		t.Fatalf("resolve repo root: %v", err)
	}
	items, err := shop.LoadFromFile(filepath.Join(repoRoot, "seed", "shop_items.json"))
	if err != nil {
		t.Fatalf("load shipped catalog: %v", err)
	}
	if len(items) < 5 {
		t.Errorf("expected at least 5 catalog items, got %d", len(items))
	}
}
