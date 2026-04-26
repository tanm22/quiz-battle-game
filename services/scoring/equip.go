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
// roomId / roundId are accepted in the request for forward-compat with
// a future "log reroll consumption per match" audit trail, but this PR
// doesn't persist them — the per-match audit is out of §4.3 scope.
func (s *scoringServer) ConsumeReroll(ctx context.Context, req *pb.ConsumeRerollRequest) (*pb.ConsumeRerollResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if req.RoomId == "" || req.RoundId == "" {
		return nil, status.Error(codes.InvalidArgument, "roomId and roundId required")
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
		if errors.Is(err, mongo.ErrNoDocuments) {
			// Either the user has no rerollCharges field at all, or the
			// existing count is 0. Either way, no charge consumed —
			// surface NO_CHARGES so the client renders the right copy.
			return &pb.ConsumeRerollResponse{ErrorCode: "NO_CHARGES"}, nil
		}
		return nil, status.Errorf(codes.Internal, "consume reroll: %v", err)
	}
	return &pb.ConsumeRerollResponse{Success: true, ChargesRemaining: u.RerollCharges}, nil
}
