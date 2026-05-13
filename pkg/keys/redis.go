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

// RemoveFromPool removes a player from the matchmaking pool. Returns the
// number of members actually removed (0 or 1). Callers rely on this count to
// tell "we took the user out of the queue" (1) apart from "the poller had
// already matched them out before our ZRem reached Redis" (0) — that
// distinction drives the daily-quota refund in LeaveMatchmaking.
func RemoveFromPool(ctx context.Context, rdb *redis.Client, userID string) (int64, error) {
	return rdb.ZRem(ctx, MatchmakingPool, userID).Result()
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

// IsPlayerInRoom reports whether userID is registered in roomID's player
// hash. Callers use this to gate room-scoped RPCs (StreamGameEvents,
// SubmitAnswer, GetRoomQuestions) so outsiders can't act on rooms they
// were never added to. Returns (false, nil) when the user is absent;
// any non-nil error should be treated as deny-by-default by the caller.
func IsPlayerInRoom(ctx context.Context, rdb *redis.Client, roomID, userID string) (bool, error) {
	return rdb.HExists(ctx, Players(roomID), userID).Result()
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

// TrySetAnswer atomically records a player's answer using HSETNX.
// Returns true if the answer was set (first submission), false if it already existed (duplicate).
func TrySetAnswer(ctx context.Context, rdb *redis.Client, roomID string, round int, userID, answerJSON string) (bool, error) {
	key := Answers(roomID, round)
	set, err := rdb.HSetNX(ctx, key, userID, answerJSON).Result()
	if err != nil {
		return false, err
	}
	if set {
		rdb.Expire(ctx, key, RoomTTL)
	}
	return set, nil
}

// --- Recency bonus counters ---

// BumpStreak increments the per-user consecutive-correct counter for a
// match and returns the post-INCR value (1 on the first correct answer,
// 2 on the second, …). The caller maps the returned level to a bonus.
// Refreshes TTL so the counter survives a long match.
func BumpStreak(ctx context.Context, rdb *redis.Client, roomID, userID string) (int64, error) {
	key := Streak(roomID, userID)
	level, err := rdb.Incr(ctx, key).Result()
	if err != nil {
		return 0, err
	}
	rdb.Expire(ctx, key, RoomTTL)
	return level, nil
}

// ResetStreak clears the per-user consecutive-correct counter — called
// when a player answers wrong so the next correct answer starts a
// fresh streak at 1.
func ResetStreak(ctx context.Context, rdb *redis.Client, roomID, userID string) error {
	return rdb.Del(ctx, Streak(roomID, userID)).Err()
}

// IncrCorrectOrder atomically increments the per-round correct-answer
// counter and returns the caller's rank (1 = first correct in the
// round, 2 = second, …). The caller maps the rank to a bonus.
// Called only on a correct answer.
func IncrCorrectOrder(ctx context.Context, rdb *redis.Client, roomID string, round int) (int64, error) {
	key := CorrectOrder(roomID, round)
	rank, err := rdb.Incr(ctx, key).Result()
	if err != nil {
		return 0, err
	}
	rdb.Expire(ctx, key, RoomTTL)
	return rank, nil
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

// RefundQuotaScript decrements the daily quota counter, but only if the
// current value is > 0. The guard prevents a stray refund (e.g. one triggered
// after the IST-midnight EXPIREAT fired and the key was reset) from landing
// on a fresh counter and making it negative. Returns 1 if a refund happened,
// 0 if the counter was already at zero or missing.
var RefundQuotaScript = redis.NewScript(`
local current = redis.call('GET', KEYS[1])
if current and tonumber(current) > 0 then
  redis.call('DECR', KEYS[1])
  return 1
end
return 0
`)

// RefundQuota reverses a previous CheckQuota INCR when the user aborts before
// actually playing (e.g. cancelling out of matchmaking before a match is
// made). Safe to call unconditionally — the Lua guard turns it into a no-op
// for premium users (whose counter is never touched) or after quota reset.
func RefundQuota(ctx context.Context, rdb *redis.Client, userID string) (bool, error) {
	result, err := RefundQuotaScript.Run(ctx, rdb, []string{DailyQuota(userID)}).Int64()
	if err != nil {
		return false, err
	}
	return result == 1, nil
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

// ---------------------------------------------------------------------------
// Notifications: match invite throttle (30-min window per inviter→opponent)
// ---------------------------------------------------------------------------

const MatchInviteThrottleTTL = 30 * time.Minute

// TrySetMatchInviteThrottle returns true if we won the SETNX race — i.e. no
// notif.match.invite has been dispatched from `fromUserID` to `toUserID` in the
// last MatchInviteThrottleTTL. Returns false when the throttle is still active.
func TrySetMatchInviteThrottle(ctx context.Context, rdb *redis.Client, fromUserID, toUserID string) (bool, error) {
	return rdb.SetNX(ctx, MatchInviteThrottle(fromUserID, toUserID), "1", MatchInviteThrottleTTL).Result()
}

// ---------------------------------------------------------------------------
// Phase 3 (4.4): Friend presence + challenge throttle
// ---------------------------------------------------------------------------

// PresenceTTL is the window inside which a user counts as "online". Each
// Heartbeat RPC refreshes the key; readers (GetFriendsList) check the
// key's existence to render the online dot. 60s matches the typical
// mobile foreground keep-alive cadence and survives a single missed
// heartbeat without flicker.
const PresenceTTL = 60 * time.Second

// TouchPresence sets the user's presence key with PresenceTTL, replacing
// any existing TTL. Equivalent to "this user just heartbeat'd."
func TouchPresence(ctx context.Context, rdb *redis.Client, userID string) error {
	return rdb.Set(ctx, Presence(userID), "1", PresenceTTL).Err()
}

// IsOnline returns true when the presence key exists for userID. Used
// from GetFriendsList to render the online dot. EXISTS is single-key
// O(1) on Redis, so the per-friend overhead is negligible — a user
// with 200 friends sees ~200 EXISTS calls per list fetch, well under a
// millisecond on the same Redis pool the rest of the service uses.
func IsOnline(ctx context.Context, rdb *redis.Client, userID string) (bool, error) {
	n, err := rdb.Exists(ctx, Presence(userID)).Result()
	if err != nil {
		return false, err
	}
	return n > 0, nil
}

// AreOnline does an MGET-style batch check across many users so
// GetFriendsList can issue ONE round trip instead of N. Returns a map
// keyed by userID; missing entries default to false (caller can
// freely range over its friend list).
func AreOnline(ctx context.Context, rdb *redis.Client, userIDs []string) (map[string]bool, error) {
	if len(userIDs) == 0 {
		return map[string]bool{}, nil
	}
	keys := make([]string, len(userIDs))
	for i, uid := range userIDs {
		keys[i] = Presence(uid)
	}
	vals, err := rdb.MGet(ctx, keys...).Result()
	if err != nil {
		return nil, err
	}
	out := make(map[string]bool, len(userIDs))
	for i, uid := range userIDs {
		out[uid] = vals[i] != nil
	}
	return out, nil
}

// ChallengeThrottleTTL is short on purpose: the use case is "stop
// spam clicks of the Challenge button," not "limit challenges per
// hour." 30 seconds is enough to debounce double-taps and the
// notification-arrives-late-and-user-clicks-again pattern.
const ChallengeThrottleTTL = 30 * time.Second

// TrySetChallengeThrottle returns true when this is the first
// challenge from fromUserID → toUserID inside the throttle window.
// Returns false if a challenge from this pair was sent recently —
// the caller should surface a friendly "you just challenged them" hint.
func TrySetChallengeThrottle(ctx context.Context, rdb *redis.Client, fromUserID, toUserID string) (bool, error) {
	return rdb.SetNX(ctx, ChallengeThrottle(fromUserID, toUserID), "1", ChallengeThrottleTTL).Result()
}

// §4.6 Notification policy helpers ----------------------------------------

// NotifDailyCapTTL is 48h on purpose — the {YYYY-MM-DD} segment of the
// key handles the actual day rollover; the TTL is a fail-safe so a
// crashed service or clock skew doesn't leave a forever counter behind.
const NotifDailyCapTTL = 48 * time.Hour

// NotifDedupTTL is the suppression window for repeat pushes of the same
// category. 1 hour matches the problem-03 example: "don't send 3 streak
// warnings in an hour."
const NotifDedupTTL = 1 * time.Hour

// NotifMetricTTL keeps per-day counters around long enough to look at
// "yesterday" without keeping a forever metric set. Operators wanting
// long-term trends should aggregate to a real metrics store.
const NotifMetricTTL = 7 * 24 * time.Hour

// IncrNotifDailyCap atomically increments the per-user daily push
// counter and returns the new value. The TTL is set only on the
// first increment of the day via ExpireNX (Redis 7.0+) — subsequent
// hits don't reset the 48h fail-safe. Day rollover itself is handled
// by the {YYYY-MM-DD} segment of the key, not the TTL.
func IncrNotifDailyCap(ctx context.Context, rdb *redis.Client, userID, day string) (int64, error) {
	pipe := rdb.TxPipeline()
	incr := pipe.Incr(ctx, NotifDailyCap(userID, day))
	pipe.ExpireNX(ctx, NotifDailyCap(userID, day), NotifDailyCapTTL)
	if _, err := pipe.Exec(ctx); err != nil {
		return 0, err
	}
	return incr.Val(), nil
}

// TrySetNotifOpenedDedup gates the global "opened" counter to one
// increment per (user, category, day). Returns true on the first call
// in the window; false on subsequent calls so the caller knows to
// skip the metric increment.
func TrySetNotifOpenedDedup(ctx context.Context, rdb *redis.Client, userID, category, day string) (bool, error) {
	// 25h TTL gives a one-hour cushion past midnight UTC so a tap that
	// arrives right at the day boundary doesn't double-count.
	const ttl = 25 * time.Hour
	return rdb.SetNX(ctx, NotifOpenedDedup(userID, category, day), "1", ttl).Result()
}

// DecrNotifDailyCap rolls back a counted push when the policy decides
// to drop it AFTER the cap was incremented. Today this isn't called —
// the cap is the LAST gate so a counted push is always sent — but the
// helper exists so a future reorder can compensate without bespoke code.
func DecrNotifDailyCap(ctx context.Context, rdb *redis.Client, userID, day string) error {
	return rdb.Decr(ctx, NotifDailyCap(userID, day)).Err()
}

// TrySetNotifDedup returns true when this is the first push of the
// category in the dedup window. False means "we just sent one, suppress."
// Idempotent retries within the window stay suppressed — the SETNX
// race is resolved by Redis.
func TrySetNotifDedup(ctx context.Context, rdb *redis.Client, userID, category string) (bool, error) {
	return rdb.SetNX(ctx, NotifDedup(userID, category), "1", NotifDedupTTL).Result()
}

// IncrNotifMetricSent / Opened / Dropped are the three counters the
// policy gate writes for offline analysis. Failures are non-fatal —
// metrics are best-effort and the caller should log + continue.
func IncrNotifMetricSent(ctx context.Context, rdb *redis.Client, category, day string) error {
	return incrWithTTL(ctx, rdb, NotifMetricSent(category, day))
}
func IncrNotifMetricOpened(ctx context.Context, rdb *redis.Client, category, day string) error {
	return incrWithTTL(ctx, rdb, NotifMetricOpened(category, day))
}
func IncrNotifMetricDropped(ctx context.Context, rdb *redis.Client, category, reason, day string) error {
	return incrWithTTL(ctx, rdb, NotifMetricDropped(category, reason, day))
}

func incrWithTTL(ctx context.Context, rdb *redis.Client, key string) error {
	pipe := rdb.TxPipeline()
	pipe.Incr(ctx, key)
	pipe.Expire(ctx, key, NotifMetricTTL)
	_, err := pipe.Exec(ctx)
	return err
}
