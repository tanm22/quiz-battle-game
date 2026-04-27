package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"log/slog"
	"net"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	amqp "github.com/rabbitmq/amqp091-go"
	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"golang.org/x/crypto/bcrypt"
	"google.golang.org/api/idtoken"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/coins"
	"quiz-battle/pkg/email"
	"quiz-battle/pkg/keys"
	"quiz-battle/pkg/log"
	"quiz-battle/pkg/models"
	pb "quiz-battle/proto"
)

var (
	usernameRegex = regexp.MustCompile(`^[a-zA-Z0-9_]{3,20}$`)
	emailRegex    = regexp.MustCompile(`^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$`)
)

type authServer struct {
	pb.UnimplementedAuthServiceServer
	mongoDB   *mongo.Database
	ledger    *coins.Ledger // §4.3 — every coin grant goes through this
	rdb       *redis.Client
	amqpConn  *amqp.Connection
	jwtSecret string
	mailer    *email.Sender
}

func (s *authServer) users() *mongo.Collection {
	return s.mongoDB.Collection("users")
}

// ---------------------------------------------------------------------------
// Register — username + password + optional email
// ---------------------------------------------------------------------------

func (s *authServer) Register(ctx context.Context, req *pb.RegisterRequest) (*pb.AuthResponse, error) {
	if !usernameRegex.MatchString(req.Username) {
		return nil, status.Error(codes.InvalidArgument, "username must be 3-20 alphanumeric or underscore characters")
	}
	if len(req.Password) < 6 {
		return nil, status.Error(codes.InvalidArgument, "password must be at least 6 characters")
	}
	if req.Email != "" && !emailRegex.MatchString(req.Email) {
		return nil, status.Error(codes.InvalidArgument, "invalid email format")
	}

	var existing bson.M
	if err := s.users().FindOne(ctx, bson.M{"username": req.Username}).Decode(&existing); err == nil {
		return nil, status.Error(codes.AlreadyExists, "username already taken")
	}
	if req.Email != "" {
		if err := s.users().FindOne(ctx, bson.M{"email": req.Email}).Decode(&existing); err == nil {
			return nil, status.Error(codes.AlreadyExists, "email already in use")
		}
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "hash error: %v", err)
	}

	userID := uuid.New().String()
	refCode := s.generateUniqueReferralCode(ctx, userID)
	user := models.User{
		ID:            userID,
		Username:      req.Username,
		PasswordHash:  string(hash),
		Email:         req.Email,
		IsGuest:       false,
		Rating:        1200,
		MatchesPlayed: 0,
		Wins:          0,
		Plan:          "free",
		Coins:         0,
		ReferralCode:  refCode,
		Streak:        models.Streak{Current: 0, Longest: 0, LastClaimedDate: ""},
		CreatedAt:     time.Now().Unix(),
	}
	if _, err := s.users().InsertOne(ctx, user); err != nil {
		return nil, status.Errorf(codes.Internal, "insert error: %v", err)
	}

	// Apply referral code if provided
	if req.ReferralCode != "" {
		s.applyReferral(ctx, userID, req.ReferralCode)
	}

	// Process streak (first login = day 1)
	streakInfo, reward, _ := s.processStreak(ctx, &user)

	token, err := auth.GenerateToken(userID, req.Username, s.jwtSecret)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "token error: %v", err)
	}

	log.FromContext(ctx).Info("registered user", "username", req.Username, "user_id", userID)
	return &pb.AuthResponse{
		UserId: userID, Username: req.Username, Token: token,
		Rating: 1200, MatchesPlayed: 0, Wins: 0, Email: req.Email, IsGuest: false,
		Plan: "free", ReferralCode: refCode, Streak: streakInfo, Reward: reward,
		StreakUpdated:       true,
		OnboardingCompleted: false,
	}, nil
}

// ---------------------------------------------------------------------------
// Login — username + password
// ---------------------------------------------------------------------------

func (s *authServer) Login(ctx context.Context, req *pb.LoginRequest) (*pb.AuthResponse, error) {
	if req.Username == "" || req.Password == "" {
		return nil, status.Error(codes.InvalidArgument, "username and password required")
	}

	var user models.User
	err := s.users().FindOne(ctx, bson.M{"username": req.Username}).Decode(&user)
	if err == mongo.ErrNoDocuments {
		return nil, status.Error(codes.NotFound, "invalid username or password")
	}
	if err != nil {
		return nil, status.Errorf(codes.Internal, "db error: %v", err)
	}

	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(req.Password)); err != nil {
		return nil, status.Error(codes.NotFound, "invalid username or password")
	}

	token, err := auth.GenerateToken(user.ID, user.Username, s.jwtSecret)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "token error: %v", err)
	}

	// Process streak on login
	streakInfo, reward, streakUpdated := s.processStreak(ctx, &user)

	log.FromContext(ctx).Info("login", "username", user.Username, "user_id", user.ID)
	return &pb.AuthResponse{
		UserId: user.ID, Username: user.Username, Token: token,
		Rating: user.Rating, MatchesPlayed: user.MatchesPlayed, Wins: user.Wins,
		Email: user.Email, IsGuest: user.IsGuest,
		Plan: user.Plan, Coins: user.Coins, Streak: streakInfo,
		ReferralCode: user.ReferralCode, StreakUpdated: streakUpdated, Reward: reward,
		OnboardingCompleted: user.OnboardingCompleted,
	}, nil
}

