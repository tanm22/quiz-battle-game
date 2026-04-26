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
	pb "quiz-battle/proto"
)

// notifCategories enumerates every category the §4.6 policy gate
// recognises. Kept in one place so UpdateNotificationPrefs validation,
// the policy gate's category-from-event lookup, and the Flutter settings
// screen all reference the same canonical list.
//
// Adding a new category: extend this slice AND add the routing-key →
// category mapping in services/notification/policy.go.
var notifCategories = map[string]struct{}{
	"friend_request":   {},
	"friend_challenge": {},
	"match_invite":     {},
	"streak":           {},
	"daily_reward":     {},
	"referral":         {},
	"tournament":       {},
	"premium":          {},
}

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
		if _, known := notifCategories[c]; !known {
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
// per-user notification timing data.
func (s *scoringServer) MarkNotificationOpened(ctx context.Context, req *pb.MarkNotificationOpenedRequest) (*pb.MarkNotificationOpenedResponse, error) {
	if _, err := auth.UserIDFromContext(ctx); err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if _, ok := notifCategories[req.Category]; !ok {
		return nil, status.Errorf(codes.InvalidArgument, "unknown notification category: %q", req.Category)
	}
	day := time.Now().UTC().Format("2006-01-02")
	if err := keys.IncrNotifMetricOpened(ctx, s.rdb, req.Category, day); err != nil {
		return nil, status.Errorf(codes.Internal, "increment open counter: %v", err)
	}
	return &pb.MarkNotificationOpenedResponse{Success: true}, nil
}
