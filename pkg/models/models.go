package models

import "time"

// PlayerInfo is stored as JSON in the room:{id}:players hash.
type PlayerInfo struct {
	UserID   string `json:"userId"`
	Username string `json:"username"`
	Rating   int32  `json:"rating"`
	Plan     string `json:"plan"`
}

// RoomState is stored as JSON in room:{id}:state.
type RoomState struct {
	RoomID    string   `json:"roomId"`
	PlayerIDs []string `json:"playerIds"`
	Status    string   `json:"status"` // "waiting", "playing", "finished"
	Round     int      `json:"round"`
	CreatedAt int64    `json:"createdAt"`
}

// AnswerRecord is stored as JSON in room:{id}:answers:{round} hash.
type AnswerRecord struct {
	UserID          string `json:"userId"`
	OptionIndex     int32  `json:"optionIndex"`
	ClientTimestamp int64  `json:"clientTimestamp"`
	ServerTimestamp int64  `json:"serverTimestamp"`
}

// Streak is embedded in the User document. Source of truth is MongoDB only (ISSUE-01).
type Streak struct {
	Current           int    `bson:"current" json:"current"`
	Longest           int    `bson:"longest" json:"longest"`
	LastClaimedDate   string `bson:"lastClaimedDate" json:"lastClaimedDate"`     // YYYY-MM-DD IST
	RewardClaimedDate string `bson:"rewardClaimedDate" json:"rewardClaimedDate"` // YYYY-MM-DD IST
}

// User is the MongoDB document in the users collection.
type User struct {
	ID                    string     `bson:"_id"`
	Username              string     `bson:"username"`
	PasswordHash          string     `bson:"passwordHash,omitempty"`
	Email                 string     `bson:"email,omitempty"`
	GoogleID              string     `bson:"googleId,omitempty"`
	DisplayName           string     `bson:"displayName,omitempty"`
	AvatarUrl             string     `bson:"avatarUrl,omitempty"`
	IsGuest               bool       `bson:"isGuest"`
	Rating                int32      `bson:"rating"`
	MatchesPlayed         int32      `bson:"matchesPlayed"`
	Wins                  int32      `bson:"wins"`
	WinStreak             int32      `bson:"winStreak"`
	LongestWinStreak      int32      `bson:"longestWinStreak"`
	Plan                  string     `bson:"plan"` // "free" or "premium"
	PlanExpiresAt         *time.Time `bson:"planExpiresAt,omitempty"`
	Coins                 int64      `bson:"coins"`
	FCMTokens             []string   `bson:"fcmTokens,omitempty"`
	ReferralCode          string     `bson:"referralCode,omitempty"`
	ReferredBy            string     `bson:"referredBy,omitempty"`
	Streak                Streak     `bson:"streak"`
	CorrectAnswers        int32      `bson:"correctAnswers"`
	TotalAnswers          int32      `bson:"totalAnswers"`
	PreferredTopics       []string   `bson:"preferredTopics,omitempty" json:"preferredTopics,omitempty"`
	OnboardingCompleted   bool       `bson:"onboardingCompleted" json:"onboardingCompleted"`
	OnboardingCompletedAt *time.Time `bson:"onboardingCompletedAt,omitempty" json:"onboardingCompletedAt,omitempty"`
	CreatedAt             int64      `bson:"createdAt"`
}

// Payment is the MongoDB document in the payments collection.
type Payment struct {
	ID                string     `bson:"_id,omitempty"`
	UserID            string     `bson:"userId"`
	RazorpayOrderID   string     `bson:"razorpayOrderId"`
	RazorpayPaymentID string     `bson:"razorpayPaymentId,omitempty"`
	Amount            int64      `bson:"amount"`
	Currency          string     `bson:"currency"`
	Status            string     `bson:"status"` // "created", "captured", "failed"
	PlanDuration      string     `bson:"planDuration"`
	WebhookReceivedAt *time.Time `bson:"webhookReceivedAt,omitempty"`
	CreatedAt         time.Time  `bson:"createdAt"`
}

// Referral is the MongoDB document in the referrals collection.
type Referral struct {
	ID            string     `bson:"_id,omitempty"`
	ReferrerID    string     `bson:"referrerId"`
	RefereeID     string     `bson:"refereeId"`
	ReferralCode  string     `bson:"referralCode"`
	Status        string     `bson:"status"` // "pending", "converted"
	RewardGranted bool       `bson:"rewardGranted"`
	ConvertedAt   *time.Time `bson:"convertedAt,omitempty"`
	CreatedAt     time.Time  `bson:"createdAt"`
}