// ---------------------------------------------------------------------------
// GetProfile
// ---------------------------------------------------------------------------

func (s *authServer) GetProfile(ctx context.Context, _ *pb.GetProfileRequest) (*pb.ProfileResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	var user models.User
	if err := s.users().FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	return &pb.ProfileResponse{
		UserId: user.ID, Username: user.Username, Rating: user.Rating,
		MatchesPlayed: user.MatchesPlayed, Wins: user.Wins,
		Email: user.Email, IsGuest: user.IsGuest,
		DisplayName:         user.DisplayName,
		AvatarUrl:           user.AvatarUrl,
		PreferredTopics:     user.PreferredTopics,
		OnboardingCompleted: user.OnboardingCompleted,
	}, nil
}

// ---------------------------------------------------------------------------
// GuestLogin — instant play, no credentials
// ---------------------------------------------------------------------------

func (s *authServer) GuestLogin(ctx context.Context, _ *pb.GuestLoginRequest) (*pb.AuthResponse, error) {
	userID := uuid.New().String()
	shortID := userID[:8]
	username := "Guest_" + shortID

	// Generate referral code even for guests, so linking their email later preserves the code.
	// Note: guests CANNOT be referred (applyReferral blocks it), but they CAN refer others.
	refCode := s.generateUniqueReferralCode(ctx, userID)

	user := models.User{
		ID:           userID,
		Username:     username,
		IsGuest:      true,
		Rating:       1200,
		Plan:         "free",
		ReferralCode: refCode,
		CreatedAt:    time.Now().Unix(),
	}
	if _, err := s.users().InsertOne(ctx, user); err != nil {
		return nil, status.Errorf(codes.Internal, "insert error: %v", err)
	}

	token, err := auth.GenerateToken(userID, username, s.jwtSecret)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "token error: %v", err)
	}

	log.FromContext(ctx).Info("guest login", "username", username, "user_id", userID)
	return &pb.AuthResponse{
		UserId: userID, Username: username, Token: token,
		Rating: 1200, IsGuest: true, ReferralCode: refCode,
		OnboardingCompleted: false,
	}, nil
}

// ---------------------------------------------------------------------------
// SendEmailCode — generates and emails a 6-digit code
// ---------------------------------------------------------------------------

func (s *authServer) SendEmailCode(ctx context.Context, req *pb.SendEmailCodeRequest) (*pb.SendEmailCodeResponse, error) {
	if !emailRegex.MatchString(req.Email) {
		return nil, status.Error(codes.InvalidArgument, "invalid email format")
	}
	purpose := req.Purpose
	if purpose != "login" && purpose != "reset" && purpose != "link" {
		return nil, status.Error(codes.InvalidArgument, "purpose must be login, reset, or link")
	}

	// For login/reset: verify user with this email exists
	if purpose == "login" || purpose == "reset" {
		var existing bson.M
		if err := s.users().FindOne(ctx, bson.M{"email": req.Email}).Decode(&existing); err != nil {
			return nil, status.Error(codes.NotFound, "no account with this email")
		}
	}

	// Rate limit
	allowed, err := keys.CheckEmailRateLimit(ctx, s.rdb, req.Email)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "rate limit check: %v", err)
	}
	if !allowed {
		return nil, status.Error(codes.ResourceExhausted, "please wait 60 seconds before requesting another code")
	}

	code := generateCode()
	if err := keys.StoreEmailCode(ctx, s.rdb, req.Email, purpose, code); err != nil {
		return nil, status.Errorf(codes.Internal, "store code: %v", err)
	}

	if err := s.mailer.SendCode(req.Email, code, purpose); err != nil {
		log.FromContext(ctx).Warn("email send failed", "err", err)
		// Dev convenience: when DEV_MODE=true, log the code so a developer can
		// complete the flow without configured email. NEVER set DEV_MODE in
		// production — the code becomes a queryable JSON attr in log
		// aggregators and anyone with read access can mine recent OTPs.
		if os.Getenv("DEV_MODE") == "true" {
			log.FromContext(ctx).Debug("dev fallback code", "email", req.Email, "purpose", purpose, "code", code)
		}
	} else {
		log.FromContext(ctx).Info("email code sent", "purpose", purpose, "email", log.RedactEmail(req.Email))
	}

	return &pb.SendEmailCodeResponse{Sent: true}, nil
}

// ---------------------------------------------------------------------------
// VerifyEmailCode — verifies code, returns JWT for login flow
// ---------------------------------------------------------------------------

