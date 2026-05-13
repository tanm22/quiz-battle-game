package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/log"
	"quiz-battle/pkg/models"
	"quiz-battle/pkg/validate"
	pb "quiz-battle/proto"
)

// friendRequestsCollection is the canonical Mongo collection name. Hoisted
// to a const so tests and seed don't drift on the literal.
const friendRequestsCollection = "friend_requests"

// friendAcceptedEvent is the payload for notif.friend.request_accepted —
// fired when a pending request flips to accepted (either via the
// auto-accept-reverse path in SendFriendRequest or the explicit accept in
// RespondToFriendRequest). The recipient is the user whose original
// outbound request just got accepted.
type friendAcceptedEvent struct {
	RecipientUserID  string
	AccepterUserID   string
	AccepterUsername string
	RequestID        string
}

// publishFriendRequestAccepted is the single fan-out point for the
// "your friend request was accepted" push. Best-effort: a publish failure
// is logged but doesn't fail the caller — the friendship is already
// committed in Mongo and the recipient will see it on next GetFriendsList.
func (s *scoringServer) publishFriendRequestAccepted(ctx context.Context, ev friendAcceptedEvent) {
	body, _ := json.Marshal(map[string]any{
		"event":            "notif.friend.request_accepted",
		"userId":           ev.RecipientUserID,
		"accepterUserId":   ev.AccepterUserID,
		"accepterUsername": ev.AccepterUsername,
		"requestId":        ev.RequestID,
	})
	if err := s.publish(ctx, "notif.friend.request_accepted", body); err != nil {
		log.FromContext(ctx).Warn("publish notif.friend.request_accepted failed",
			"component", "friends", "recipient_id", ev.RecipientUserID, "err", err)
	}
}

