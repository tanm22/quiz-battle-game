package main

import (
	"context"
	"fmt"
	"os"
	"sort"
	"strings"
	"testing"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// newTopicsTestServer wires a minimal quizServer backed by a real Mongo
// database scoped to this single test. rdb stays nil — computeAllowedTopics
// guards on that and falls back to Mongo for plan lookup, which is exactly
// the path we want to exercise here.
//
// Skips the test (instead of failing) when Mongo isn't reachable so
// unit-only runs (CI without docker compose) stay green. Use
// MONGO_URI=mongodb://localhost:27017/?replicaSet=rs0&directConnection=true
// when running locally.
func newTopicsTestServer(t *testing.T) *quizServer {
	t.Helper()

	uri := os.Getenv("MONGO_URI")
	if uri == "" {
		uri = "mongodb://localhost:27017/?replicaSet=rs0&directConnection=true"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	client, err := mongo.Connect(options.Client().ApplyURI(uri))
	if err != nil {
		t.Skipf("mongo.Connect: %v (is docker compose up?)", err)
	}
	if err := client.Ping(ctx, nil); err != nil {
		t.Skipf("mongo.Ping: %v (is docker compose up?)", err)
	}

	suffix := strings.ReplaceAll(t.Name(), "/", "_")
	if len(suffix) > 24 {
		suffix = suffix[:24]
	}
	dbName := fmt.Sprintf("quiztest_%d_%s", time.Now().UnixNano(), suffix)
	db := client.Database(dbName)

	t.Cleanup(func() {
		_ = db.Drop(context.Background())
		_ = client.Disconnect(context.Background())
	})

	return &quizServer{mongoDB: db}
}

// seedUser inserts a single user document with the given plan + preferences.
// `prefs == nil` skips the preferredTopics field entirely so we can model
// pre-onboarding users.
func seedUser(t *testing.T, srv *quizServer, id, plan string, prefs []string) {
	t.Helper()
	doc := bson.M{"_id": id, "plan": plan}
	if prefs != nil {
		doc["preferredTopics"] = prefs
	}
	_, err := srv.mongoDB.Collection("users").InsertOne(context.Background(), doc)
	if err != nil {
		t.Fatalf("seed %s: %v", id, err)
	}
}

// assertTopicsEqual compares two topic slices ignoring order.
func assertTopicsEqual(t *testing.T, got, want []string) {
	t.Helper()
	g := append([]string(nil), got...)
	w := append([]string(nil), want...)
	sort.Strings(g)
	sort.Strings(w)
	if len(g) != len(w) {
		t.Errorf("topics = %v, want %v", got, want)
		return
	}
	for i := range g {
		if g[i] != w[i] {
			t.Errorf("topics = %v, want %v", got, want)
			return
		}
	}
}

//  1. Both free, both have prefs entirely within the free tier.
//     Expect the union, no fallback.
func TestComputeAllowedTopics_BothFree_PrefsWithinFreeTier(t *testing.T) {
	srv := newTopicsTestServer(t)
	seedUser(t, srv, "alice", "free", []string{"science", "history"})
	seedUser(t, srv, "bob", "free", []string{"history", "geography"})

	got, err := srv.computeAllowedTopics(context.Background(), []string{"alice", "bob"})
	if err != nil {
		t.Fatalf("computeAllowedTopics: %v", err)
	}
	assertTopicsEqual(t, got, []string{"science", "history", "geography"})
}

//  2. Both free, prefs span free + non-free topics.
//     Expect only the free-tier-allowed subset.
func TestComputeAllowedTopics_BothFree_PrefsSpanFreeAndPremium(t *testing.T) {
	srv := newTopicsTestServer(t)
	seedUser(t, srv, "alice", "free", []string{"sports", "science"})
	seedUser(t, srv, "bob", "free", []string{"movies", "history"})

	got, err := srv.computeAllowedTopics(context.Background(), []string{"alice", "bob"})
	if err != nil {
		t.Fatalf("computeAllowedTopics: %v", err)
	}
	assertTopicsEqual(t, got, []string{"science", "history"})
}

//  3. Both free, neither has any preferences set (old / un-onboarded users).
//     Expect fallback to freeTopics.
func TestComputeAllowedTopics_BothFree_NoPrefs(t *testing.T) {
	srv := newTopicsTestServer(t)
	seedUser(t, srv, "alice", "free", nil)
	seedUser(t, srv, "bob", "free", nil)

	got, err := srv.computeAllowedTopics(context.Background(), []string{"alice", "bob"})
	if err != nil {
		t.Fatalf("computeAllowedTopics: %v", err)
	}
	assertTopicsEqual(t, got, freeTopics)
}

//  4. Both free, but every preferred topic is outside the free tier.
//     Intersection is empty → expect fallback to freeTopics.
func TestComputeAllowedTopics_BothFree_PrefsAllOutsideFreeTier(t *testing.T) {
	srv := newTopicsTestServer(t)
	seedUser(t, srv, "alice", "free", []string{"sports", "movies"})
	seedUser(t, srv, "bob", "free", []string{"gaming"})

	got, err := srv.computeAllowedTopics(context.Background(), []string{"alice", "bob"})
	if err != nil {
		t.Fatalf("computeAllowedTopics: %v", err)
	}
	assertTopicsEqual(t, got, freeTopics)
}

//  5. Both premium, both have preferences.
//     Expect the union with no plan filtering.
func TestComputeAllowedTopics_BothPremium_WithPrefs(t *testing.T) {
	srv := newTopicsTestServer(t)
	seedUser(t, srv, "alice", "premium", []string{"movies"})
	seedUser(t, srv, "bob", "premium", []string{"gaming"})

	got, err := srv.computeAllowedTopics(context.Background(), []string{"alice", "bob"})
	if err != nil {
		t.Fatalf("computeAllowedTopics: %v", err)
	}
	assertTopicsEqual(t, got, []string{"movies", "gaming"})
}

//  6. Both premium, no preferences set.
//     Ceiling is nil; union is empty → fallback is nil (all topics).
func TestComputeAllowedTopics_BothPremium_NoPrefs(t *testing.T) {
	srv := newTopicsTestServer(t)
	seedUser(t, srv, "alice", "premium", nil)
	seedUser(t, srv, "bob", "premium", nil)

	got, err := srv.computeAllowedTopics(context.Background(), []string{"alice", "bob"})
	if err != nil {
		t.Fatalf("computeAllowedTopics: %v", err)
	}
	if got != nil {
		t.Errorf("topics = %v, want nil (all topics)", got)
	}
}

//  7. Mixed free + premium → the free-tier ceiling applies.
//     The free player has prefs spanning free + non-free; the premium player
//     has a non-free pref. Only the free-tier subset of the union survives.
func TestComputeAllowedTopics_MixedFreeAndPremium(t *testing.T) {
	srv := newTopicsTestServer(t)
	seedUser(t, srv, "alice", "free", []string{"science", "sports"})
	seedUser(t, srv, "bob", "premium", []string{"movies", "geography"})

	got, err := srv.computeAllowedTopics(context.Background(), []string{"alice", "bob"})
	if err != nil {
		t.Fatalf("computeAllowedTopics: %v", err)
	}
	assertTopicsEqual(t, got, []string{"science", "geography"})
}