func (s *authServer) VerifyEmailCode(ctx context.Context, req *pb.VerifyEmailCodeRequest) (*pb.VerifyEmailCodeResponse, error) {
	if req.Email == "" || req.Code == "" {
		return nil, status.Error(codes.InvalidArgument, "email and code required")
	}

	// Try all purposes — the code storage is purpose-scoped
	for _, purpose := range []string{"login", "reset", "link"} {
		valid, err := keys.CheckEmailCode(ctx, s.rdb, req.Email, purpose, req.Code)
		if err != nil {
			continue
		}
		if valid {
			// For login purpose: return JWT
			if purpose == "login" {
				var user models.User
				if err := s.users().FindOne(ctx, bson.M{"email": req.Email}).Decode(&user); err != nil {
					return nil, status.Error(codes.NotFound, "user not found")
				}
				token, err := auth.GenerateToken(user.ID, user.Username, s.jwtSecret)
				if err != nil {
					return nil, status.Errorf(codes.Internal, "token error: %v", err)
				}
				log.FromContext(ctx).Info("email login verified", "email", log.RedactEmail(req.Email))
				return &pb.VerifyEmailCodeResponse{Verified: true, Token: token, UserId: user.ID}, nil
			}

			// For reset/link: just confirm verification
			// Store a short-lived verification flag for the subsequent reset/link call
			keys.StoreEmailCode(ctx, s.rdb, req.Email, purpose+":verified", "1")
			return &pb.VerifyEmailCodeResponse{Verified: true}, nil
		}
	}

	return &pb.VerifyEmailCodeResponse{Verified: false}, nil
}

// ---------------------------------------------------------------------------
// LoginWithEmail — sends login code, client calls VerifyEmailCode next
// ---------------------------------------------------------------------------

func (s *authServer) LoginWithEmail(ctx context.Context, req *pb.EmailLoginRequest) (*pb.SendEmailCodeResponse, error) {
	return s.SendEmailCode(ctx, &pb.SendEmailCodeRequest{
		Email:   req.Email,
		Purpose: "login",
	})
}

// ---------------------------------------------------------------------------
// LinkEmail — links email to authenticated user (after code verification)
// ---------------------------------------------------------------------------

func (s *authServer) LinkEmail(ctx context.Context, req *pb.LinkEmailRequest) (*pb.LinkEmailResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	if !emailRegex.MatchString(req.Email) {
		return nil, status.Error(codes.InvalidArgument, "invalid email format")
	}

	// Verify the code
	valid, err := keys.CheckEmailCode(ctx, s.rdb, req.Email, "link", req.Code)
	if err != nil || !valid {
		return nil, status.Error(codes.PermissionDenied, "invalid or expired code")
	}

	// Check email not already used
	var existing bson.M
	if err := s.users().FindOne(ctx, bson.M{"email": req.Email}).Decode(&existing); err == nil {
		return nil, status.Error(codes.AlreadyExists, "email already linked to another account")
	}

	// Update user
	_, err = s.users().UpdateOne(ctx, bson.M{"_id": userID}, bson.M{
		"$set": bson.M{"email": req.Email, "isGuest": false},
	})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "update error: %v", err)
	}

	log.FromContext(ctx).Info("email linked", "email", log.RedactEmail(req.Email), "user_id", userID)
	return &pb.LinkEmailResponse{Linked: true}, nil
}

// ---------------------------------------------------------------------------
// ResetPassword — after email code verification
// ---------------------------------------------------------------------------

func (s *authServer) ResetPassword(ctx context.Context, req *pb.ResetPasswordRequest) (*pb.ResetPasswordResponse, error) {
	if !emailRegex.MatchString(req.Email) {
		return nil, status.Error(codes.InvalidArgument, "invalid email format")
	}
	if len(req.NewPassword) < 6 {
		return nil, status.Error(codes.InvalidArgument, "password must be at least 6 characters")
	}

	// Verify the code
	valid, err := keys.CheckEmailCode(ctx, s.rdb, req.Email, "reset", req.Code)
	if err != nil || !valid {
		return nil, status.Error(codes.PermissionDenied, "invalid or expired code")
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.NewPassword), bcrypt.DefaultCost)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "hash error: %v", err)
	}

	result, err := s.users().UpdateOne(ctx, bson.M{"email": req.Email}, bson.M{
		"$set": bson.M{"passwordHash": string(hash)},
	})
	if err != nil || result.MatchedCount == 0 {
		return nil, status.Error(codes.NotFound, "no account with this email")
	}

	log.FromContext(ctx).Info("password reset", "email", log.RedactEmail(req.Email))
	return &pb.ResetPasswordResponse{Success: true}, nil
}

// ---------------------------------------------------------------------------
// CheckUsername — real-time availability check
// ---------------------------------------------------------------------------

func (s *authServer) CheckUsername(ctx context.Context, req *pb.CheckUsernameRequest) (*pb.CheckUsernameResponse, error) {
	if req.Username == "" {
		return &pb.CheckUsernameResponse{Available: false}, nil
	}

	var existing bson.M
	err := s.users().FindOne(ctx, bson.M{"username": req.Username}).Decode(&existing)
	return &pb.CheckUsernameResponse{Available: err == mongo.ErrNoDocuments}, nil
}

