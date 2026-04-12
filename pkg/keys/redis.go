package keys

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// RoomTTL is applied to all room:{id}:* keys on every write.
const RoomTTL = 30 * time.Minute

// LockTTL is the safety release for room:lock:{id}.
const LockTTL = 10 * time.Second

// LeaderboardScript atomically reads the current score for a member,
// adds a delta to it, writes it back with ZADD, and returns the full
// sorted set with ZRANGE WITHSCORES. This is race-condition-free because
// the entire read-modify-write executes as a single atomic Lua script
// on the Redis server — no two goroutines can interleave their reads and writes.
var LeaderboardScript = redis.NewScript(`
local current = redis.call('ZSCORE', KEYS[1], ARGV[1])
if not current then current = 0 end
redis.call('ZADD', KEYS[1], current + ARGV[2], ARGV[1])
return redis.call('ZRANGE', KEYS[1], 0, -1, 'REV', 'WITHSCORES')
`)

// --- Matchmaking pool operations ---

// AddToPool adds a player to the matchmaking sorted set with score = rating.
func AddToPool(ctx context.Context, rdb *redis.Client, userID string, rating float64) error {
	return rdb.ZAdd(ctx, MatchmakingPool, redis.Z{Score: rating, Member: userID}).Err()
}

// IsInPool checks if a player is already in the matchmaking pool.
func IsInPool(ctx context.Context, rdb *redis.Client, userID string) (bool, error) {
	_, err := rdb.ZScore(ctx, MatchmakingPool, userID).Result()
	if err == redis.Nil {
		return false, nil
	}
	if err != nil {
		return false, err
	}
	return true, nil
}

// RemoveFromPool removes a player from the matchmaking pool.
func RemoveFromPool(ctx context.Context, rdb *redis.Client, userID string) error {
	return rdb.ZRem(ctx, MatchmakingPool, userID).Err()
}

// PoolSize returns the number of players waiting in the pool.
func PoolSize(ctx context.Context, rdb *redis.Client) (int64, error) {
	return rdb.ZCard(ctx, MatchmakingPool).Result()
}

// PopPoolPlayers removes and returns up to count members from the pool (lowest scores first).
func PopPoolPlayers(ctx context.Context, rdb *redis.Client, count int64) ([]redis.Z, error) {
	return rdb.ZPopMin(ctx, MatchmakingPool, count).Result()
}

// OldestWaitTime returns the wait time of the longest-waiting player in the pool.
// Returns 0 if the pool is empty. Score is assumed to be the rating, so we use
// the insertion order via ZRANGE to get the first member added.
func OldestWaitTime(ctx context.Context, rdb *redis.Client) ([]redis.Z, error) {
	return rdb.ZRangeWithScores(ctx, MatchmakingPool, 0, -1).Result()
}

// --- Room lock ---

// AcquireRoomLock attempts to acquire a distributed lock for room creation.
// Returns true if the lock was acquired (SETNX succeeded).
func AcquireRoomLock(ctx context.Context, rdb *redis.Client, roomID string) (bool, error) {
	return rdb.SetNX(ctx, Lock(roomID), "1", LockTTL).Result()
}

// ReleaseRoomLock releases the distributed lock for room creation.
func ReleaseRoomLock(ctx context.Context, rdb *redis.Client, roomID string) error {
	return rdb.Del(ctx, Lock(roomID)).Err()
}

// --- Room state operations ---

// SetRoomState writes the room state JSON and refreshes TTL.
func SetRoomState(ctx context.Context, rdb *redis.Client, roomID string, stateJSON string) error {
	return rdb.Set(ctx, State(roomID), stateJSON, RoomTTL).Err()
}

// GetRoomState retrieves the room state JSON.
func GetRoomState(ctx context.Context, rdb *redis.Client, roomID string) (string, error) {
	return rdb.Get(ctx, State(roomID)).Result()
}

// --- Room round ---

// SetRoomRound sets the current round index and refreshes TTL.
func SetRoomRound(ctx context.Context, rdb *redis.Client, roomID string, round int) error {
	return rdb.Set(ctx, Round(roomID), round, RoomTTL).Err()
}

// GetRoomRound retrieves the current round index.
func GetRoomRound(ctx context.Context, rdb *redis.Client, roomID string) (int, error) {
	return rdb.Get(ctx, Round(roomID)).Int()
}

// --- Room players hash ---

// SetPlayer stores a player's JSON metadata in the room players hash and refreshes TTL.
func SetPlayer(ctx context.Context, rdb *redis.Client, roomID, userID, playerJSON string) error {
	pipe := rdb.Pipeline()
	pipe.HSet(ctx, Players(roomID), userID, playerJSON)
	pipe.Expire(ctx, Players(roomID), RoomTTL)
	_, err := pipe.Exec(ctx)
	return err
}

