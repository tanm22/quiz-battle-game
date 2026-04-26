// Package shop owns the §4.3 storefront primitives: catalog records, the
// per-user inventory mutations, and the Purchase orchestrator that ties a
// coin debit to its in-app effect inside one Mongo transaction.
//
// Catalog rows live in the `coin_catalog` collection, seeded from
// seed/shop_items.json by the seed binary on every start. The Item.Kind
// constant tells Purchase.Buy which inventory branch to take; Metadata is
// a free-form key/value bag used by the kind-specific code (e.g. premium
// trial duration in days, re-roll charge count).
package shop

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"strconv"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// Kind* constants enumerate the supported item kinds. Each kind is dispatched
// to a distinct branch in Purchase.Buy; adding a new kind means adding a
// constant here AND a switch arm there AND an entry in validKinds below so
// LoadFromFile rejects catalog rows it can't dispatch.
const (
	KindAvatarFrame  = "cosmetic.avatar_frame"
	KindNameColor    = "cosmetic.name_color"
	KindStreakFreeze = "streak_freeze"
	KindPremiumTrial = "premium_trial"
	KindRerollTopic  = "reroll_topic"
)

// validKinds is the authoritative allowlist for catalog rows. LoadFromFile
// rejects any item whose Kind is not a key in this map so a typo'd kind
// (e.g. "cosmetic.avatar_fram") fails loudly at deploy time instead of
// surfacing as a codes.Internal at first-purchase time when applyEffect's
// default arm fires.
var validKinds = map[string]struct{}{
	KindAvatarFrame:  {},
	KindNameColor:    {},
	KindStreakFreeze: {},
	KindPremiumTrial: {},
	KindRerollTopic:  {},
}

// CatalogCollection is the Mongo collection name. Exported so tests and the
// seed binary can reach it without re-declaring the literal.
const CatalogCollection = "coin_catalog"

// Item is a single shop catalog row. Stored as a Mongo document with `_id`
// set to the human-readable id (e.g. "frame.gold") so upserts are natural
// and clients can deep-link to a stable item key.
type Item struct {
	ID          string            `bson:"_id"          json:"id"`
	Kind        string            `bson:"kind"         json:"kind"`
	Name        string            `bson:"name"         json:"name"`
	Description string            `bson:"description"  json:"description"`
	PriceCoins  int64             `bson:"priceCoins"   json:"priceCoins"`
	Active      bool              `bson:"active"       json:"active"`
	Metadata    map[string]string `bson:"metadata,omitempty" json:"metadata,omitempty"`
}

// LoadFromFile parses a JSON catalog into Items, validating that each row has
// the minimum fields a Purchase needs (id, kind, positive price). The seed
// binary calls this once at start; tests can call it on any path.
func LoadFromFile(path string) ([]Item, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read %s: %w", path, err)
	}
	var items []Item
	if err := json.Unmarshal(b, &items); err != nil {
		return nil, fmt.Errorf("parse %s: %w", path, err)
	}
	for _, it := range items {
		if it.ID == "" || it.Kind == "" || it.PriceCoins <= 0 {
			return nil, fmt.Errorf("invalid item: %+v", it)
		}
		if _, ok := validKinds[it.Kind]; !ok {
			return nil, fmt.Errorf("invalid item %s: unknown kind %q", it.ID, it.Kind)
		}
		if err := validateMetadataForKind(it); err != nil {
			return nil, err
		}
	}
	return items, nil
}

// validateMetadataForKind enforces the per-kind shape of Item.Metadata at
// load time. Without this, a typo or missing key would silently fall through
// to runtime — most dangerously, a bad "charges" value on a reroll item
// would let Purchase.Buy debit the user but apply the wrong charge count.
// Failing loudly in the seed binary is cheaper than a bug report.
func validateMetadataForKind(it Item) error {
	switch it.Kind {
	case KindRerollTopic:
		raw, ok := it.Metadata["charges"]
		if !ok {
			return fmt.Errorf("invalid item %s: %s requires metadata.charges", it.ID, it.Kind)
		}
		n, err := strconv.ParseInt(raw, 10, 32)
		if err != nil || n <= 0 {
			return fmt.Errorf("invalid item %s: metadata.charges must be a positive int, got %q", it.ID, raw)
		}
	case KindPremiumTrial:
		raw, ok := it.Metadata["days"]
		if !ok {
			return fmt.Errorf("invalid item %s: %s requires metadata.days", it.ID, it.Kind)
		}
		n, err := strconv.ParseInt(raw, 10, 32)
		if err != nil || n <= 0 {
			return fmt.Errorf("invalid item %s: metadata.days must be a positive int, got %q", it.ID, raw)
		}
	}
	return nil
}

// Upsert writes each Item into coin_catalog by _id, replacing the previous
// document. Idempotent: re-running with an unchanged JSON is a no-op write.
func Upsert(ctx context.Context, db *mongo.Database, items []Item) error {
	col := db.Collection(CatalogCollection)
	for _, it := range items {
		_, err := col.UpdateOne(ctx, bson.M{"_id": it.ID}, bson.M{"$set": it},
			options.UpdateOne().SetUpsert(true))
		if err != nil {
			return fmt.Errorf("upsert %s: %w", it.ID, err)
		}
	}
	return nil
}

// GetActiveItems returns every catalog row whose Active flag is true. Used by
// the GetShopCatalog RPC to render the storefront. Order is unspecified; the
// client is expected to group by Kind for display.
func GetActiveItems(ctx context.Context, db *mongo.Database) ([]Item, error) {
	cur, err := db.Collection(CatalogCollection).Find(ctx, bson.M{"active": true})
	if err != nil {
		return nil, err
	}
	var items []Item
	if err := cur.All(ctx, &items); err != nil {
		return nil, err
	}
	return items, nil
}

// GetItem fetches a single item by id. Returns mongo.ErrNoDocuments if the
// id isn't in the catalog so callers (Purchase.Buy) can map that to a
// domain-level "unknown item" error.
func GetItem(ctx context.Context, db *mongo.Database, id string) (*Item, error) {
	var it Item
	if err := db.Collection(CatalogCollection).FindOne(ctx, bson.M{"_id": id}).Decode(&it); err != nil {
		return nil, err
	}
	return &it, nil
}