// ---------------------------------------------------------------------------
// DeleteAccount — permanently delete user account
// ---------------------------------------------------------------------------

func (s *authServer) DeleteAccount(ctx context.Context, _ *pb.DeleteAccountRequest) (*pb.DeleteAccountResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	result, err := s.users().DeleteOne(ctx, bson.M{"_id": userID})
	if err != nil {
		return nil, status.Errorf(codes.Internal, "delete error: %v", err)
	}
	if result.DeletedCount == 0 {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	log.FromContext(ctx).Info("account deleted", "user_id", userID)
	return &pb.DeleteAccountResponse{Deleted: true}, nil
}

// ---------------------------------------------------------------------------
// UpdateProfile — onboarding completion (display name, avatar, topics, flag)
// ---------------------------------------------------------------------------

// Accepts partial updates: empty string / empty slice leaves the field
// untouched. The OnboardingCompleted bool is one-way: once true, the
// handler also stamps OnboardingCompletedAt.
func (s *authServer) UpdateProfile(ctx context.Context, req *pb.UpdateProfileRequest) (*pb.UpdateProfileResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	set := bson.M{}
	if req.DisplayName != "" {
		if len(req.DisplayName) > 40 {
			return nil, status.Error(codes.InvalidArgument, "display name too long")
		}
		set["displayName"] = sanitizeText(req.DisplayName)
	}
	if req.AvatarUrl != "" {
		if len(req.AvatarUrl) > 500 {
			return nil, status.Error(codes.InvalidArgument, "avatar url too long")
		}
		// Enforce http(s) scheme — defends against javascript: / data: URIs
		// that a future web client could render as an <img src> XSS vector.
		if !strings.HasPrefix(req.AvatarUrl, "https://") && !strings.HasPrefix(req.AvatarUrl, "http://") {
			return nil, status.Error(codes.InvalidArgument, "avatar url must be http(s)")
		}
		set["avatarUrl"] = req.AvatarUrl
	}
	if len(req.PreferredTopics) > 0 {
		if len(req.PreferredTopics) > 10 {
			return nil, status.Error(codes.InvalidArgument, "too many topics")
		}
		set["preferredTopics"] = req.PreferredTopics
	}
	if req.OnboardingCompleted {
		set["onboardingCompleted"] = true
		set["onboardingCompletedAt"] = time.Now()
	}

	if len(set) == 0 {
		return &pb.UpdateProfileResponse{Success: true}, nil
	}

	if _, err := s.users().UpdateOne(ctx,
		bson.M{"_id": userID},
		bson.M{"$set": set},
	); err != nil {
		return nil, status.Errorf(codes.Internal, "update failed: %v", err)
	}
	return &pb.UpdateProfileResponse{Success: true}, nil
}

// sanitizeText trims whitespace and strips ASCII control characters.
// UTF-8 letters/digits/punctuation/emoji pass through.
func sanitizeText(s string) string {
	s = strings.TrimSpace(s)
	out := make([]rune, 0, len(s))
	for _, r := range s {
		if r >= 0x20 || r == '\n' {
			out = append(out, r)
		}
	}
	return string(out)
}

// ---------------------------------------------------------------------------
// GoogleSignIn — verify Google ID token, upsert user, issue JWT (Phase 2)
// ---------------------------------------------------------------------------

func (s *authServer) GoogleSignIn(ctx context.Context, req *pb.GoogleSignInRequest) (*pb.GoogleSignInResponse, error) {
	googleClientID := os.Getenv("GOOGLE_CLIENT_ID")

	// Verify Google ID token
	payload, err := idtoken.Validate(ctx, req.IdToken, googleClientID)
	if err != nil {
		return nil, status.Errorf(codes.Unauthenticated, "invalid Google ID token: %v", err)
	}

	googleID, _ := payload.Claims["sub"].(string)
	email, _ := payload.Claims["email"].(string)
	name, _ := payload.Claims["name"].(string)
	picture, _ := payload.Claims["picture"].(string)

	if googleID == "" {
		return nil, status.Error(codes.InvalidArgument, "missing Google ID in token")
	}

	// Check if user exists by googleId
	var user models.User
	isNewUser := false
	err = s.users().FindOne(ctx, bson.M{"googleId": googleID}).Decode(&user)
	if err == mongo.ErrNoDocuments {
		// New user — insert
		isNewUser = true
		userID := uuid.New().String()
		user = models.User{
			ID:            userID,
			GoogleID:      googleID,
			Email:         email,
			DisplayName:   name,
			AvatarUrl:     picture,
			Username:      strings.Split(email, "@")[0],
			IsGuest:       false,
			Rating:        1200,
			MatchesPlayed: 0,
			Wins:          0,
			Plan:          "free",
			Coins:         0,
			Streak:        models.Streak{Current: 0, Longest: 0, LastClaimedDate: ""},
			CreatedAt:     time.Now().Unix(),
		}
		if _, err := s.users().InsertOne(ctx, user); err != nil {
			return nil, status.Errorf(codes.Internal, "insert failed: %v", err)
		}
	} else if err != nil {
		return nil, status.Errorf(codes.Internal, "lookup failed: %v", err)
	} else {
		// Returning user — update avatar/name
		s.users().UpdateOne(ctx, bson.M{"_id": user.ID}, bson.M{
			"$set": bson.M{"avatarUrl": picture, "displayName": name},
		})
		user.AvatarUrl = picture
		user.DisplayName = name
	}

	// New user only: generate referral code + apply referral if provided (ISSUE-12)
	if isNewUser {
		refCode := s.generateUniqueReferralCode(ctx, user.ID)
		s.users().UpdateOne(ctx, bson.M{"_id": user.ID}, bson.M{"$set": bson.M{"referralCode": refCode}})
		user.ReferralCode = refCode

		if req.ReferralCode != "" {
			s.applyReferral(ctx, user.ID, req.ReferralCode)
		}
	}

	// Process streak
	streakInfo, reward, streakUpdated := s.processStreak(ctx, &user)

	// Issue JWT
	token, err := auth.GenerateToken(user.ID, user.Username, s.jwtSecret)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "token generation failed: %v", err)
	}

	return &pb.GoogleSignInResponse{
		Token:         token,
		IsNewUser:     isNewUser,
		StreakUpdated: streakUpdated,
		Reward:        reward,
		UserProfile: &pb.UserProfile{
			UserId:              user.ID,
			Username:            user.Username,
			DisplayName:         user.DisplayName,
			Email:               user.Email,
			AvatarUrl:           user.AvatarUrl,
			Rating:              user.Rating,
			MatchesPlayed:       user.MatchesPlayed,
			Wins:                user.Wins,
			Plan:                user.Plan,
			Coins:               user.Coins,
			Streak:              streakInfo,
			ReferralCode:        user.ReferralCode,
			IsGuest:             false,
			WinStreak:           user.WinStreak,
			PreferredTopics:     user.PreferredTopics,
			OnboardingCompleted: user.OnboardingCompleted,
		},
	}, nil
}