// SendFriendRequest creates a pending friend_requests row for the caller →
// target. Idempotent on (fromUserId, toUserId) via the unique index in
// seed/main.go: a duplicate send returns the existing pending request or,
// once accepted, an ALREADY_FRIENDS error code without writing.
//
// The target is resolved from EXACTLY ONE of target_username or
// target_referral_code. Username takes precedence when both are set
// (defensive — clients should send one).
func (s *scoringServer) SendFriendRequest(ctx context.Context, req *pb.SendFriendRequestRequest) (*pb.SendFriendRequestResponse, error) {
	fromID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if (req.TargetUsername == "" && req.TargetReferralCode == "") ||
		(req.TargetUsername != "" && req.TargetReferralCode != "") {
		return &pb.SendFriendRequestResponse{ErrorCode: "INVALID_ARGUMENT"}, nil
	}
	// §4.7 PR-B2: validate the user-supplied identifier matches the
	// expected shape before hitting Mongo. Rejects "alice@bob",
	// "../../etc/passwd", SQLi-style inputs at the parse step.
	if req.TargetUsername != "" {
		if err := validate.Username(req.TargetUsername); err != nil {
			return &pb.SendFriendRequestResponse{ErrorCode: "INVALID_ARGUMENT"}, nil
		}
	}
	if req.TargetReferralCode != "" {
		// Referral codes are short alphanumeric tokens (~6 chars, generated
		// in scoring/main.go's referral path). Bound the length to dodge
		// pathological inputs that would still index-scan.
		if err := validate.MaxLen(req.TargetReferralCode, 32); err != nil {
			return &pb.SendFriendRequestResponse{ErrorCode: "INVALID_ARGUMENT"}, nil
		}
	}

	// Look up the target user. The two paths are mutually exclusive so
	// there's never an ambiguous resolution.
	var target struct {
		ID       string `bson:"_id"`
		Username string `bson:"username"`
	}
	var lookupFilter bson.M
	if req.TargetUsername != "" {
		lookupFilter = bson.M{"username": req.TargetUsername}
	} else {
		lookupFilter = bson.M{"referralCode": req.TargetReferralCode}
	}
	if err := s.mongoDB.Collection("users").FindOne(ctx, lookupFilter).Decode(&target); err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return &pb.SendFriendRequestResponse{ErrorCode: "USER_NOT_FOUND"}, nil
		}
		return nil, status.Errorf(codes.Internal, "lookup target: %v", err)
	}
	if target.ID == fromID {
		return &pb.SendFriendRequestResponse{ErrorCode: "SELF"}, nil
	}

	// Resolve the caller's username for the row — saves the recipient
	// from a separate users-lookup when listing incoming requests.
	var caller struct {
		Username string `bson:"username"`
	}
	if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": fromID}).Decode(&caller); err != nil {
		return nil, status.Errorf(codes.Internal, "load caller: %v", err)
	}

	// Symmetric "already friends" check: if the REVERSE direction
	// (target → caller) exists in any state, treat it as the canonical
	// row. Avoids the corner case where Alice sends a request to Bob
	// while Bob's request to Alice is sitting pending — the system
	// shouldn't create a second request for the same pair.
	var reverse models.FriendRequest
	reverseErr := s.mongoDB.Collection(friendRequestsCollection).FindOne(ctx,
		bson.M{"fromUserId": target.ID, "toUserId": fromID}).Decode(&reverse)
	if reverseErr == nil {
		switch reverse.Status {
		case "accepted":
			return &pb.SendFriendRequestResponse{ErrorCode: "ALREADY_FRIENDS", RequestId: reverse.ID}, nil
		case "pending":
			// Auto-accept: if Bob already invited Alice, Alice "sending"
			// to Bob means she's accepting the existing request.
			now := time.Now().UTC()
			if _, err := s.mongoDB.Collection(friendRequestsCollection).UpdateOne(ctx,
				bson.M{"_id": reverse.ID, "status": "pending"},
				bson.M{"$set": bson.M{"status": "accepted", "respondedAt": now}},
			); err != nil {
				return nil, status.Errorf(codes.Internal, "auto-accept: %v", err)
			}
			// Touch the auto-accepter's presence before notifying the
			// original requester. Same rationale as RespondToFriendRequest's
			// accept path: the sender's UI immediately refetches the
			// friends list and reads presence; a missing key here would
			// render the brand-new friend as Offline right after the
			// friendship is committed. Best-effort.
			if perr := keys.TouchPresence(ctx, s.rdb, fromID); perr != nil {
				log.FromContext(ctx).Warn("touch presence on auto-accept failed",
					"component", "friends", "user_id", fromID, "err", perr)
			}

			// Tell the original requester (Bob) that the request just flipped
			// to accepted. Without this push he'd only learn via polling
			// GetFriendsList. Best-effort: a publish failure doesn't fail
			// the RPC — the friendship is already committed in Mongo.
			s.publishFriendRequestAccepted(ctx, friendAcceptedEvent{
				RecipientUserID:  reverse.FromUserID, // Bob, the original sender
				AccepterUserID:   fromID,             // Alice, who just sent in reverse
				AccepterUsername: caller.Username,
				RequestID:        reverse.ID,
			})
			return &pb.SendFriendRequestResponse{Success: true, RequestId: reverse.ID}, nil
		}
		// reverse.Status == "rejected": fall through and let the caller
		// create a forward request. The rejected reverse row stays as a
		// historical record.
	} else if !errors.Is(reverseErr, mongo.ErrNoDocuments) {
		return nil, status.Errorf(codes.Internal, "reverse lookup: %v", reverseErr)
	}

	// Forward direction: insert (or fast-path the existing row).
	now := time.Now().UTC()
	doc := models.FriendRequest{
		ID:           uuid.New().String(),
		FromUserID:   fromID,
		FromUsername: caller.Username,
		ToUserID:     target.ID,
		ToUsername:   target.Username,
		Status:       "pending",
		CreatedAt:    now,
	}
	_, insErr := s.mongoDB.Collection(friendRequestsCollection).InsertOne(ctx, doc)
	if insErr != nil {
		if mongo.IsDuplicateKeyError(insErr) {
			// Another row already exists in the forward direction. Re-read
			// to see whether it's pending (idempotent retry — return same
			// id) or already accepted (return ALREADY_FRIENDS).
			var existing models.FriendRequest
			if err := s.mongoDB.Collection(friendRequestsCollection).FindOne(ctx,
				bson.M{"fromUserId": fromID, "toUserId": target.ID}).Decode(&existing); err != nil {
				return nil, status.Errorf(codes.Internal, "load existing: %v", err)
			}
			switch existing.Status {
			case "accepted":
				return &pb.SendFriendRequestResponse{ErrorCode: "ALREADY_FRIENDS", RequestId: existing.ID}, nil
			case "pending":
				return &pb.SendFriendRequestResponse{Success: true, RequestId: existing.ID, ErrorCode: "ALREADY_PENDING"}, nil
			}
			// Rejected forward row: surface as ALREADY_PENDING-ish, but
			// the cleaner outcome is "we kept the rejection." Return
			// the existing id with no error so the client can decide.
			return &pb.SendFriendRequestResponse{Success: false, RequestId: existing.ID, ErrorCode: "ALREADY_PENDING"}, nil
		}
		return nil, status.Errorf(codes.Internal, "insert: %v", insErr)
	}

	// Best-effort push: failure to publish doesn't fail the RPC. The
	// recipient will see the request when they next call
	// GetFriendRequests anyway.
	notifJSON, _ := json.Marshal(map[string]any{
		"event":        "notif.friend.request_received",
		"userId":       target.ID,
		"fromUserId":   fromID,
		"fromUsername": caller.Username,
		"requestId":    doc.ID,
	})
	if err := s.publish(ctx, "notif.friend.request_received", notifJSON); err != nil {
		log.FromContext(ctx).Warn("publish notif.friend.request_received failed",
			"component", "friends", "err", err)
	}

	return &pb.SendFriendRequestResponse{Success: true, RequestId: doc.ID}, nil
}

