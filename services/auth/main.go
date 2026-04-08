package main

import (
	"context"
	"crypto/rand"
	"fmt"
	"log"
	"net"
	"os"
	"regexp"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"golang.org/x/crypto/bcrypt"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/email"
	"quiz-battle/pkg/keys"
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
	rdb       *redis.Client
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
	user := models.User{
		ID:            userID,
		Username:      req.Username,
		PasswordHash:  string(hash),
		Email:         req.Email,
		IsGuest:       false,
		Rating:        1200,
		MatchesPlayed: 0,
		Wins:          0,
		CreatedAt:     time.Now().Unix(),
	}
	if _, err := s.users().InsertOne(ctx, user); err != nil {
		return nil, status.Errorf(codes.Internal, "insert error: %v", err)
	}

	token, err := auth.GenerateToken(userID, req.Username, s.jwtSecret)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "token error: %v", err)
	}

	log.Printf("[auth] registered user %s (%s)", req.Username, userID)
	return &pb.AuthResponse{
		UserId: userID, Username: req.Username, Token: token,
		Rating: 1200, MatchesPlayed: 0, Wins: 0, Email: req.Email, IsGuest: false,
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

	log.Printf("[auth] login user %s (%s)", user.Username, user.ID)
	return &pb.AuthResponse{
		UserId: user.ID, Username: user.Username, Token: token,
		Rating: user.Rating, MatchesPlayed: user.MatchesPlayed, Wins: user.Wins,
		Email: user.Email, IsGuest: user.IsGuest,
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
	}, nil
}

// ---------------------------------------------------------------------------
// GuestLogin — instant play, no credentials
// ---------------------------------------------------------------------------

func (s *authServer) GuestLogin(ctx context.Context, _ *pb.GuestLoginRequest) (*pb.AuthResponse, error) {
	userID := uuid.New().String()
	shortID := userID[:8]
	username := "Guest_" + shortID

	user := models.User{
		ID:        userID,
		Username:  username,
		IsGuest:   true,
		Rating:    1200,
		CreatedAt: time.Now().Unix(),
	}
	if _, err := s.users().InsertOne(ctx, user); err != nil {
		return nil, status.Errorf(codes.Internal, "insert error: %v", err)
	}

	token, err := auth.GenerateToken(userID, username, s.jwtSecret)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "token error: %v", err)
	}

	log.Printf("[auth] guest login %s (%s)", username, userID)
	return &pb.AuthResponse{
		UserId: userID, Username: username, Token: token,
		Rating: 1200, IsGuest: true,
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
		log.Printf("[auth] email send failed: %v", err)
		// Log code to stdout as fallback for dev
		log.Printf("[auth] DEV FALLBACK — code for %s (%s): %s", req.Email, purpose, code)
	} else {
		log.Printf("[auth] sent %s code to %s", purpose, req.Email)
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
				log.Printf("[auth] email login verified for %s", req.Email)
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

	log.Printf("[auth] linked email %s to user %s", req.Email, userID)
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

	log.Printf("[auth] password reset for %s", req.Email)
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

	log.Printf("[auth] deleted account %s", userID)
	return &pb.DeleteAccountResponse{Deleted: true}, nil
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
// Main
// ---------------------------------------------------------------------------

func main() {
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
		log.Fatalf("mongodb connect failed: %v", err)
	}
	defer mongoClient.Disconnect(ctx)
	db := mongoClient.Database("quizbattle")

	// Create indexes
	db.Collection("users").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "username", Value: 1}},
		Options: options.Index().SetUnique(true),
	})
	db.Collection("users").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "email", Value: 1}},
		Options: options.Index().SetUnique(true).SetSparse(true),
	})
	log.Println("[auth] connected to MongoDB")

	// Redis
	redisAddr := os.Getenv("REDIS_ADDR")
	if redisAddr == "" {
		redisAddr = "localhost:6379"
	}
	rdb := redis.NewClient(&redis.Options{Addr: redisAddr})
	if err := rdb.Ping(ctx).Err(); err != nil {
		log.Fatalf("redis connect failed: %v", err)
	}
	log.Println("[auth] connected to Redis")

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
		log.Println("[auth] WARNING: RESEND_API_KEY not set — email codes will only be logged to stdout")
	}

	srv := &authServer{
		mongoDB:   db,
		rdb:       rdb,
		jwtSecret: jwtSecret,
		mailer:    email.NewSender(resendKey, resendFrom),
	}

	skipMethods := []string{
		"/quiz.AuthService/Register",
		"/quiz.AuthService/Login",
		"/quiz.AuthService/GuestLogin",
		"/quiz.AuthService/SendEmailCode",
		"/quiz.AuthService/VerifyEmailCode",
		"/quiz.AuthService/ResetPassword",
		"/quiz.AuthService/LoginWithEmail",
		"/quiz.AuthService/CheckUsername",
	}

	_ = strings.Join(nil, "") // ensure strings import used

	grpcServer := grpc.NewServer(
		grpc.UnaryInterceptor(auth.UnaryInterceptor(jwtSecret, skipMethods)),
		grpc.StreamInterceptor(auth.StreamInterceptor(jwtSecret, nil)),
	)
	pb.RegisterAuthServiceServer(grpcServer, srv)

	lis, err := net.Listen("tcp", ":50054")
	if err != nil {
		log.Fatalf("failed to listen: %v", err)
	}

	log.Println("[auth] serving on :50054")
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("failed to serve: %v", err)
	}
}