// ---------------------------------------------------------------------------
// Streak processing — MongoDB only (ISSUE-01), IST dates
// ---------------------------------------------------------------------------

func (s *authServer) processStreak(ctx context.Context, user *models.User) (*pb.StreakInfo, *pb.RewardGrant, bool) {
	ist, _ := time.LoadLocation("Asia/Kolkata")
	today := time.Now().In(ist).Format("2006-01-02")
	yesterday := time.Now().In(ist).Add(-24 * time.Hour).Format("2006-01-02")
	twoDaysAgo := time.Now().In(ist).AddDate(0, 0, -2).Format("2006-01-02")

	streak := user.Streak
	// freezeConsumed flips true when the gap-day branch consumed a held
	// streak freeze instead of resetting the streak. Threaded out so the
	// single UpdateOne below can flip streakFreezeHeld in the same write
	// — keeping the freeze flag in lock-step with the streak fields means
	// a crash between them can't desync ("freeze burned but streak reset"
	// or "streak preserved but freeze still held").
	freezeConsumed := false

	switch {
	case streak.LastClaimedDate == today:
		// CASE A: already claimed today — idempotent
		return toStreakInfo(streak), nil, false

	case streak.LastClaimedDate == yesterday:
		// CASE B: consecutive day
		streak.Current++
		if streak.Current > streak.Longest {
			streak.Longest = streak.Current
		}
		streak.LastClaimedDate = today

	default:
		// CASE C: gap >= 2 days (or first ever login).
		//
		// §4.3 (PR 5) streak freeze policy: a held freeze bridges EXACTLY
		// ONE missed day — the lastClaimed-was-the-day-before-yesterday
		// case. A user gone longer (3+ days) has the freeze stay held
		// and the streak resets normally; the freeze remains spendable
		// for the next time they miss exactly one day. This matches
		// typical product semantics ("freeze covers a forgotten day,
		// not a long absence") and keeps the freeze meaningful — without
		// the gap cap, a 30-day disappearance would burn the freeze for
		// a +1 advance from a long-stale streak, which doesn't match
		// what users buy a freeze for.
		if user.StreakFreezeHeld && streak.LastClaimedDate == twoDaysAgo {
			streak.Current++
			if streak.Current > streak.Longest {
				streak.Longest = streak.Current
			}
			streak.LastClaimedDate = today
			freezeConsumed = true
			break
		}
		streak.Current = 1
		streak.LastClaimedDate = today
	}

	update := bson.M{"streak": streak}
	if freezeConsumed {
		update["streakFreezeHeld"] = false
	}
	res, err := s.users().UpdateOne(ctx,
		bson.M{"_id": user.ID, "streak.lastClaimedDate": bson.M{"$ne": today}},
		bson.M{"$set": update})
	if err != nil {
		log.FromContext(ctx).Error("streak update failed", "user_id", user.ID, "err", err)
	}
	if res != nil && res.ModifiedCount == 0 {
		// Race: another request already claimed today
		return toStreakInfo(user.Streak), nil, false
	}
	user.Streak = streak
	if freezeConsumed {
		user.StreakFreezeHeld = false
	}

	reward := rewardForDay(streak.Current)
	return toStreakInfo(streak), reward, true
}