// RespondToFriendRequest accepts or rejects a pending incoming request.
// The atomic UpdateOne with status="pending" filter is the dedup point:
// a second response is a no-op (ALREADY_RESPONDED). The recipient check
// is enforced by the toUserId filter — the wrong caller's UpdateOne sees
// MatchedCount == 0 and surfaces NOT_RECIPIENT.
func (s *scoringServer) RespondToFriendRequest(ctx context.Context, req *pb.RespondToFriendRequestRequest) (*pb.RespondToFriendRequestResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if req.RequestId == "" {
		return nil, status.Error(codes.InvalidArgument, "requestId required")
	}

	// Read first so we can distinguish NOT_FOUND from NOT_RECIPIENT
	// from ALREADY_RESPONDED. A single UpdateOne with the recipient
	// guard would collapse all three into "not modified."
	var existing models.FriendRequest
	if err := s.mongoDB.Collection(friendRequestsCollection).FindOne(ctx,
		bson.M{"_id": req.RequestId}).Decode(&existing); err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return &pb.RespondToFriendRequestResponse{ErrorCode: "NOT_FOUND"}, nil
		}
		return nil, status.Errorf(codes.Internal, "load request: %v", err)
	}
	if existing.ToUserID != uid {
		return &pb.RespondToFriendRequestResponse{ErrorCode: "NOT_RECIPIENT"}, nil
	}
	if existing.Status != "pending" {
		return &pb.RespondToFriendRequestResponse{ErrorCode: "ALREADY_RESPONDED"}, nil
	}

	newStatus := "rejected"
	if req.Accept {
		newStatus = "accepted"
	}
	now := time.Now().UTC()
	res, err := s.mongoDB.Collection(friendRequestsCollection).UpdateOne(ctx,
		bson.M{"_id": req.RequestId, "status": "pending"},
		bson.M{"$set": bson.M{"status": newStatus, "respondedAt": now}},
	)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "respond: %v", err)
	}
	if res.MatchedCount == 0 {
		// Concurrent racer responded between our read and write.
		return &pb.RespondToFriendRequestResponse{ErrorCode: "ALREADY_RESPONDED"}, nil
	}
	// On accept, push the original sender so they learn in real time
	// (mirrors the auto-accept-reverse path in SendFriendRequest). Reject
	// is silent on purpose — surfacing rejections would create an
	// uncomfortable UX without giving the rejector any control.
	if newStatus == "accepted" {
		// Touch the acceptor's presence BEFORE publishing the accepted
		// event. The sender's FCM handler invalidates friendsListProvider
		// on receipt, which triggers GetFriendsList → AreOnline; without
		// this refresh, a stale-or-missing presence key would render the
		// brand-new friend as Offline immediately after the friendship
		// is committed (the act of accepting proves you're online).
		// Best-effort: a failure here logs but doesn't fail the RPC,
		// since the friendship is already accepted.
		if perr := keys.TouchPresence(ctx, s.rdb, uid); perr != nil {
			log.FromContext(ctx).Warn("touch presence on accept failed",
				"component", "friends", "user_id", uid, "err", perr)
		}

		// Resolve the responder's username for the push body so the
		// recipient sees "<friend> accepted your request" instead of an
		// opaque user id. Best-effort lookup; a failure here doesn't
		// fail the RPC.
		var responder struct {
			Username string `bson:"username"`
		}
		_ = s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": uid}).Decode(&responder)
		s.publishFriendRequestAccepted(ctx, friendAcceptedEvent{
			RecipientUserID:  existing.FromUserID, // original sender
			AccepterUserID:   uid,
			AccepterUsername: responder.Username,
			RequestID:        existing.ID,
		})
	}
	return &pb.RespondToFriendRequestResponse{Success: true}, nil
}

