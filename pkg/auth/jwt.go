package auth

import (
	"context"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// TokenTTL is the lifetime of a JWT token.
const TokenTTL = 24 * time.Hour

// Claims holds the authenticated user identity extracted from a JWT.
type Claims struct {
	UserID   string `json:"sub"`
	Username string `json:"username"`
	jwt.RegisteredClaims
}

type contextKey string

const (
	ctxUserID   contextKey = "auth_user_id"
	ctxUsername contextKey = "auth_username"
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
	claims := Claims{
		UserID:   userID,
		Username: username,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(TokenTTL)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	return token.SignedString([]byte(secret))
}

// VerifyToken validates an HS256 JWT and returns the claims.
func VerifyToken(tokenStr, secret string) (*Claims, error) {
	token, err := jwt.ParseWithClaims(tokenStr, &Claims{}, func(t *jwt.Token) (interface{}, error) {
		if _, ok := t.Method.(*jwt.SigningMethodHMAC); !ok {
			return nil, errors.New("unexpected signing method")
		}
		return []byte(secret), nil
	})
	if err != nil {
		return nil, err
	}

	claims, ok := token.Claims.(*Claims)
	if !ok || !token.Valid {
		return nil, errors.New("invalid token")
	}

	return claims, nil
}