// Tournament is the MongoDB document in the tournaments collection.
type Tournament struct {
	ID        string    `bson:"_id,omitempty"`
	Name      string    `bson:"name"`
	StartTime time.Time `bson:"startTime"`
	EndTime   time.Time `bson:"endTime"`
	// EntryDeadline is the cutoff for new participants. Defaults to StartTime
	// when zero. Lets us configure tournaments where joins close before the
	// scoring window opens (e.g. premium leagues with announced rosters).
	EntryDeadline time.Time `bson:"entryDeadline,omitempty"`
	Status        string    `bson:"status"` // "upcoming", "active", "completed"
	Participants  []string  `bson:"participants"`
	RequiredPlan  string    `bson:"requiredPlan"`
	// PrizeDescription is human-readable; PrizePool is the structured prize
	// table actually used by the finalization worker. Index i in the slice
	// is the coin reward for rank i+1 (PrizePool[0] = winner). An empty
	// slice means the tournament is purely reputational — no coins awarded.
	PrizeDescription string  `bson:"prizeDescription"`
	PrizePool        []int64 `bson:"prizePool,omitempty"`
	// WinnersAwarded flips true after the finalization worker has emitted
	// tournament.finished events for the top-N. Idempotency guard so the
	// worker can re-poll safely without double-paying.
	WinnersAwarded bool `bson:"winnersAwarded"`
	// AutoGenerated marks tournaments created by the weekly cron, so the
	// cron can ask "did I already create this week's open tournament?"
	// without colliding with manually-seeded ones.
	AutoGenerated bool      `bson:"autoGenerated,omitempty"`
	ReminderSent  bool      `bson:"reminderSent"`
	CreatedAt     time.Time `bson:"createdAt"`
}

// TournamentStanding is a row in the tournament_standings collection.
// Updated atomically (via $inc) by the scoring service when a participant
// finishes a regular match while a tournament is active. Read by the quiz
// service's finalization worker to compute top-N.
//
// Indexes (declared in seed/main.go):
//   - unique compound (tournamentId, userId)
//   - compound (tournamentId, score desc) for ranking queries
type TournamentStanding struct {
	ID            string    `bson:"_id,omitempty"`
	TournamentID  string    `bson:"tournamentId"`
	UserID        string    `bson:"userId"`
	Username      string    `bson:"username"`
	Score         int64     `bson:"score"`
	MatchesPlayed int32     `bson:"matchesPlayed"`
	UpdatedAt     time.Time `bson:"updatedAt"`
	CreatedAt     time.Time `bson:"createdAt"`
}

// TournamentPayout is a durable work-list row for the tournament prize
// pipeline. Inserted by the quiz finalization worker right after the
// atomic winnersAwarded flip, so a RabbitMQ outage between "we know who
// won" and "publish each tournament.finished" doesn't lose prize coins.
//
// State machine:
//
//	pending   — row written, publish to RabbitMQ has NOT been confirmed.
//	            The drain worker re-publishes pending rows on its tick.
//	published — quiz finalizer (or drain) successfully wrote the message
//	            to the broker. The consumer hasn't acked yet.
//	paid      — scoring consumer has incremented user.coins and is done.
//	            Set via an atomic check-then-set so a queue redelivery
//	            transitions exactly one row.
//
// The (tournamentId, userId) unique index gives us natural dedup: two
// finalizers racing on the same tournament both attempt $setOnInsert and
// only one wins. The drain worker's republish + the consumer's transition
// together give at-least-once delivery with idempotent processing.
//
// Indexes (declared in seed/main.go):
//   - unique compound (tournamentId, userId)
//   - status (for the drain worker's "find all pending" sweep)
type TournamentPayout struct {
	ID             string     `bson:"_id,omitempty"`
	TournamentID   string     `bson:"tournamentId"`
	TournamentName string     `bson:"tournamentName"`
	UserID         string     `bson:"userId"`
	Username       string     `bson:"username"`
	Rank           int        `bson:"rank"`
	CoinsAwarded   int64      `bson:"coinsAwarded"`
	FinalScore     int64      `bson:"finalScore"`
	Status         string     `bson:"status"` // "pending" | "published" | "paid"
	CreatedAt      time.Time  `bson:"createdAt"`
	PublishedAt    *time.Time `bson:"publishedAt,omitempty"`
	PaidAt         *time.Time `bson:"paidAt,omitempty"`
}