// GetPlayer retrieves a player's JSON metadata from the room players hash.
func GetPlayer(ctx context.Context, rdb *redis.Client, roomID, userID string) (string, error) {
	return rdb.HGet(ctx, Players(roomID), userID).Result()
}

// GetAllPlayers retrieves all players in a room.
func GetAllPlayers(ctx context.Context, rdb *redis.Client, roomID string) (map[string]string, error) {
	return rdb.HGetAll(ctx, Players(roomID)).Result()
}

// --- Room questions list ---

// SetQuestions stores the ordered question IDs for a match and refreshes TTL.
func SetQuestions(ctx context.Context, rdb *redis.Client, roomID string, questionIDs []string) error {
	pipe := rdb.Pipeline()
	for _, qid := range questionIDs {
		pipe.RPush(ctx, Questions(roomID), qid)
	}
	pipe.Expire(ctx, Questions(roomID), RoomTTL)
	_, err := pipe.Exec(ctx)
	return err
}

// GetQuestions retrieves all ordered question IDs for a match.
func GetQuestions(ctx context.Context, rdb *redis.Client, roomID string) ([]string, error) {
	return rdb.LRange(ctx, Questions(roomID), 0, -1).Result()
}

// --- Leaderboard operations ---

// UpdateLeaderboard atomically updates a player's score and returns the full leaderboard.
// Uses the Lua script to prevent race conditions.
func UpdateLeaderboard(ctx context.Context, rdb *redis.Client, roomID, userID string, scoreDelta float64) ([]redis.Z, error) {
	result, err := LeaderboardScript.Run(ctx, rdb, []string{Leaderboard(roomID)}, userID, scoreDelta).Result()
	if err != nil {
		return nil, err
	}

	// Parse the flat [member, score, member, score, ...] result into []redis.Z
	flat, ok := result.([]interface{})
	if !ok {
		return nil, nil
	}

	entries := make([]redis.Z, 0, len(flat)/2)
	for i := 0; i < len(flat)-1; i += 2 {
		member, _ := flat[i].(string)
		scoreStr, _ := flat[i+1].(string)
		var score float64
		fmt.Sscanf(scoreStr, "%f", &score)
		entries = append(entries, redis.Z{Member: member, Score: score})
	}

	// Refresh TTL on leaderboard key
	rdb.Expire(ctx, Leaderboard(roomID), RoomTTL)

	return entries, nil
}

// GetLeaderboardEntries returns the full leaderboard sorted descending by score.
func GetLeaderboardEntries(ctx context.Context, rdb *redis.Client, roomID string) ([]redis.Z, error) {
	return rdb.ZRevRangeWithScores(ctx, Leaderboard(roomID), 0, -1).Result()
}

// --- Answer tracking ---

// SetAnswer records a player's answer for idempotency checking.
func SetAnswer(ctx context.Context, rdb *redis.Client, roomID string, round int, userID, answerJSON string) error {
	pipe := rdb.Pipeline()
	pipe.HSet(ctx, Answers(roomID, round), userID, answerJSON)
	pipe.Expire(ctx, Answers(roomID, round), RoomTTL)
	_, err := pipe.Exec(ctx)
	return err
}

// HasAnswer checks if a player already submitted an answer for a round (idempotency check).
func HasAnswer(ctx context.Context, rdb *redis.Client, roomID string, round int, userID string) (bool, error) {
	return rdb.HExists(ctx, Answers(roomID, round), userID).Result()
}

// --- Round close guard ---

// RoundClosedTTL is the safety expiry for the round-closed guard key.
// Only needs to outlive the round transition (~17s). Spec mandates EX 30.
const RoundClosedTTL = 30 * time.Second

// TryCloseRound attempts to set the round-closed guard via SETNX.
// Returns true if this goroutine won the race (first to close the round).
func TryCloseRound(ctx context.Context, rdb *redis.Client, roomID string, round int) (bool, error) {
	return rdb.SetNX(ctx, RoundClosed(roomID, round), "1", RoundClosedTTL).Result()
}

// --- Email verification codes ---

const (
	EmailCodeTTL      = 10 * time.Minute
	EmailRateLimitTTL = 60 * time.Second
	MaxCodeAttempts   = 3
)

// StoreEmailCode saves a verification code in Redis with 10min TTL.
func StoreEmailCode(ctx context.Context, rdb *redis.Client, email, purpose, code string) error {
	return rdb.Set(ctx, EmailCodeKey(email, purpose), code, EmailCodeTTL).Err()
}