// GetFriendsList returns the caller's accepted friendships, deduplicated
// across the two directions of the relationship. Each friend gets the
// online flag from a single batch MGET on the presence keys.
//
// Sort order is "newest friendship first" — we use friended-at as a
// proxy for "active relationship" so the user's UI reflects recent
// activity by default.
func (s *scoringServer) GetFriendsList(ctx context.Context, _ *pb.GetFriendsListRequest) (*pb.GetFriendsListResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	cur, err := s.mongoDB.Collection(friendRequestsCollection).Find(ctx, bson.M{
		"$or": []bson.M{
			{"fromUserId": uid, "status": "accepted"},
			{"toUserId": uid, "status": "accepted"},
		},
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load friends: %v", err)
	}
	defer cur.Close(ctx)

	var rows []models.FriendRequest
	if err := cur.All(ctx, &rows); err != nil {
		return nil, status.Errorf(codes.Internal, "decode friends: %v", err)
	}

	// Project each row onto "the friend" — the user that ISN'T the caller.
	// Build the userID slice in one pass for the batch presence lookup.
	friends := make([]*pb.Friend, 0, len(rows))
	otherIDs := make([]string, 0, len(rows))
	type pendingFriend struct {
		userID, username string
		friendedAt       int64
	}
	pending := make([]pendingFriend, 0, len(rows))
	for _, r := range rows {
		var friendID, friendName string
		if r.FromUserID == uid {
			friendID, friendName = r.ToUserID, r.ToUsername
		} else {
			friendID, friendName = r.FromUserID, r.FromUsername
		}
		var friendedAt int64
		if r.RespondedAt != nil {
			friendedAt = r.RespondedAt.UnixMilli()
		} else {
			friendedAt = r.CreatedAt.UnixMilli()
		}
		pending = append(pending, pendingFriend{friendID, friendName, friendedAt})
		otherIDs = append(otherIDs, friendID)
	}

	online, err := keys.AreOnline(ctx, s.rdb, otherIDs)
	if err != nil {
		// Presence is best-effort — degrade to "everyone offline" rather
		// than fail the list call. The accepted-friends list is still
		// the authoritative answer.
		log.FromContext(ctx).Warn("AreOnline batch failed; rendering all offline",
			"component", "friends", "err", err)
		online = map[string]bool{}
	}

	for _, p := range pending {
		friends = append(friends, &pb.Friend{
			UserId:       p.userID,
			Username:     p.username,
			Online:       online[p.userID],
			FriendedAtMs: p.friendedAt,
		})
	}
	return &pb.GetFriendsListResponse{Friends: friends}, nil
}

// GetFriendRequests returns incoming pending requests. Outgoing
// requests aren't surfaced here in v1: senders see the request id from
// SendFriendRequest's response and don't usually need a "my outbox" UI.
func (s *scoringServer) GetFriendRequests(ctx context.Context, _ *pb.GetFriendRequestsRequest) (*pb.GetFriendRequestsResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	cur, err := s.mongoDB.Collection(friendRequestsCollection).Find(ctx,
		bson.M{"toUserId": uid, "status": "pending"})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "load incoming: %v", err)
	}
	defer cur.Close(ctx)

	var rows []models.FriendRequest
	if err := cur.All(ctx, &rows); err != nil {
		return nil, status.Errorf(codes.Internal, "decode incoming: %v", err)
	}
	out := make([]*pb.FriendRequest, 0, len(rows))
	for _, r := range rows {
		var respondedMs int64
		if r.RespondedAt != nil {
			respondedMs = r.RespondedAt.UnixMilli()
		}
		out = append(out, &pb.FriendRequest{
			Id:            r.ID,
			FromUserId:    r.FromUserID,
			FromUsername:  r.FromUsername,
			ToUserId:      r.ToUserID,
			ToUsername:    r.ToUsername,
			Status:        r.Status,
			CreatedAtMs:   r.CreatedAt.UnixMilli(),
			RespondedAtMs: respondedMs,
		})
	}
	return &pb.GetFriendRequestsResponse{Incoming: out}, nil
}

