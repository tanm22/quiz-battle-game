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
