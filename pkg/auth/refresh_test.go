package auth

import (
	"context"
	"os"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// newTestMongo wires a throwaway database backed by the local rs0 replica
// set. The plan calls for ?replicaSet=rs0&directConnection=true so the
// Mongo session model the refresh-token rotation relies on (single-doc
// updates with $exists predicates) behaves identically to production.
func newTestMongo(t *testing.T) *mongo.Database {
	t.Helper()
	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		uri = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true"
	}
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	client, err := mongo.Connect(options.Client().ApplyURI(uri))
	if err != nil {
		t.Skipf("mongo.Connect: %v", err)
	}
	if err := client.Ping(ctx, nil); err != nil {
		t.Skipf("mongo.Ping: %v", err)
	}
	// Mongo caps database names at 63 bytes; truncate the test-name suffix.
	suffix := t.Name()
	if len(suffix) > 24 {
		suffix = suffix[:24]
	}
	db := client.Database("authtest_" + suffix)
	t.Cleanup(func() {
		_ = db.Drop(context.Background())
		_ = client.Disconnect(context.Background())
	})
	return db
}

func TestRefreshStore_IssueAndValidate(t *testing.T) {
	db := newTestMongo(t)
	store := NewRefreshStore(db)
	ctx := context.Background()

	id, err := store.Issue(ctx, "user-1", "fam-1")
	if err != nil {
		t.Fatalf("Issue: %v", err)
	}
	rec, err := store.Validate(ctx, id)
	if err != nil {
		t.Fatalf("Validate: %v", err)
	}
	if rec.UserID != "user-1" || rec.FamilyID != "fam-1" {
		t.Errorf("rec=%+v, want user-1/fam-1", rec)
	}
}

func TestRefreshStore_Rotate_InvalidatesOld(t *testing.T) {
	db := newTestMongo(t)
	store := NewRefreshStore(db)
	ctx := context.Background()

	oldID, _ := store.Issue(ctx, "u", "fam")
	newID, err := store.Rotate(ctx, oldID)
	if err != nil {
		t.Fatalf("Rotate: %v", err)
	}
	if _, err := store.Validate(ctx, oldID); err == nil {
		t.Errorf("old id still valid after rotate")
	}
	rec, err := store.Validate(ctx, newID)
	if err != nil {
		t.Fatalf("Validate new: %v", err)
	}
	if rec.FamilyID != "fam" {
		t.Errorf("new rec family=%q, want fam (rotation preserves family)", rec.FamilyID)
	}
}

func TestRefreshStore_RevokeFamily_RevokesAllInFamily(t *testing.T) {
	db := newTestMongo(t)
	store := NewRefreshStore(db)
	ctx := context.Background()

	a, _ := store.Issue(ctx, "u", "famA")
	b, _ := store.Issue(ctx, "u", "famB")
	if err := store.RevokeFamily(ctx, "famA"); err != nil {
		t.Fatalf("RevokeFamily: %v", err)
	}
	if _, err := store.Validate(ctx, a); err == nil {
		t.Errorf("famA token still valid")
	}
	if _, err := store.Validate(ctx, b); err != nil {
		t.Errorf("famB token incorrectly revoked: %v", err)
	}
}

func TestRefreshStore_Rotate_DetectsReplay(t *testing.T) {
	db := newTestMongo(t)
	store := NewRefreshStore(db)
	ctx := context.Background()

	id, _ := store.Issue(ctx, "u", "fam")
	if _, err := store.Rotate(ctx, id); err != nil {
		t.Fatalf("first rotate: %v", err)
	}
	// Replaying the rotated ID must revoke the family entirely.
	if _, err := store.Rotate(ctx, id); err == nil {
		t.Errorf("replay rotate succeeded; expected reuse detection")
	}
	// After a reuse, the whole family is dead — issuing a fresh token
	// in the same family must refuse (and Validate of the never-issued
	// id must fail).
	id2, _ := store.Issue(ctx, "u", "fam")
	if _, err := store.Validate(ctx, id2); err == nil {
		t.Errorf("post-reuse issuance in same family still valid")
	}
}

func TestRefreshStore_RevokeAllForUser(t *testing.T) {
	db := newTestMongo(t)
	store := NewRefreshStore(db)
	ctx := context.Background()

	a, _ := store.Issue(ctx, "alice", "famA")
	b, _ := store.Issue(ctx, "alice", "famB")
	c, _ := store.Issue(ctx, "bob", "famC")
	if err := store.RevokeAllForUser(ctx, "alice"); err != nil {
		t.Fatalf("RevokeAllForUser: %v", err)
	}
	if _, err := store.Validate(ctx, a); err == nil {
		t.Errorf("alice famA still valid")
	}
	if _, err := store.Validate(ctx, b); err == nil {
		t.Errorf("alice famB still valid")
	}
	if _, err := store.Validate(ctx, c); err != nil {
		t.Errorf("bob's token incorrectly revoked: %v", err)
	}
}
