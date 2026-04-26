package main

import (
	"context"
	"errors"
	"sort"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/models"
	"quiz-battle/pkg/notif"
	pb "quiz-battle/proto"
)

// defaultNotifTimezone is the fallback when a user has no timezone set
// (no onboarding step has captured it yet). Asia/Kolkata matches the
// product's primary market — see problem-03's SpeakX framing.
const defaultNotifTimezone = "Asia/Kolkata"

// GetNotificationPrefs returns the caller's stored prefs or product
// defaults if nothing is stored yet. A user who has never opened the
// settings screen still gets a sensible response rather than a 404.
func (s *scoringServer) GetNotificationPrefs(ctx context.Context, _ *pb.GetNotificationPrefsRequest) (*pb.GetNotificationPrefsResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	var doc struct {
		Prefs *models.NotificationPrefs `bson:"notificationPrefs"`
	}
	if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": uid}).Decode(&doc); err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		return nil, status.Errorf(codes.Internal, "load user: %v", err)
	}

	resp := &pb.GetNotificationPrefsResponse{
		Timezone: defaultNotifTimezone,
	}
	if doc.Prefs != nil {
		// Sort for deterministic responses — clients diff this list to
		// detect changes and a stable order avoids spurious diffs.
		mt := append([]string(nil), doc.Prefs.MutedTypes...)
		sort.Strings(mt)
		resp.MutedTypes = mt
		if doc.Prefs.Timezone != "" {
			resp.Timezone = doc.Prefs.Timezone
		}
	}
	return resp, nil
}

// UpdateNotificationPrefs replaces the entire muted_types list (set
// semantics) and optionally the timezone. Unknown categories are
// rejected with InvalidArgument; an unparseable timezone is rejected
// the same way. Empty muted_types clears all mutes.
func (s *scoringServer) UpdateNotificationPrefs(ctx context.Context, req *pb.UpdateNotificationPrefsRequest) (*pb.UpdateNotificationPrefsResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	// Dedup + validate. The dedup is a defensive measure — a client
	// that sends the same category twice would otherwise persist a
	// list with duplicates that's harder to reason about.
	seen := map[string]struct{}{}
	cleaned := make([]string, 0, len(req.MutedTypes))
	for _, c := range req.MutedTypes {
		if !notif.IsKnown(c) {
			return nil, status.Errorf(codes.InvalidArgument, "unknown notification category: %q", c)
		}
		if _, dup := seen[c]; dup {
			continue
		}
		seen[c] = struct{}{}
		cleaned = append(cleaned, c)
	}
	sort.Strings(cleaned)

	set := bson.M{"notificationPrefs.mutedTypes": cleaned}
	if req.Timezone != "" {
		// Validate against the embedded tzdata before writing — a bad
		// IANA name persisted here would silently fall back to UTC at
		// every policy check.
		if _, err := time.LoadLocation(req.Timezone); err != nil {
			return nil, status.Errorf(codes.InvalidArgument, "invalid timezone %q: %v", req.Timezone, err)
		}
		set["notificationPrefs.timezone"] = req.Timezone
	}

	res, err := s.mongoDB.Collection("users").UpdateOne(ctx,
		bson.M{"_id": uid},
		bson.M{"$set": set},
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update prefs: %v", err)
	}
	if res.MatchedCount == 0 {
		return nil, status.Error(codes.NotFound, "user not found")
	}
	return &pb.UpdateNotificationPrefsResponse{Success: true}, nil
}

// MarkNotificationOpened increments the global per-day open counter
// for the category. Sent counters live in services/notification's
// policy gate; pairing the two on the same day lets us compute open
// rate offline (opened / sent).
//
// Per-user open events aren't recorded. Aggregate metrics are enough
// for the §4.6 requirement and avoid building a privacy review for
// per-user notification timing data. To keep the global counter
// honest, the increment is gated by a per-(user, category, day) SETNX
// dedup with a 24h TTL — a misbehaving client can't bump the counter
// in a loop, and idempotent retries (FCM tap firing twice) are no-ops.
//
// Day bucket is UTC to match the global SENT counter in
// services/notification/policy.go: open rate = opened/sent only makes
// sense when both sides agree on what "today" means.
func (s *scoringServer) MarkNotificationOpened(ctx context.Context, req *pb.MarkNotificationOpenedRequest) (*pb.MarkNotificationOpenedResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if !notif.IsKnown(req.Category) {
		return nil, status.Errorf(codes.InvalidArgument, "unknown notification category: %q", req.Category)
	}
	day := time.Now().UTC().Format("2006-01-02")
	first, dedupErr := keys.TrySetNotifOpenedDedup(ctx, s.rdb, uid, req.Category, day)
	if dedupErr != nil {
		// Fail-open posture matches the policy gate: a degraded Redis
		// shouldn't make taps fail. The increment will still run; in
		// the worst case the counter double-counts for one user/day
		// while Redis is down.
		first = true
	}
	if !first {
		// Already counted today. Return success so the client doesn't
		// surface a "tap didn't register" error.
		return &pb.MarkNotificationOpenedResponse{Success: true}, nil
	}
	if err := keys.IncrNotifMetricOpened(ctx, s.rdb, req.Category, day); err != nil {
		return nil, status.Errorf(codes.Internal, "increment open counter: %v", err)
	}
	return &pb.MarkNotificationOpenedResponse{Success: true}, nil
}
