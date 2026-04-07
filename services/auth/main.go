package main

import (
	"context"
	"log"
	"net"
	"os"
	"regexp"
	"time"

	"github.com/google/uuid"
	"go.mongodb.org/mongo-driver/v2/bson"
	"go.mongodb.org/mongo-driver/v2/mongo"
	"go.mongodb.org/mongo-driver/v2/mongo/options"
	"golang.org/x/crypto/bcrypt"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"

	"quiz-battle/pkg/auth"
	"quiz-battle/pkg/models"
	pb "quiz-battle/proto"
)

var usernameRegex = regexp.MustCompile(`^[a-zA-Z0-9_]{3,20}$`)

type authServer struct {
	pb.UnimplementedAuthServiceServer
	mongoDB   *mongo.Database
	jwtSecret string
}

// ---------------------------------------------------------------------------
// Register
// ---------------------------------------------------------------------------

func (s *authServer) Register(ctx context.Context, req *pb.RegisterRequest) (*pb.AuthResponse, error) {
	username := req.Username
	password := req.Password

	// Validate input
	if !usernameRegex.MatchString(username) {
		return nil, status.Error(codes.InvalidArgument, "username must be 3-20 alphanumeric or underscore characters")
	}
	if len(password) < 6 {
		return nil, status.Error(codes.InvalidArgument, "password must be at least 6 characters")
	}

	// Check uniqueness
	coll := s.mongoDB.Collection("users")
	var existing bson.M
	err := coll.FindOne(ctx, bson.M{"username": username}).Decode(&existing)
	if err == nil {
		return nil, status.Error(codes.AlreadyExists, "username already taken")
	}
	if err != mongo.ErrNoDocuments {
		return nil, status.Errorf(codes.Internal, "db error: %v", err)
	}

	// Hash password
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcrypt.DefaultCost)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "hash error: %v", err)
	}

	// Insert user
	userID := uuid.New().String()
	user := models.User{
		ID:            userID,
		Username:      username,
		PasswordHash:  string(hash),
		Rating:        1200,
		MatchesPlayed: 0,
		Wins:          0,
		CreatedAt:     time.Now().Unix(),
	}
	if _, err := coll.InsertOne(ctx, user); err != nil {
		return nil, status.Errorf(codes.Internal, "insert error: %v", err)
	}

	// Generate JWT
	token, err := auth.GenerateToken(userID, username, s.jwtSecret)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "token error: %v", err)
	}

	log.Printf("[auth] registered user %s (%s)", username, userID)

	return &pb.AuthResponse{
		UserId:        userID,
		Username:      username,
		Token:         token,
		Rating:        1200,
		MatchesPlayed: 0,
		Wins:          0,
	}, nil
}

// ---------------------------------------------------------------------------
// Login
// ---------------------------------------------------------------------------

func (s *authServer) Login(ctx context.Context, req *pb.LoginRequest) (*pb.AuthResponse, error) {
	username := req.Username
	password := req.Password

	if username == "" || password == "" {
		return nil, status.Error(codes.InvalidArgument, "username and password required")
	}

	// Lookup user
	coll := s.mongoDB.Collection("users")
	var user models.User
	err := coll.FindOne(ctx, bson.M{"username": username}).Decode(&user)
	if err == mongo.ErrNoDocuments {
		return nil, status.Error(codes.NotFound, "invalid username or password")
	}
	if err != nil {
		return nil, status.Errorf(codes.Internal, "db error: %v", err)
	}

	// Verify password
	if err := bcrypt.CompareHashAndPassword([]byte(user.PasswordHash), []byte(password)); err != nil {
		return nil, status.Error(codes.NotFound, "invalid username or password")
	}

	// Generate JWT
	token, err := auth.GenerateToken(user.ID, user.Username, s.jwtSecret)
	if err != nil {
		return nil, status.Errorf(codes.Internal, "token error: %v", err)
	}

	log.Printf("[auth] login user %s (%s)", user.Username, user.ID)

	return &pb.AuthResponse{
		UserId:        user.ID,
		Username:      user.Username,
		Token:         token,
		Rating:        user.Rating,
		MatchesPlayed: user.MatchesPlayed,
		Wins:          user.Wins,
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
	err = s.mongoDB.Collection("users").FindOne(ctx, bson.M{"_id": userID}).Decode(&user)
	if err == mongo.ErrNoDocuments {
		return nil, status.Error(codes.NotFound, "user not found")
	}
	if err != nil {
		return nil, status.Errorf(codes.Internal, "db error: %v", err)
	}

	return &pb.ProfileResponse{
		UserId:        user.ID,
		Username:      user.Username,
		Rating:        user.Rating,
		MatchesPlayed: user.MatchesPlayed,
		Wins:          user.Wins,
	}, nil
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

	// Create unique index on username
	_, err = db.Collection("users").Indexes().CreateOne(ctx, mongo.IndexModel{
		Keys:    bson.D{{Key: "username", Value: 1}},
		Options: options.Index().SetUnique(true),
	})
	if err != nil {
		log.Printf("[auth] username index may already exist: %v", err)
	}

	log.Println("[auth] connected to MongoDB")

	// JWT secret
	jwtSecret := os.Getenv("JWT_SECRET")
	if jwtSecret == "" {
		jwtSecret = "quiz-battle-dev-secret"
	}

	srv := &authServer{
		mongoDB:   db,
		jwtSecret: jwtSecret,
	}

	// gRPC server with auth interceptors (skip Register + Login)
	skipMethods := []string{
		"/quiz.AuthService/Register",
		"/quiz.AuthService/Login",
	}
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
