package shop_test

import (
	"context"
	"errors"
	"sync"
	"testing"

	"go.mongodb.org/mongo-driver/v2/bson"

	"quiz-battle/pkg/coins"
	"quiz-battle/pkg/coins/shop"
)

func TestPurchase_HappyPath_DeductsAndAddsCosmetic(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 1000)
	d := c.Database(db)
	if err := shop.Upsert(context.Background(), d, []shop.Item{
		{ID: "frame.gold", Kind: shop.KindAvatarFrame, PriceCoins: 500, Active: true, Name: "Gold"},
	}); err != nil {
		t.Fatalf("upsert catalog: %v", err)
	}
	ledger := coins.NewLedger(c, db)
	p := shop.NewPurchase(c, d, ledger)

	res, err := p.Buy(context.Background(), uid, "frame.gold", "idem-1")
	if err != nil {
		t.Fatalf("buy: %v", err)
	}
	if res.NewBalance != 500 {
		t.Errorf("NewBalance=%d, want 500", res.NewBalance)
	}
	if !res.Owned {
		t.Errorf("Owned=false for cosmetic, want true")
	}

	// Inventory mutation committed alongside the debit.
	var u struct {
		Coins          int64    `bson:"coins"`
		OwnedCosmetics []string `bson:"ownedCosmetics"`
	}
	if err := d.Collection("users").FindOne(context.Background(), bson.M{"_id": uid}).Decode(&u); err != nil {
		t.Fatalf("read user: %v", err)
	}
	if u.Coins != 500 || len(u.OwnedCosmetics) != 1 || u.OwnedCosmetics[0] != "frame.gold" {
		t.Errorf("user state wrong: %+v", u)
	}
}

func TestPurchase_InsufficientBalance(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 100)
	d := c.Database(db)
	if err := shop.Upsert(context.Background(), d, []shop.Item{
		{ID: "frame.gold", Kind: shop.KindAvatarFrame, PriceCoins: 500, Active: true, Name: "Gold"},
	}); err != nil {
		t.Fatalf("upsert catalog: %v", err)
	}
	p := shop.NewPurchase(c, d, coins.NewLedger(c, db))

	_, err := p.Buy(context.Background(), uid, "frame.gold", "idem-x")
	if !errors.Is(err, coins.ErrInsufficientBalance) {
		t.Fatalf("got %v, want ErrInsufficientBalance", err)
	}

	bal, _ := coins.NewLedger(c, db).GetBalance(context.Background(), uid)
	if bal != 100 {
		t.Errorf("balance changed on failed buy: %d", bal)
	}
	cnt, _ := d.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": uid})
	if cnt != 0 {
		t.Errorf("ledger row written on failed buy: %d", cnt)
	}
}

func TestPurchase_IdempotentByKey(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 1000)
	d := c.Database(db)
	if err := shop.Upsert(context.Background(), d, []shop.Item{
		{ID: "name.crimson", Kind: shop.KindNameColor, PriceCoins: 150, Active: true, Name: "Crimson"},
	}); err != nil {
		t.Fatalf("upsert catalog: %v", err)
	}
	p := shop.NewPurchase(c, d, coins.NewLedger(c, db))

	r1, err := p.Buy(context.Background(), uid, "name.crimson", "idem-7")
	if err != nil {
		t.Fatal(err)
	}
	r2, err := p.Buy(context.Background(), uid, "name.crimson", "idem-7")
	if err != nil {
		t.Fatal(err)
	}
	if r1.LedgerEntryID != r2.LedgerEntryID {
		t.Errorf("idempotency broken: r1=%v r2=%v", r1, r2)
	}
	if r2.NewBalance != 850 {
		t.Errorf("retry balance wrong: %d", r2.NewBalance)
	}

	bal, _ := coins.NewLedger(c, db).GetBalance(context.Background(), uid)
	if bal != 850 {
		t.Errorf("balance double-debited: %d", bal)
	}
}

func TestPurchase_UnknownItem(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 1000)
	d := c.Database(db)
	p := shop.NewPurchase(c, d, coins.NewLedger(c, db))

	_, err := p.Buy(context.Background(), uid, "no.such.item", "idem-1")
	if !errors.Is(err, shop.ErrUnknownItem) {
		t.Errorf("got %v, want ErrUnknownItem", err)
	}
}