func toStreakInfo(s models.Streak) *pb.StreakInfo {
	return &pb.StreakInfo{
		Current:         int32(s.Current),
		Longest:         int32(s.Longest),
		LastClaimedDate: s.LastClaimedDate,
	}
}

func rewardForDay(day int) *pb.RewardGrant {
	switch {
	case day >= 30:
		return &pb.RewardGrant{Coins: 200}
	case day >= 14:
		return &pb.RewardGrant{Coins: 200, BadgeName: "Two Week Streak"}
	case day >= 7:
		return &pb.RewardGrant{Coins: 100, BadgeName: "Weekly Warrior"}
	case day >= 5:
		return &pb.RewardGrant{Coins: 50, BonusQuizzes: 1}
	case day >= 3:
		return &pb.RewardGrant{Coins: 30}
	case day >= 2:
		return &pb.RewardGrant{Coins: 20}
	default:
		return &pb.RewardGrant{Coins: 10}
	}
}

// ---------------------------------------------------------------------------
// ClaimDailyReward — grants coins/badges for the current streak day
// ---------------------------------------------------------------------------

func (s *authServer) ClaimDailyReward(ctx context.Context, _ *pb.ClaimDailyRewardRequest) (*pb.ClaimDailyRewardResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	var user models.User
	if err := s.users().FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	ist, _ := time.LoadLocation("Asia/Kolkata")
	today := time.Now().In(ist).Format("2006-01-02")
	if user.Streak.LastClaimedDate != today {
		return nil, status.Error(codes.FailedPrecondition, "login first to update streak")
	}
	if user.Streak.RewardClaimedDate == today {
		// Already claimed today — return the reward info without granting again
		return &pb.ClaimDailyRewardResponse{
			Reward: rewardForDay(user.Streak.Current),
			Streak: toStreakInfo(user.Streak),
		}, nil
	}

	reward := rewardForDay(user.Streak.Current)

	// §4.3 invariant: every balance change writes a ledger row in the same
	// transaction (ADR-0001). Grant is idempotent on (userId, refId, reason),
	// so concurrent racers and retries after partial failure converge on a
	// single ledger entry. We Grant FIRST, then mark rewardClaimedDate so a
	// crash between the two retries safely (Grant returns existing entry).
	if _, err := s.ledger.Grant(ctx, userID, reward.Coins, coins.ReasonDailyReward,
		"streak:"+userID+":"+today,
		map[string]string{"streakDay": fmt.Sprintf("%d", user.Streak.Current)}); err != nil {
		return nil, status.Errorf(codes.Internal, "grant daily reward: %v", err)
	}
	if _, err := s.users().UpdateOne(ctx,
		bson.M{"_id": userID},
		bson.M{"$set": bson.M{"streak.rewardClaimedDate": today}}); err != nil {
		return nil, status.Errorf(codes.Internal, "mark reward claimed: %v", err)
	}

	return &pb.ClaimDailyRewardResponse{
		Reward: reward,
		Streak: toStreakInfo(user.Streak),
	}, nil
}

// ---------------------------------------------------------------------------
// GetStreakInfo
// ---------------------------------------------------------------------------

func (s *authServer) GetStreakInfo(ctx context.Context, _ *pb.GetStreakInfoRequest) (*pb.GetStreakInfoResponse, error) {
	userID, err := auth.UserIDFromContext(ctx)
	if err != nil {
		return nil, status.Error(codes.Unauthenticated, "not authenticated")
	}

	var user models.User
	if err := s.users().FindOne(ctx, bson.M{"_id": userID}).Decode(&user); err != nil {
		return nil, status.Error(codes.NotFound, "user not found")
	}

	return &pb.GetStreakInfoResponse{Streak: toStreakInfo(user.Streak)}, nil
}

// ---------------------------------------------------------------------------
// Referral helpers
// ---------------------------------------------------------------------------

func generateReferralCode() string {
	b := make([]byte, 4) // 8 hex chars
	rand.Read(b)
	return "REF" + strings.ToUpper(hex.EncodeToString(b))
}

// generateUniqueReferralCode retries on Redis SETNX collision (max 5 tries).
// Uses SETNX so two concurrent signups can't be assigned the same code.
func (s *authServer) generateUniqueReferralCode(ctx context.Context, userID string) string {
	for i := 0; i < 5; i++ {
		code := generateReferralCode()
		ok, err := s.rdb.SetNX(ctx, keys.RefCode(code), userID, 0).Result()
		if err == nil && ok {
			return code
		}
	}
	// Vanishingly rare; fall back to last attempt (force set).
	code := generateReferralCode()
	keys.SetRefCode(ctx, s.rdb, code, userID)
	return code
}

