package main

import (
	"context"
	"errors"

	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/coins/shop"
	"quiz-battle/pkg/validate"
	pb "quiz-battle/proto"
)

// EquipCosmetic activates an owned avatar frame or name color. The
// `_id + ownedCosmetics` filter on UpdateOne is the authorisation guard:
// it succeeds only when the user actually owns the item, surfacing
// NOT_OWNED otherwise. Re-equipping the already-equipped item is a
// no-op success because the predicate still matches.
//
// Authentication errors come back as gRPC status codes; domain errors
// (UNKNOWN / NOT_OWNED / NOT_EQUIPPABLE) come back as a successful
// response with ErrorCode set, mirroring the hybrid model that
// PurchaseShopItem already uses.
func (s *scoringServer) EquipCosmetic(ctx context.Context, req *pb.EquipCosmeticRequest) (*pb.EquipCosmeticResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if req.ItemId == "" {
		return nil, status.Error(codes.InvalidArgument, "itemId required")
	}
	if err := validate.MaxLen(req.ItemId, 64); err != nil {
		return nil, status.Errorf(codes.InvalidArgument, "item_id: %v", err)
	}

	item, err := shop.GetItem(ctx, s.mongoDB, req.ItemId)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return &pb.EquipCosmeticResponse{ErrorCode: "UNKNOWN"}, nil
		}
		return nil, status.Errorf(codes.Internal, "load item: %v", err)
	}

	// Only cosmetic kinds are equippable. Streak-freeze / reroll / premium
	// trial use their own activation paths; surfacing NOT_EQUIPPABLE here
	// stops the client from trying to "equip" a streak freeze.
	var field string
	switch item.Kind {
	case shop.KindAvatarFrame:
		field = "equippedCosmeticId"
	case shop.KindNameColor:
		field = "equippedNameColor"
	default:
		return &pb.EquipCosmeticResponse{ErrorCode: "NOT_EQUIPPABLE"}, nil
	}

	res, err := s.mongoDB.Collection("users").UpdateOne(ctx,
		bson.M{"_id": uid, "ownedCosmetics": req.ItemId},
		bson.M{"$set": bson.M{field: req.ItemId}},
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "equip: %v", err)
	}
	if res.MatchedCount == 0 {
		return &pb.EquipCosmeticResponse{ErrorCode: "NOT_OWNED"}, nil
	}
	return &pb.EquipCosmeticResponse{Success: true}, nil
}

// ConsumeReroll atomically decrements rerollCharges by 1 and returns the
// post-update count. FindOneAndUpdate with ReturnDocument: After in a
// single round-trip avoids the read-after-write race that the older
// "UpdateOne; FindOne" pattern had.
//
// The `rerollCharges > 0` filter is the spend guard: a user with zero
// charges sees ModifiedCount == 0, which surfaces as
// mongo.ErrNoDocuments and maps to the NO_CHARGES domain error code.
// The user document is otherwise untouched.
//
// roomId / roundId are optional today — accepted for forward-compat
// with a per-match audit trail in a future PR, but the server doesn't
// require them, so callers can leave them empty until that lands. We
// don't validate non-empty: enforcing a contract the server doesn't
// actually use makes the proto fields meaningless beyond their comment.
func (s *scoringServer) ConsumeReroll(ctx context.Context, _ *pb.ConsumeRerollRequest) (*pb.ConsumeRerollResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	var u struct {
		RerollCharges int32 `bson:"rerollCharges"`
	}
	err = s.mongoDB.Collection("users").FindOneAndUpdate(ctx,
		bson.M{"_id": uid, "rerollCharges": bson.M{"$gt": 0}},
		bson.M{"$inc": bson.M{"rerollCharges": -1}},
		options.FindOneAndUpdate().SetReturnDocument(options.After).
			SetProjection(bson.M{"rerollCharges": 1}),
	).Decode(&u)
	if err != nil {
		if !errors.Is(err, mongo.ErrNoDocuments) {
			return nil, status.Errorf(codes.Internal, "consume reroll: %v", err)
		}
		// FindOneAndUpdate with no match has two meanings: (a) the user
		// doc doesn't exist, (b) the user exists but rerollCharges <= 0.
		// They look identical from this single op, but the client should
		// see different copy: "you've used all your re-rolls" vs "your
		// account is gone". A short follow-up FindOne distinguishes
		// them. The race window between the FindOneAndUpdate miss and
		// this read is non-issue: a user that gets created in between
		// has no charges either way (NO_CHARGES is correct), and a
		// user that gets deleted in between is already in the NotFound
		// arm (also correct).
		var probe struct{}
		probeErr := s.mongoDB.Collection("users").
			FindOne(ctx, bson.M{"_id": uid}, options.FindOne().SetProjection(bson.M{"_id": 1})).
			Decode(&probe)
		if errors.Is(probeErr, mongo.ErrNoDocuments) {
			return nil, status.Error(codes.NotFound, "user not found")
		}
		// Probe also caught a real error; surface NO_CHARGES rather
		// than masking the FindOneAndUpdate result with a probe error.
		return &pb.ConsumeRerollResponse{ErrorCode: "NO_CHARGES"}, nil
	}
	return &pb.ConsumeRerollResponse{Success: true, ChargesRemaining: u.RerollCharges}, nil
}