// Heartbeat refreshes the caller's presence TTL. Cheap and idempotent;
// clients call this on app foreground and on a ~30s interval while
// open. The presence key stops existing PresenceTTL after the last
// heartbeat — readers (GetFriendsList) infer offline from the absent key.
func (s *scoringServer) Heartbeat(ctx context.Context, _ *pb.HeartbeatRequest) (*pb.HeartbeatResponse, error) {
	uid, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if err := keys.TouchPresence(ctx, s.rdb, uid); err != nil {
		return nil, status.Errorf(codes.Internal, "touch presence: %v", err)
	}
	return &pb.HeartbeatResponse{Success: true}, nil
}

// ChallengeFriend creates a private 1v1 room between the caller and the
// friend, publishes notif.friend.challenge, and returns the room id.
//
// The room is created with the same Redis layout matchmaking uses
// (room:{id}:players hash, room:{id}:state, room:{id}:round) and the
// same match.created RabbitMQ event the quiz service consumes — so the
// quiz flow doesn't need to know the room came from a challenge vs. a
// pool match. Only matchmaking knows about the rating-based pool;
// scoring writes directly because we know both players upfront.
//
// Privacy: the room is exclusive to the two players because no other
// path can add a userId to room:{id}:players. The matchmaking pool
// picks players from its ZSET; the quiz service's StreamGameEvents
// validates the caller is in the players hash before sending events.
// A third party can't join an existing room without first being in
// the players hash, which only the room creator writes.
func (s *scoringServer) ChallengeFriend(ctx context.Context, req *pb.ChallengeFriendRequest) (*pb.ChallengeFriendResponse, error) {
	fromID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}
	if req.FriendUserId == "" {
		return nil, status.Error(codes.InvalidArgument, "friendUserId required")
	}
	// §4.7 PR-B2: bound the user-supplied id length so a forged value
	// like "../../etc/passwd" (40 bytes) or a 1MB SQLi payload doesn't
	// reach Mongo. UUIDs are 36 chars; seeded test ids (`user_alice`)
	// are short. 128 is a generous fence above both — anything longer
	// is almost certainly an attack.
	if err := validate.MaxLen(req.FriendUserId, 128); err != nil {
		return nil, status.Error(codes.InvalidArgument, "friendUserId is too long")
	}
	if req.FriendUserId == fromID {
		return &pb.ChallengeFriendResponse{ErrorCode: "NOT_FRIENDS"}, nil
	}

	// Friendship check: an accepted row exists in EITHER direction.
	count, err := s.mongoDB.Collection(friendRequestsCollection).CountDocuments(ctx, bson.M{
		"status": "accepted",
		"$or": []bson.M{
			{"fromUserId": fromID, "toUserId": req.FriendUserId},
			{"fromUserId": req.FriendUserId, "toUserId": fromID},
		},
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "friendship check: %v", err)
	}
	if count == 0 {
		return &pb.ChallengeFriendResponse{ErrorCode: "NOT_FRIENDS"}, nil
	}

	// Throttle SETNX so a double-tap or rapid retry doesn't create two
	// rooms + two notifs. 30 seconds is the debounce window.
	//
	// Held throughout the rest of the handler so concurrent calls see
	// THROTTLED, but compensated (DEL) on every error return below — a
	// failed challenge mustn't lock the user out for 30 seconds when no
	// room ever existed. We only keep the throttle on the happy path.
	//
	// Bidirectional defense: TryClaimChallenge stores the candidate roomID
	// as the throttle value on a canonical (a,b) pair key, so when both
	// users simultaneously tap Challenge on each other the second caller
	// gets the FIRST caller's room back instead of spawning a parallel
	// solo room. Without this, the two clients ended up in separate rooms
	// (each rendering "VICTORY rank #1, opponent score 0") — see PR #55.
	candidateRoomID := uuid.New().String()
	claimed, existingRoomID, err := keys.TryClaimChallenge(ctx, s.rdb, fromID, req.FriendUserId, candidateRoomID)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "throttle: %v", err)
	}
	if !claimed {
		// Pair already has an active challenge in flight. If we can read
		// back the first caller's roomID, join them there; otherwise the
		// claim races with TTL expiry and we surface THROTTLED so the
		// client can retry the next tick.
		if existingRoomID != "" {
			return &pb.ChallengeFriendResponse{Success: true, RoomId: existingRoomID}, nil
		}
		return &pb.ChallengeFriendResponse{ErrorCode: "THROTTLED"}, nil
	}
	throttleHeld := true
	defer func() {
		if throttleHeld {
			// Use Background — the request ctx may be cancelled by the
			// time we get here, but the throttle key release must still
			// land or the caller stays locked out.
			if delErr := s.rdb.Del(context.Background(),
				keys.ChallengeThrottle(fromID, req.FriendUserId)).Err(); delErr != nil {
				log.FromContext(ctx).Warn("release throttle on error path failed",
					"component", "friends", "from_id", fromID, "to_id", req.FriendUserId, "err", delErr)
			}
		}
	}()

	// Resolve usernames + plans for the room players hash so leaderboard
	// rendering doesn't have to look them up later. Mirrors the pattern
	// in matchmaking/main.go createRoom.
	//
	// mongo.ErrNoDocuments here means a stale JWT or deleted account —
	// surface as NotFound so the client can re-auth or render a friendly
	// error rather than swallow a 500. Other lookup failures stay Internal.
	resolvePlayer := func(uid string) (models.PlayerInfo, error) {
		var u struct {
			Username string `bson:"username"`
			Rating   int32  `bson:"rating"`
			Plan     string `bson:"plan"`
		}
		if err := s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": uid}).Decode(&u); err != nil {
			return models.PlayerInfo{}, fmt.Errorf("load player %s: %w", uid, err)
		}
		if u.Username == "" {
			u.Username = uid
		}
		if u.Plan == "" {
			u.Plan = "free"
		}
		if u.Rating == 0 {
			u.Rating = 1200
		}
		return models.PlayerInfo{UserID: uid, Username: u.Username, Rating: u.Rating, Plan: u.Plan}, nil
	}
	challenger, err := resolvePlayer(fromID)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, status.Errorf(codes.NotFound, "%v", err)
		}
		return nil, status.Errorf(codes.Internal, "%v", err)
	}
	friend, err := resolvePlayer(req.FriendUserId)
	if err != nil {
		if errors.Is(err, mongo.ErrNoDocuments) {
			return nil, status.Errorf(codes.NotFound, "%v", err)
		}
		return nil, status.Errorf(codes.Internal, "%v", err)
	}

	// Friendly hint when the friend's presence has lapsed. Doesn't
	// block the challenge — the notification will reach them via FCM
	// regardless and they can accept whenever they next open the app.
	friendOnline, _ := keys.IsOnline(ctx, s.rdb, req.FriendUserId)

	roomID := candidateRoomID
	now := time.Now().Unix()
	playerIDs := []string{fromID, req.FriendUserId}

	pipe := s.rdb.TxPipeline()
	for _, info := range []models.PlayerInfo{challenger, friend} {
		j, jerr := json.Marshal(info)
		if jerr != nil {
			return nil, status.Errorf(codes.Internal, "marshal player: %v", jerr)
		}
		pipe.HSet(ctx, keys.Players(roomID), info.UserID, string(j))
	}
	pipe.Expire(ctx, keys.Players(roomID), keys.RoomTTL)

	state := models.RoomState{
		RoomID:    roomID,
		PlayerIDs: playerIDs,
		Status:    "waiting",
		Round:     0,
		CreatedAt: now,
	}
	stateJSON, jerr := json.Marshal(state)
	if jerr != nil {
		return nil, status.Errorf(codes.Internal, "marshal state: %v", jerr)
	}
	pipe.Set(ctx, keys.State(roomID), string(stateJSON), keys.RoomTTL)
	pipe.Set(ctx, keys.Round(roomID), 0, keys.RoomTTL)

	if _, err := pipe.Exec(ctx); err != nil {
		return nil, status.Errorf(codes.Internal, "write room: %v", err)
	}

	// Durably enqueue the friend-challenge push BEFORE attempting to
	// publish. A transient RabbitMQ failure here would otherwise
	// permanently lose the FCM (the room is already committed in Redis
	// but the recipient never gets the push). drainChallengeNotifOutbox
	// retries unprocessed rows on a 30s ticker — see friends_outbox.go.
	outboxRow := challengeNotifOutboxRow{
		ID:           uuid.New().String(),
		RecipientID:  req.FriendUserId,
		FromUserID:   fromID,
		FromUsername: challenger.Username,
		RoomID:       roomID,
		CreatedAt:    time.Now().UTC(),
	}
	if err := s.enqueueChallengeNotifOutbox(ctx, outboxRow); err != nil {
		// Rare: Mongo write failed AFTER Redis room commit. Log loudly —
		// the room exists but no push will fire. Don't fail the RPC: the
		// challenger still has the roomId and can share it directly.
		log.FromContext(ctx).Error("enqueue challenge notif outbox failed",
			"component", "friends", "room_id", roomID, "err", err)
	}

	// match.created is what the quiz service consumes to start the
	// round. Identical event shape to matchmaking's publish, so the
	// quiz consumer doesn't need to know about challenges.
	//
	// Contract note: matchmaking's publish is `{roomId, playerIds,
	// createdAt}`. We add an OPTIONAL `source` field for log triage —
	// consumers must ignore unknown fields (the quiz consumer already
	// does). Recorded here so a future schema migration knows the field
	// is publisher-side optional, not part of the canonical payload.
	event := map[string]any{
		"roomId":    roomID,
		"playerIds": playerIDs,
		"createdAt": now,
		"source":    "friend_challenge",
	}
	eventJSON, _ := json.Marshal(event)
	if err := s.publish(ctx, "match.created", eventJSON); err != nil {
		// We've already committed the room state — log and return the
		// roomId regardless. The quiz service will pick up the room
		// when the event eventually flows OR when matchmaking republishes.
		// (Worst case: client polls room state directly.)
		log.FromContext(ctx).Warn("publish match.created for challenge room failed",
			"component", "friends", "room_id", roomID, "err", err)
	}

	// Notification: separate publish from match.created so the topic-
	// exchange consumers stay clean (push-notification-queue binds
	// notif.# only). Friendly hint when offline lets the recipient
	// see "Alice challenged you to a quiz" on next open even without
	// a live FCM token.
	notifJSON, _ := json.Marshal(map[string]any{
		"event":           "notif.friend.challenge",
		"userId":          req.FriendUserId,
		"fromUserId":      fromID,
		"fromUsername":    challenger.Username,
		"roomId":          roomID,
		"recipientOnline": friendOnline,
		"outboxId":        outboxRow.ID,
	})
	if err := s.publish(ctx, "notif.friend.challenge", notifJSON); err != nil {
		// Don't mark the outbox row processed — the drain worker will
		// retry on its next tick.
		log.FromContext(ctx).Warn("publish notif.friend.challenge failed; will retry",
			"component", "friends", "outbox_id", outboxRow.ID, "err", err)
	} else {
		// Inline success path: mark processed so the drain worker doesn't
		// re-fire the same notif. Failure to mark is acceptable — the
		// drainer will publish again, and the consumer is idempotent on
		// (recipient, roomId).
		if err := s.markChallengeNotifProcessed(ctx, outboxRow.ID); err != nil {
			log.FromContext(ctx).Warn("mark challenge notif processed failed",
				"component", "friends", "outbox_id", outboxRow.ID, "err", err)
		}
	}

	resp := &pb.ChallengeFriendResponse{Success: true, RoomId: roomID}
	if !friendOnline {
		// Best-effort hint surfaced to the client so the challenger can
		// see "they're offline — they'll see this when they're back."
		// Non-blocking — the challenge still goes out via FCM.
		resp.ErrorCode = "FRIEND_OFFLINE"
	}
	// Successful return: keep the throttle so a rapid follow-up click
	// hits THROTTLED rather than creating a second room.
	throttleHeld = false
	return resp, nil
}
