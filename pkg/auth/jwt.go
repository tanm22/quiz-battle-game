package auth

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// AccessTokenTTL bounds how long a JWT stays valid before a refresh
// round-trip is required. Short on purpose so revocation (logout,
// password change, account delete) takes effect within minutes
// without needing a per-request blacklist lookup on every RPC.
const AccessTokenTTL = 15 * time.Minute

// RefreshTokenTTL bounds the session length before a user has to
// re-authenticate from scratch. Long enough that mobile users on
// stable devices don't see frequent forced logins.
const RefreshTokenTTL = 30 * 24 * time.Hour

// TokenTTL is retained as an alias of AccessTokenTTL for any external
// callers that imported it before the refresh-token migration. Remove
// after one release cycle.
const TokenTTL = AccessTokenTTL

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

// GenerateAccessToken creates an HS256-signed JWT carrying the user
// identity and a fresh JTI. The JTI is returned alongside so the
// caller (handler) can persist it for revocation checks if desired.
func GenerateAccessToken(userID, username, secret string) (token, jti string, err error) {
	jti, err = randomHex(16)
	if err != nil {
		return "", "", err
	}
	claims := Claims{
		UserID:   userID,
		Username: username,
		RegisteredClaims: jwt.RegisteredClaims{
			Subject:   userID,
			ID:        jti,
			ExpiresAt: jwt.NewNumericDate(time.Now().Add(AccessTokenTTL)),
			IssuedAt:  jwt.NewNumericDate(time.Now()),
		},
	}
	t := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := t.SignedString([]byte(secret))
	return signed, jti, err
}

// GenerateToken is retained as a compatibility wrapper. New callers
// should use GenerateAccessToken to receive the JTI.
func GenerateToken(userID, username, secret string) (string, error) {
	t, _, err := GenerateAccessToken(userID, username, secret)
	return t, err
}

// GenerateRefreshTokenID returns a 32-byte hex string suitable as the
// _id of a refresh-token Mongo document. The persisted ID, not the
// JWT, is what the client returns at refresh time.
func GenerateRefreshTokenID() (string, error) {
	return randomHex(32)
}

func randomHex(nBytes int) (string, error) {
	b := make([]byte, nBytes)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
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
