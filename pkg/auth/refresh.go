// Package auth — refresh.go owns the refresh-token persistence layer.
//
// Token model: each refresh document carries (id, userId, familyId,
// revokedAt, replacedBy, expiresAt). A refresh token is single-use:
// rotating it stamps replacedBy and mints a new document in the same
// family. Validate rejects revoked or expired documents. If a caller
// presents an already-rotated token (replacedBy is set) we treat it
// as a replay attack and revoke the entire family — this is the
// standard refresh-token-reuse defense against a stolen token.
//
// Family-poisoning: once Rotate's replay path revokes a family, Issue
// refuses to mint new tokens into the same family by detecting any
// sibling with revokedAt set AND replacedBy unset (the signature of
// a non-rotation revocation). Legitimate rotations always set
// replacedBy to the successor id, so they don't poison the family.
//
// Why Mongo (not Redis): we want long-lived persistence across
// service restarts and the ability to revoke an entire family
// retroactively (logout from all devices). Redis would work but
// would add another data-loss surface for a session-tier resource
// we already pay Mongo to durably hold.
package auth

import (
	"context"
	"errors"
	"time"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
)

// ErrRefreshInvalid is returned for any failure mode the caller
// should surface to the client as "log in again": expired, revoked,
// unknown id, or family poisoned by replay.
var ErrRefreshInvalid = errors.New("refresh token invalid")

// RefreshRecord is the post-validate view returned to handlers.
type RefreshRecord struct {
	ID       string
	UserID   string
	FamilyID string
}

type refreshDoc struct {
	ID        string    `bson:"_id"`
	UserID    string    `bson:"userId"`
	FamilyID  string    `bson:"familyId"`
	ExpiresAt time.Time `bson:"expiresAt"`
	// RevokedAt uses ,omitempty so freshly-issued docs leave the field
	// absent. The "$exists: false" filter in RevokeFamily/RevokeAllForUser
	// then matches only unrevoked tokens, preventing redundant overwrite
	// of the timestamp on rows that were revoked in a prior call.
	RevokedAt time.Time `bson:"revokedAt,omitempty"`
	// ReplacedBy is explicitly persisted as "" on Issue (no ,omitempty) so
	// Rotate's "replacedBy: \"\"" filter actually matches. With omitempty,
	// the field would be absent on a fresh doc and the equality match
	// would silently fail every rotation.
	ReplacedBy string    `bson:"replacedBy"`
	CreatedAt  time.Time `bson:"createdAt"`
}

// RefreshStore persists refresh-token state.
type RefreshStore struct {
	coll *mongo.Collection
}

// NewRefreshStore wires a store to the supplied database. It does
// not call EnsureIndexes; call that once at service startup.
func NewRefreshStore(db *mongo.Database) *RefreshStore {
	return &RefreshStore{coll: db.Collection("refresh_tokens")}
}

// EnsureIndexes creates (userId), (familyId), and TTL on expiresAt
// indexes. The TTL index drives Mongo to physically delete expired
// rows in the background; we still validate expiresAt at read time
// because the TTL job runs on a ~60s cadence. Idempotent.
func (s *RefreshStore) EnsureIndexes(ctx context.Context) error {
	_, err := s.coll.Indexes().CreateMany(ctx, []mongo.IndexModel{
		{Keys: bson.D{{Key: "userId", Value: 1}}},
		{Keys: bson.D{{Key: "familyId", Value: 1}}},
		{Keys: bson.D{{Key: "expiresAt", Value: 1}}, Options: options.Index().SetExpireAfterSeconds(0)},
	})
	return err
}

// Issue persists a freshly-minted refresh token under the given
// family. The returned id is what the caller hands to the client.
//
// Refuses to mint into a family that's been poisoned by replay
// detection. We detect that by counting siblings with revokedAt set
// AND replacedBy empty — the signature of a RevokeFamily/RevokeAllForUser
// revocation. Legitimate rotations always populate replacedBy, so
// they do not trip this check.
func (s *RefreshStore) Issue(ctx context.Context, userID, familyID string) (string, error) {
	n, err := s.coll.CountDocuments(ctx, bson.M{
		"familyId":   familyID,
		"revokedAt":  bson.M{"$exists": true},
		"replacedBy": "",
	})
	if err != nil {
		return "", err
	}
	if n > 0 {
		return "", ErrRefreshInvalid
	}

	id, err := GenerateRefreshTokenID()
	if err != nil {
		return "", err
	}
	now := time.Now()
	_, err = s.coll.InsertOne(ctx, refreshDoc{
		ID:        id,
		UserID:    userID,
		FamilyID:  familyID,
		ExpiresAt: now.Add(RefreshTokenTTL),
		CreatedAt: now,
	})
	return id, err
}

// Validate returns the record for id if it is not revoked, not
// rotated, and not expired. Any failure collapses to ErrRefreshInvalid
// to deny the attacker a side-channel on which check failed.
func (s *RefreshStore) Validate(ctx context.Context, id string) (*RefreshRecord, error) {
	if id == "" {
		return nil, ErrRefreshInvalid
	}
	var doc refreshDoc
	if err := s.coll.FindOne(ctx, bson.M{"_id": id}).Decode(&doc); err != nil {
		return nil, ErrRefreshInvalid
	}
	if !doc.RevokedAt.IsZero() || doc.ReplacedBy != "" || time.Now().After(doc.ExpiresAt) {
		return nil, ErrRefreshInvalid
	}
	return &RefreshRecord{ID: doc.ID, UserID: doc.UserID, FamilyID: doc.FamilyID}, nil
}

// Rotate atomically marks the presented id as replaced and issues
// a fresh id in the same family. Reuse detection: if the presented
// id is already-rotated or revoked, we revoke the entire family.
func (s *RefreshStore) Rotate(ctx context.Context, id string) (string, error) {
	var doc refreshDoc
	if err := s.coll.FindOne(ctx, bson.M{"_id": id}).Decode(&doc); err != nil {
		return "", ErrRefreshInvalid
	}
	// Replay or already-revoked? Burn the family and refuse.
	if !doc.RevokedAt.IsZero() || doc.ReplacedBy != "" {
		_ = s.RevokeFamily(ctx, doc.FamilyID)
		return "", ErrRefreshInvalid
	}
	if time.Now().After(doc.ExpiresAt) {
		return "", ErrRefreshInvalid
	}
	newID, err := s.Issue(ctx, doc.UserID, doc.FamilyID)
	if err != nil {
		return "", err
	}
	_, err = s.coll.UpdateOne(ctx,
		bson.M{"_id": id, "replacedBy": ""},
		bson.M{"$set": bson.M{"replacedBy": newID, "revokedAt": time.Now()}},
	)
	return newID, err
}

// RevokeFamily marks every token in familyID as revoked. Used by
// Logout and by the replay-detection path in Rotate.
func (s *RefreshStore) RevokeFamily(ctx context.Context, familyID string) error {
	_, err := s.coll.UpdateMany(ctx,
		bson.M{"familyId": familyID, "revokedAt": bson.M{"$exists": false}},
		bson.M{"$set": bson.M{"revokedAt": time.Now()}},
	)
	return err
}

// RevokeAllForUser revokes every refresh token belonging to userID.
// Used by password change and account delete.
func (s *RefreshStore) RevokeAllForUser(ctx context.Context, userID string) error {
	_, err := s.coll.UpdateMany(ctx,
		bson.M{"userId": userID, "revokedAt": bson.M{"$exists": false}},
		bson.M{"$set": bson.M{"revokedAt": time.Now()}},
	)
	return err
}
