package auth

import (
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"
)

// TokenTTL is the lifetime of a JWT token.
const TokenTTL = 24 * time.Hour

// Claims holds the authenticated user identity extracted from a JWT.
type Claims struct {
	UserID   string `json:"sub"`
	Username string `json:"username"`
	Exp      int64  `json:"exp"`
}

type contextKey string

const (
	ctxUserID   contextKey = "auth_user_id"
	ctxUsername  contextKey = "auth_username"
)

// UserIDFromContext extracts the authenticated user ID from the context.
func UserIDFromContext(ctx context.Context) (string, error) {
	v, ok := ctx.Value(ctxUserID).(string)
	if !ok || v == "" {
		return "", errors.New("no authenticated user in context")
	}
	return v, nil
}

// UsernameFromContext extracts the authenticated username from the context.
func UsernameFromContext(ctx context.Context) (string, error) {
	v, ok := ctx.Value(ctxUsername).(string)
	if !ok || v == "" {
		return "", errors.New("no username in context")
	}
	return v, nil
}

// ContextWithClaims injects claims into the context.
func ContextWithClaims(ctx context.Context, claims *Claims) context.Context {
	ctx = context.WithValue(ctx, ctxUserID, claims.UserID)
	ctx = context.WithValue(ctx, ctxUsername, claims.Username)
	return ctx
}

// GenerateToken creates an HS256-signed JWT with 24h expiry.
func GenerateToken(userID, username, secret string) (string, error) {
	header := base64Encode([]byte(`{"alg":"HS256","typ":"JWT"}`))

	claims := Claims{
		UserID:   userID,
		Username: username,
		Exp:      time.Now().Add(TokenTTL).Unix(),
	}
	payload, err := json.Marshal(claims)
	if err != nil {
		return "", fmt.Errorf("marshal claims: %w", err)
	}
	encodedPayload := base64Encode(payload)

	signingInput := header + "." + encodedPayload
	signature := sign(signingInput, secret)

	return signingInput + "." + signature, nil
}

// VerifyToken validates an HS256 JWT and returns the claims.
func VerifyToken(tokenStr, secret string) (*Claims, error) {
	parts := strings.SplitN(tokenStr, ".", 3)
	if len(parts) != 3 {
		return nil, errors.New("malformed token")
	}

	signingInput := parts[0] + "." + parts[1]
	expectedSig := sign(signingInput, secret)
	if !hmac.Equal([]byte(parts[2]), []byte(expectedSig)) {
		return nil, errors.New("invalid signature")
	}

	payload, err := base64Decode(parts[1])
	if err != nil {
		return nil, fmt.Errorf("decode payload: %w", err)
	}

	var claims Claims
	if err := json.Unmarshal(payload, &claims); err != nil {
		return nil, fmt.Errorf("unmarshal claims: %w", err)
	}

	if time.Now().Unix() > claims.Exp {
		return nil, errors.New("token expired")
	}

	return &claims, nil
}

func sign(input, secret string) string {
	mac := hmac.New(sha256.New, []byte(secret))
	mac.Write([]byte(input))
	return base64Encode(mac.Sum(nil))
}

func base64Encode(data []byte) string {
	return base64.RawURLEncoding.EncodeToString(data)
}

func base64Decode(s string) ([]byte, error) {
	return base64.RawURLEncoding.DecodeString(s)
}