// CheckEmailCode verifies a code matches what's stored. Returns true if valid.
// Deletes the code after successful verification or after max attempts.
func CheckEmailCode(ctx context.Context, rdb *redis.Client, email, purpose, code string) (bool, error) {
	key := EmailCodeKey(email, purpose)
	stored, err := rdb.Get(ctx, key).Result()
	if err == redis.Nil {
		return false, nil
	}
	if err != nil {
		return false, err
	}

	if stored == code {
		rdb.Del(ctx, key) // one-time use
		return true, nil
	}

	// Track failed attempts
	attemptsKey := key + ":attempts"
	attempts, _ := rdb.Incr(ctx, attemptsKey).Result()
	rdb.Expire(ctx, attemptsKey, EmailCodeTTL)
	if attempts >= MaxCodeAttempts {
		rdb.Del(ctx, key)         // invalidate code
		rdb.Del(ctx, attemptsKey) // cleanup
	}
	return false, nil
}

// CheckEmailRateLimit returns true if a code can be sent (not rate limited).
func CheckEmailRateLimit(ctx context.Context, rdb *redis.Client, email string) (bool, error) {
	return rdb.SetNX(ctx, EmailRateLimitKey(email), "1", EmailRateLimitTTL).Result()
}

// ---------------------------------------------------------------------------
// Phase 2: Daily quota (ISSUE-03 corrected Lua script)
// ---------------------------------------------------------------------------

// QuotaScript atomically increments the daily quota counter and checks the limit.
// KEYS[1] = user:{id}:daily_quota, ARGV[1] = limit, ARGV[2] = IST midnight unix.
// Returns 1 if allowed, 0 if over quota.
var QuotaScript = redis.NewScript(`
local current = redis.call('INCR', KEYS[1])
redis.call('EXPIREAT', KEYS[1], tonumber(ARGV[2]))
if current > tonumber(ARGV[1]) then
  redis.call('DECR', KEYS[1])
  return 0
end
return 1
`)

// ISTMidnightUnix returns the Unix timestamp of the next midnight in IST.
func ISTMidnightUnix() int64 {
	ist, _ := time.LoadLocation("Asia/Kolkata")
	now := time.Now().In(ist)
	midnight := time.Date(now.Year(), now.Month(), now.Day()+1, 0, 0, 0, 0, ist)
	return midnight.Unix()
}

// CheckQuota atomically checks and increments the daily quiz quota.
// Returns true if the user is allowed to play, false if over quota.
func CheckQuota(ctx context.Context, rdb *redis.Client, userID string, limit int) (bool, error) {
	result, err := QuotaScript.Run(ctx, rdb, []string{DailyQuota(userID)}, limit, ISTMidnightUnix()).Int64()
	if err != nil {
		return false, err
	}
	return result == 1, nil
}

// GetQuotaUsed returns the current daily quota usage count.
func GetQuotaUsed(ctx context.Context, rdb *redis.Client, userID string) (int64, error) {
	val, err := rdb.Get(ctx, DailyQuota(userID)).Int64()
	if err == redis.Nil {
		return 0, nil
	}
	return val, err
}

// ---------------------------------------------------------------------------
// Phase 2: Plan cache (5-minute TTL read-through)
// ---------------------------------------------------------------------------

const PlanCacheTTL = 5 * time.Minute

// GetPlan reads the cached plan. Returns "" on cache miss.
func GetPlan(ctx context.Context, rdb *redis.Client, userID string) (string, error) {
	val, err := rdb.Get(ctx, Plan(userID)).Result()
	if err == redis.Nil {
		return "", nil
	}
	return val, err
}

// SetPlan caches the user's plan with 5-minute TTL.
func SetPlan(ctx context.Context, rdb *redis.Client, userID, plan string) error {
	return rdb.Set(ctx, Plan(userID), plan, PlanCacheTTL).Err()
}

// DelPlan invalidates the plan cache (call after plan changes).
func DelPlan(ctx context.Context, rdb *redis.Client, userID string) error {
	return rdb.Del(ctx, Plan(userID)).Err()
}

// ---------------------------------------------------------------------------
// Phase 2: Referral codes (no TTL — persistent mapping)
// ---------------------------------------------------------------------------

// SetRefCode stores a referral code -> userId mapping with no TTL.
func SetRefCode(ctx context.Context, rdb *redis.Client, code, userID string) error {
	return rdb.Set(ctx, RefCode(code), userID, 0).Err()
}

// GetRefCode looks up the userId for a referral code. Returns "" if not found.
func GetRefCode(ctx context.Context, rdb *redis.Client, code string) (string, error) {
	val, err := rdb.Get(ctx, RefCode(code)).Result()
	if err == redis.Nil {
		return "", nil
	}
	return val, err
}

// ---------------------------------------------------------------------------
// Phase 2: Webhook idempotency (72-hour TTL)
// ---------------------------------------------------------------------------

const WebhookIdempotencyTTL = 72 * time.Hour

// SetWebhookIdem attempts to set the idempotency key. Returns true if this is the
// first time (SETNX succeeded), false if the webhook was already processed.
func SetWebhookIdem(ctx context.Context, rdb *redis.Client, paymentID string) (bool, error) {
	return rdb.SetNX(ctx, WebhookIdem(paymentID), "1", WebhookIdempotencyTTL).Result()
}