func TestPurchase_InactiveItem(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 1000)
	d := c.Database(db)
	if err := shop.Upsert(context.Background(), d, []shop.Item{
		{ID: "frame.retired", Kind: shop.KindAvatarFrame, PriceCoins: 100, Active: false, Name: "Retired"},
	}); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	p := shop.NewPurchase(c, d, coins.NewLedger(c, db))

	_, err := p.Buy(context.Background(), uid, "frame.retired", "idem-1")
	if !errors.Is(err, shop.ErrInactiveItem) {
		t.Errorf("got %v, want ErrInactiveItem", err)
	}
}

func TestPurchase_StreakFreeze_WeeklyCapAbortsTransaction(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 1000)
	d := c.Database(db)
	if err := shop.Upsert(context.Background(), d, []shop.Item{
		{ID: "streak_freeze.weekly", Kind: shop.KindStreakFreeze, PriceCoins: 200, Active: true, Name: "Streak Freeze"},
	}); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	p := shop.NewPurchase(c, d, coins.NewLedger(c, db))

	if _, err := p.Buy(context.Background(), uid, "streak_freeze.weekly", "idem-1"); err != nil {
		t.Fatalf("first buy: %v", err)
	}
	// Different idempotency key — the cap, not the dedup, must reject.
	_, err := p.Buy(context.Background(), uid, "streak_freeze.weekly", "idem-2")
	if !errors.Is(err, shop.ErrStreakFreezeAlreadyHeldThisWeek) {
		t.Fatalf("second buy err=%v, want ErrStreakFreezeAlreadyHeldThisWeek", err)
	}
	// Aborted txn must not have debited a second time.
	bal, _ := coins.NewLedger(c, db).GetBalance(context.Background(), uid)
	if bal != 800 {
		t.Errorf("balance after capped retry: got %d, want 800 (one debit only)", bal)
	}
}

func TestPurchase_RerollWithBadMetadata_AbortsTransaction(t *testing.T) {
	// Defence-in-depth: even though LoadFromFile rejects bad metadata at
	// deploy time, a hand-edited coin_catalog row with an invalid charges
	// value must NOT debit the user. The runtime parse aborts the txn.
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 1000)
	d := c.Database(db)
	// Bypass shop.Upsert (which would itself reject the bad row through
	// load-time validation) and write directly. Simulates a hand-edit.
	if _, err := d.Collection(shop.CatalogCollection).InsertOne(context.Background(), bson.M{
		"_id":         "reroll.broken",
		"kind":        shop.KindRerollTopic,
		"name":        "Broken Reroll",
		"description": "bad metadata",
		"priceCoins":  int64(50),
		"active":      true,
		"metadata":    bson.M{"charges": "lots"},
	}); err != nil {
		t.Fatalf("insert bad row: %v", err)
	}
	p := shop.NewPurchase(c, d, coins.NewLedger(c, db))

	if _, err := p.Buy(context.Background(), uid, "reroll.broken", "idem-1"); err == nil {
		t.Fatalf("expected error for bad charges metadata, got nil")
	}

	bal, _ := coins.NewLedger(c, db).GetBalance(context.Background(), uid)
	if bal != 1000 {
		t.Errorf("balance changed on aborted txn: %d", bal)
	}
	cnt, _ := d.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": uid})
	if cnt != 0 {
		t.Errorf("ledger row written for aborted txn: %d", cnt)
	}
}

