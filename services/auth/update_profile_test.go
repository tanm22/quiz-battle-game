package main

import (
	"context"
	"testing"

	"go.mongodb.org/mongo-driver/v2/bson"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	pb "quiz-battle/proto"
)

func TestUpdateProfile_RequiresAuth(t *testing.T) {
	srv := newTestAuthServer(t)
	_, err := srv.UpdateProfile(context.Background(), &pb.UpdateProfileRequest{
		DisplayName: "Alice",
	})
	if status.Code(err) != codes.Unauthenticated {
		t.Fatalf("expected Unauthenticated, got %v", err)
	}
}

func TestUpdateProfile_PersistsFields(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "alice")

	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: "alice"})
	resp, err := srv.UpdateProfile(ctx, &pb.UpdateProfileRequest{
		DisplayName:         "Alice W.",
		AvatarUrl:           "https://example.com/a.png",
		PreferredTopics:     []string{"science", "history"},
		OnboardingCompleted: true,
	})
	if err != nil {
		t.Fatalf("UpdateProfile: %v", err)
	}
	if !resp.Success {
		t.Fatal("expected Success=true")
	}

	var doc bson.M
	if err := srv.users().FindOne(ctx, bson.M{"_id": uid}).Decode(&doc); err != nil {
		t.Fatalf("find user: %v", err)
	}
	if doc["displayName"] != "Alice W." {
		t.Errorf("displayName: got %v", doc["displayName"])
	}
	if doc["avatarUrl"] != "https://example.com/a.png" {
		t.Errorf("avatarUrl: got %v", doc["avatarUrl"])
	}
	if doc["onboardingCompleted"] != true {
		t.Errorf("onboardingCompleted: got %v", doc["onboardingCompleted"])
	}
	topics, _ := doc["preferredTopics"].(bson.A)
	if len(topics) != 2 || topics[0] != "science" || topics[1] != "history" {
		t.Errorf("preferredTopics: got %v", topics)
	}
}

func TestUpdateProfile_RejectsInvalidTopicValue(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "alice_invalid_topic")
	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: "alice_invalid_topic"})
	_, err := srv.UpdateProfile(ctx, &pb.UpdateProfileRequest{
		PreferredTopics: []string{"history", "", "science"}, // empty in the middle
	})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("err=%v, want InvalidArgument", err)
	}
}

func TestUpdateProfile_RejectsTooLongTopic(t *testing.T) {
	srv := newTestAuthServer(t)
	uid := createTestUser(t, srv, "alice_long_topic")
	ctx := auth.ContextWithClaims(context.Background(), &auth.Claims{UserID: uid, Username: "alice_long_topic"})
	long := make([]byte, 65)
	for i := range long {
		long[i] = 'x'
	}
	_, err := srv.UpdateProfile(ctx, &pb.UpdateProfileRequest{
		PreferredTopics: []string{"history", string(long)},
	})
	if status.Code(err) != codes.InvalidArgument {
		t.Errorf("err=%v, want InvalidArgument", err)
	}
}