func (s *authServer) applyReferral(ctx context.Context, refereeID, code string) {
	referrerID, err := keys.GetRefCode(ctx, s.rdb, code)
	if err != nil || referrerID == "" {
		log.FromContext(ctx).Info("invalid referral code", "code", code)
		return
	}

	// Anti-abuse: reject self-referral
	if referrerID == refereeID {
		log.FromContext(ctx).Info("rejected self-referral", "referee_id", refereeID)
		return
	}

	// Anti-abuse: refuse to reward referrals of guest accounts (farmable)
	var referee models.User
	if err := s.users().FindOne(ctx, bson.M{"_id": refereeID}).Decode(&referee); err == nil && referee.IsGuest {
		log.FromContext(ctx).Info("rejected guest referral", "referee_id", refereeID)
		return
	}

	// Anti-abuse: max 20 converted referrals per referrer
	count, _ := s.mongoDB.Collection("referrals").CountDocuments(ctx,
		bson.M{"referrerId": referrerID, "status": "converted"})
	if count >= 20 {
		log.FromContext(ctx).Info("referral cap reached", "referrer_id", referrerID)
		return
	}

	// Create referral document
	s.mongoDB.Collection("referrals").InsertOne(ctx, bson.M{
		"referrerId":    referrerID,
		"refereeId":     refereeID,
		"referralCode":  code,
		"status":        "pending",
		"rewardGranted": false,
		"createdAt":     time.Now(),
	})

	// Set referredBy on the referee
	s.users().UpdateOne(ctx, bson.M{"_id": refereeID}, bson.M{"$set": bson.M{"referredBy": referrerID}})
	log.FromContext(ctx).Info("referral applied", "referee_id", refereeID, "referrer_id", referrerID, "code", code)
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

func generateCode() string {
	b := make([]byte, 3)
	rand.Read(b)
	n := (int(b[0])<<16 | int(b[1])<<8 | int(b[2])) % 1000000
	return fmt.Sprintf("%06d", n)
}

// ---------------------------------------------------------------------------
// Phase 2: Cron goroutines for push notifications
// ---------------------------------------------------------------------------

// streakWarningCron publishes notif.streak.warning at 20:00 IST daily
// for users who haven't logged in today but have an active streak.
func (s *authServer) streakWarningCron(ctx context.Context) {
	ch, err := s.amqpConn.Channel()
	if err != nil {
		log.FromContext(ctx).Error("open channel failed", "cron", "streak_warning", "err", err)
		return
	}
	defer ch.Close()

	for {
		ist, _ := time.LoadLocation("Asia/Kolkata")
		now := time.Now().In(ist)
		target := time.Date(now.Year(), now.Month(), now.Day(), 20, 0, 0, 0, ist)
		if now.After(target) {
			target = target.Add(24 * time.Hour)
		}
		sleepDur := target.Sub(now)
		log.FromContext(ctx).Info("cron scheduled", "cron", "streak_warning", "sleep", sleepDur.Round(time.Minute).String())

		select {
		case <-ctx.Done():
			return
		case <-time.After(sleepDur):
		}

		today := time.Now().In(ist).Format("2006-01-02")
		cursor, err := s.mongoDB.Collection("users").Find(ctx, bson.M{
			"streak.current":         bson.M{"$gt": 0},
			"streak.lastClaimedDate": bson.M{"$ne": today},
		})
		if err != nil {
			log.FromContext(ctx).Error("cron query failed", "cron", "streak_warning", "err", err)
			continue
		}

		count := 0
		for cursor.Next(ctx) {
			var user bson.M
			if err := cursor.Decode(&user); err != nil {
				continue
			}
			userID, _ := user["_id"].(string)
			streak, _ := user["streak"].(bson.M)
			current, _ := streak["current"].(int32)

			payload, _ := json.Marshal(map[string]interface{}{
				"event":         "notif.streak.warning",
				"userId":        userID,
				"currentStreak": current,
			})
			ch.PublishWithContext(ctx, "sx", "notif.streak.warning", false, false, amqp.Publishing{
				ContentType: "application/json",
				Body:        payload,
			})
			count++
		}
		cursor.Close(ctx)
		log.FromContext(ctx).Info("cron run complete", "cron", "streak_warning", "notified", count)
	}
}

// dailyRewardNudgeCron publishes notif.daily.reward at 08:00 IST daily.
func (s *authServer) dailyRewardNudgeCron(ctx context.Context) {
	ch, err := s.amqpConn.Channel()
	if err != nil {
		log.FromContext(ctx).Error("open channel failed", "cron", "daily_reward_nudge", "err", err)
		return
	}
	defer ch.Close()

	for {
		ist, _ := time.LoadLocation("Asia/Kolkata")
		now := time.Now().In(ist)
		target := time.Date(now.Year(), now.Month(), now.Day(), 8, 0, 0, 0, ist)
		if now.After(target) {
			target = target.Add(24 * time.Hour)
		}
		sleepDur := target.Sub(now)
		log.FromContext(ctx).Info("cron scheduled", "cron", "daily_reward_nudge", "sleep", sleepDur.Round(time.Minute).String())

		select {
		case <-ctx.Done():
			return
		case <-time.After(sleepDur):
		}

		today := time.Now().In(ist).Format("2006-01-02")
		cursor, err := s.mongoDB.Collection("users").Find(ctx, bson.M{
			"streak.lastClaimedDate": bson.M{"$ne": today},
			"isGuest":                false,
		})
		if err != nil {
			log.FromContext(ctx).Error("cron query failed", "cron", "daily_reward_nudge", "err", err)
			continue
		}

		count := 0
		for cursor.Next(ctx) {
			var user bson.M
			if err := cursor.Decode(&user); err != nil {
				continue
			}
			userID, _ := user["_id"].(string)
			payload, _ := json.Marshal(map[string]interface{}{
				"event":  "notif.daily.reward",
				"userId": userID,
			})
			ch.PublishWithContext(ctx, "sx", "notif.daily.reward", false, false, amqp.Publishing{
				ContentType: "application/json",
				Body:        payload,
			})
			count++
		}
		cursor.Close(ctx)
		log.FromContext(ctx).Info("cron run complete", "cron", "daily_reward_nudge", "notified", count)
	}
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

func main() {
	slog.SetDefault(log.Init("auth"))
	ctx := context.Background()

	// MongoDB
	mongoURI := os.Getenv("MONGO_URI")
	if mongoURI == "" {
		mongoURI = "mongodb://localhost:27017/quizbattle"
	}
	mongoClient, err := mongo.Connect(options.Client().ApplyURI(mongoURI).SetBSONOptions(&options.BSONOptions{
		ObjectIDAsHexString: true,
	}))
	if err != nil {
		log.Fatal(ctx, "mongodb connect failed", "err", err)
	}
	defer mongoClient.Disconnect(ctx)
	db := mongoClient.Database(coins.DefaultDBName)

	// Create indexes
	db.Collection("users").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "username", Value: 1}},
		Options: options.Index().SetUnique(true),
	})
	db.Collection("users").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "email", Value: 1}},
		Options: options.Index().SetUnique(true).SetSparse(true),
	})
	log.FromContext(ctx).Info("connected to MongoDB")

	// Redis
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: redisAddr})
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatal(ctx, "redis connect failed", "err", err)
	}
	log.FromContext(ctx).Info("connected to Redis")

	// RabbitMQ (Phase 2: for publishing notification events)
	rabbitURL := os.Getenv("RABBITMQ_URL")
	if rabbitURL == "" {
		rabbitURL = "amqp://guest:guest@localhost:5672/"
	}
	amqpConn, err := amqp.Dial(rabbitURL)
	if err != nil {
		log.Fatal(ctx, "rabbitmq connect failed", "err", err)
	}
	defer amqpConn.Close()
	// Ensure exchange exists (use a temporary channel)
	setupCh, err := amqpConn.Channel()
	if err != nil {
		log.Fatal(ctx, "rabbitmq channel failed", "err", err)
	}
	setupCh.ExchangeDeclare("sx", "topic", true, false, false, false, nil)
	setupCh.Close()
	log.FromContext(ctx).Info("connected to RabbitMQ")

	// JWT + Resend
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "quiz-battle-dev-secret"
	}

	resendKey := os.Getenv("RESEND_API_KEY")
	resendFrom := os.Getenv("RESEND_FROM")
	if resendFrom == "" {
		resendFrom = "Quiz Battle <onboarding@resend.dev>"
	}
	if resendKey == "" {
		log.FromContext(ctx).Warn("RESEND_API_KEY not set; email send will fail. Set DEV_MODE=true to log fallback codes locally")
	}

	srv := &authServer{
		mongoDB:   db,
		ledger:    coins.NewLedger(mongoClient, coins.DefaultDBName),
		rdb:       rdb,
		amqpConn:  amqpConn,
		jwtSecret: jwtSecret,
		mailer:    email.NewSender(resendKey, resendFrom),
	}

	// Phase 2: Start notification cron goroutines
	go srv.streakWarningCron(ctx)
	go srv.dailyRewardNudgeCron(ctx)

	skipMethods := []string{
		"/quiz.AuthService/Register",
		"/quiz.AuthService/Login",
		"/quiz.AuthService/GuestLogin",
		"/quiz.AuthService/SendEmailCode",
		"/quiz.AuthService/VerifyEmailCode",
		"/quiz.AuthService/ResetPassword",
		"/quiz.AuthService/LoginWithEmail",
		"/quiz.AuthService/CheckUsername",
		"/quiz.AuthService/GoogleSignIn",
	}

	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(auth.UnaryInterceptor(jwtSecret, skipMethods)),
		grpc.StreamInterceptor(auth.StreamInterceptor(jwtSecret, nil)),
	)
	pb.RegisterAuthServiceServer(grpcServer, srv)

	lis, err := net.Listen("tcp", ":50054")
	if err != nil {
		log.Fatal(ctx, "listen failed", "addr", ":50054", "err", err)
	}

	log.FromContext(ctx).Info("gRPC serving", "addr", ":50054")
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatal(ctx, "grpc serve failed", "err", err)
	}
}