func TestPurchase_RerollIncrementsCharges(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 1000)
	d := c.Database(db)
	if err := shop.Upsert(context.Background(), d, []shop.Item{
		{ID: "reroll.topic", Kind: shop.KindRerollTopic, PriceCoins: 50, Active: true, Name: "Re-Roll", Metadata: map[string]string{"charges": "1"}},
	}); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	p := shop.NewPurchase(c, d, coins.NewLedger(c, db))

	if _, err := p.Buy(context.Background(), uid, "reroll.topic", "idem-1"); err != nil {
		t.Fatalf("buy: %v", err)
	}
	if _, err := p.Buy(context.Background(), uid, "reroll.topic", "idem-2"); err != nil {
		t.Fatalf("buy 2: %v", err)
	}

	var u struct {
		RerollCharges int32 `bson:"rerollCharges"`
		Coins         int64 `bson:"coins"`
	}
	if err := d.Collection("users").FindOne(context.Background(), bson.M{"_id": uid}).Decode(&u); err != nil {
		t.Fatalf("read user: %v", err)
	}
	if u.RerollCharges != 2 {
		t.Errorf("rerollCharges=%d, want 2", u.RerollCharges)
	}
	if u.Coins != 900 {
		t.Errorf("coins=%d, want 900 (1000 - 50*2)", u.Coins)
	}
}

func TestPurchase_PremiumTrial_EnqueuesOutbox(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 5000)
	d := c.Database(db)
	if err := shop.Upsert(context.Background(), d, []shop.Item{
		{ID: "premium.trial.3d", Kind: shop.KindPremiumTrial, PriceCoins: 1500, Active: true, Name: "Trial", Metadata: map[string]string{"days": "3"}},
	}); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	p := shop.NewPurchase(c, d, coins.NewLedger(c, db))

	res, err := p.Buy(context.Background(), uid, "premium.trial.3d", "idem-trial")
	if err != nil {
		t.Fatalf("buy: %v", err)
	}
	if res.Owned {
		t.Errorf("premium trial should not flip Owned=true")
	}

	rows, err := shop.DequeueDue(context.Background(), d, "premium_trial", 10)
	if err != nil {
		t.Fatalf("dequeue: %v", err)
	}
	if len(rows) != 1 {
		t.Fatalf("got %d outbox rows, want 1", len(rows))
	}
	if rows[0].UserID != uid || rows[0].Payload["days"] != "3" {
		t.Errorf("outbox row shape unexpected: %+v", rows[0])
	}
}

func TestPurchase_RejectsEmptyIdempotencyKey(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 1000)
	d := c.Database(db)
	p := shop.NewPurchase(c, d, coins.NewLedger(c, db))

	if _, err := p.Buy(context.Background(), uid, "frame.gold", ""); err == nil {
		t.Errorf("expected error for empty idempotencyKey")
	}
}

func TestPurchase_ConcurrentBuysOnlyDebitOnce(t *testing.T) {
	c, db := mongoForTest(t)
	uid := seedUser(t, c, db, "u1", 1000)
	d := c.Database(db)
	if err := shop.Upsert(context.Background(), d, []shop.Item{
		{ID: "frame.gold", Kind: shop.KindAvatarFrame, PriceCoins: 500, Active: true, Name: "Gold"},
	}); err != nil {
		t.Fatalf("upsert: %v", err)
	}
	p := shop.NewPurchase(c, d, coins.NewLedger(c, db))

	var (
		wg      sync.WaitGroup
		mu      sync.Mutex
		results []*shop.PurchaseResult
		errs    []error
	)
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r, err := p.Buy(context.Background(), uid, "frame.gold", "idem-shared")
			mu.Lock()
			defer mu.Unlock()
			if err != nil {
				errs = append(errs, err)
				return
			}
			results = append(results, r)
		}()
	}
	wg.Wait()

	if len(errs) > 0 {
		t.Fatalf("unexpected errors: %v", errs)
	}
	if len(results) != 8 {
		t.Fatalf("got %d results, want 8", len(results))
	}
	first := results[0].LedgerEntryID
	for _, r := range results[1:] {
		if r.LedgerEntryID != first {
			t.Errorf("ledgerEntryID drift: %s vs %s", first, r.LedgerEntryID)
		}
	}

	bal, _ := coins.NewLedger(c, db).GetBalance(context.Background(), uid)
	if bal != 500 {
		t.Errorf("racing buys debited more than once: bal=%d", bal)
	}
	cnt, _ := d.Collection("coin_ledger").CountDocuments(context.Background(), bson.M{"userId": uid})
	if cnt != 1 {
		t.Errorf("expected 1 ledger row, got %d", cnt)
	}
}
