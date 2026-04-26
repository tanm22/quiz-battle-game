package keys

import "fmt"

// Redis key constants — single source of truth imported by all three services.
// Any key name typo across services will cause silent failures that are very hard to debug.
const (
	MatchmakingPool = "matchmaking:pool"
	RoomPlayers     = "room:%s:players"
	RoomState       = "room:%s:state"
	RoomRound       = "room:%s:round"
	RoomQuestions   = "room:%s:questions"
	RoomLeaderboard = "room:%s:leaderboard"
	RoomAnswers     = "room:%s:answers:%d"
	RoomLock        = "room:lock:%s"
	RoomRoundClosed = "room:%s:round:%d:closed"
	EmailCode       = "emailcode:%s:%s" // email, purpose
	EmailRateLimit  = "emailrate:%s"    // email
	// Phase 2
	UserDailyQuota     = "user:%s:daily_quota"
	UserPlan           = "user:%s:plan"
	ReferralCodeKey    = "referral:code:%s"
	WebhookIdempotency = "webhook:idempotency:%s"
	// Notifications
	MatchInviteThrottleKey = "match_invite:%s:%s" // fromUserID, toUserID
	// Phase 3 (4.4): friend challenge throttle so one challenger can't
	// spam-fire challenges at the same friend. Key per (from, to) pair,
	// 30-second TTL set on send (see ChallengeThrottleTTL in redis.go).
	ChallengeThrottleKey = "challenge:throttle:%s:%s" // fromUserID, toUserID
	// Phase 3 (4.4): online-presence TTL key. SET with PresenceTTL on
	// every Heartbeat RPC; GetFriendsList reads via EXISTS-equivalent
	// (a non-zero TTL key means "online within the last minute").
	PresenceKey = "presence:%s" // userID
	// Phase 3 (4.6): notification policy keys.
	// NotifDailyCapKey caps the per-user push count per day. INCR with a
	// 48h TTL — the extra 24h cushion absorbs timezone drift and clock
	// skew between services without bothering with timezone-aware key
	// names. The TTL is a fail-safe; the day rollover happens via the
	// {YYYY-MM-DD} segment.
	NotifDailyCapKey = "notif:dailycap:%s:%s" // userID, YYYY-MM-DD
	// NotifDedupKey prevents the same category firing twice within the
	// dedup window (e.g. 3 streak warnings in an hour). SETNX with TTL.
	NotifDedupKey = "notif:dedup:%s:%s" // userID, category
	// NotifMetricSentKey / NotifMetricOpenedKey / NotifMetricDroppedKey
	// are global per-day counters (not per-user) used to compute open
	// rate and watch policy effectiveness over time. 7-day TTL — long
	// enough to look at "yesterday" without keeping a forever metric set.
	NotifMetricSentKey    = "notif:metric:sent:%s:%s"       // category, YYYY-MM-DD
	NotifMetricOpenedKey  = "notif:metric:opened:%s:%s"     // category, YYYY-MM-DD
	NotifMetricDroppedKey = "notif:metric:dropped:%s:%s:%s" // category, reason, YYYY-MM-DD
)

// Key helper functions — one function per key to prevent fmt.Sprintf typos.

func Players(roomID string) string {
	return fmt.Sprintf(RoomPlayers, roomID)
}

func State(roomID string) string {
	return fmt.Sprintf(RoomState, roomID)
}

func Round(roomID string) string {
	return fmt.Sprintf(RoomRound, roomID)
}

func Questions(roomID string) string {
	return fmt.Sprintf(RoomQuestions, roomID)
}

func Leaderboard(roomID string) string {
	return fmt.Sprintf(RoomLeaderboard, roomID)
}

func Answers(roomID string, round int) string {
	return fmt.Sprintf(RoomAnswers, roomID, round)
}

func Lock(roomID string) string {
	return fmt.Sprintf(RoomLock, roomID)
}

func RoundClosed(roomID string, round int) string {
	return fmt.Sprintf(RoomRoundClosed, roomID, round)
}

func EmailCodeKey(email, purpose string) string {
	return fmt.Sprintf(EmailCode, email, purpose)
}

func EmailRateLimitKey(email string) string {
	return fmt.Sprintf(EmailRateLimit, email)
}

func DailyQuota(userID string) string {
	return fmt.Sprintf(UserDailyQuota, userID)
}

func Plan(userID string) string {
	return fmt.Sprintf(UserPlan, userID)
}

func RefCode(code string) string {
	return fmt.Sprintf(ReferralCodeKey, code)
}

func WebhookIdem(paymentID string) string {
	return fmt.Sprintf(WebhookIdempotency, paymentID)
}

// MatchInviteThrottle builds the Redis key guarding an inviter→opponent
// notif.match.invite push. Held for 30 min to avoid spamming the same opponent.
func MatchInviteThrottle(fromUserID, toUserID string) string {
	return fmt.Sprintf(MatchInviteThrottleKey, fromUserID, toUserID)
}

// ChallengeThrottle builds the Redis SETNX guard preventing rapid-fire
// challenge spam from one user to the same friend.
func ChallengeThrottle(fromUserID, toUserID string) string {
	return fmt.Sprintf(ChallengeThrottleKey, fromUserID, toUserID)
}

// Presence builds the Redis TTL key whose existence indicates the user
// has heartbeat'd within the configured window.
func Presence(userID string) string {
	return fmt.Sprintf(PresenceKey, userID)
}

// NotifDailyCap is the per-user-per-day cap counter the notification
// policy gate increments before each push. day is the YYYY-MM-DD bucket
// the user is currently in (in their local timezone — caller's
// responsibility to format correctly).
func NotifDailyCap(userID, day string) string {
	return fmt.Sprintf(NotifDailyCapKey, userID, day)
}

// NotifDedup is the per-user-per-category dedup key the policy gate
// SETNXs before each push to suppress repeats inside the dedup window.
func NotifDedup(userID, category string) string {
	return fmt.Sprintf(NotifDedupKey, userID, category)
}

// NotifMetricSent / Opened / Dropped build the global per-day metric
// keys. Operators read these via redis-cli to compute open rate and
// drop reasons over a window.
func NotifMetricSent(category, day string) string {
	return fmt.Sprintf(NotifMetricSentKey, category, day)
}
func NotifMetricOpened(category, day string) string {
	return fmt.Sprintf(NotifMetricOpenedKey, category, day)
}
func NotifMetricDropped(category, reason, day string) string {
	return fmt.Sprintf(NotifMetricDroppedKey, category, reason, day)
}
