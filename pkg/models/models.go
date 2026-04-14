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
	Current         int    `bson:"current" json:"current"`
	Longest         int    `bson:"longest" json:"longest"`
	LastClaimedDate string `bson:"lastClaimedDate" json:"lastClaimedDate"` // YYYY-MM-DD IST
}

// User is the MongoDB document in the users collection.
type User struct {
	ID            string     `bson:"_id"`
	Username      string     `bson:"username"`
	PasswordHash  string     `bson:"passwordHash,omitempty"`
	Email         string     `bson:"email,omitempty"`
	GoogleID      string     `bson:"googleId,omitempty"`
	DisplayName   string     `bson:"displayName,omitempty"`
	AvatarUrl     string     `bson:"avatarUrl,omitempty"`
	IsGuest       bool       `bson:"isGuest"`
	Rating        int32      `bson:"rating"`
	MatchesPlayed int32      `bson:"matchesPlayed"`
	Wins          int32      `bson:"wins"`
	Plan          string     `bson:"plan"`          // "free" or "premium"
	PlanExpiresAt *time.Time `bson:"planExpiresAt,omitempty"`
	Coins         int64      `bson:"coins"`
	FCMTokens     []string   `bson:"fcmTokens,omitempty"`
	ReferralCode  string     `bson:"referralCode,omitempty"`
	ReferredBy    string     `bson:"referredBy,omitempty"`
	Streak         Streak     `bson:"streak"`
	CorrectAnswers int32      `bson:"correctAnswers"`
	TotalAnswers   int32      `bson:"totalAnswers"`
	CreatedAt      int64      `bson:"createdAt"`
}

// Payment is the MongoDB document in the payments collection.
type Payment struct {
	ID                string    `bson:"_id,omitempty"`
	UserID            string    `bson:"userId"`
	RazorpayOrderID   string    `bson:"razorpayOrderId"`
	RazorpayPaymentID string    `bson:"razorpayPaymentId,omitempty"`
	Amount            int64     `bson:"amount"`
	Currency          string    `bson:"currency"`
	Status            string    `bson:"status"` // "created", "captured", "failed"
	PlanDuration      string    `bson:"planDuration"`
	WebhookReceivedAt *time.Time `bson:"webhookReceivedAt,omitempty"`
	CreatedAt         time.Time `bson:"createdAt"`
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
	ID               string    `bson:"_id,omitempty"`
	Name             string    `bson:"name"`
	StartTime        time.Time `bson:"startTime"`
	EndTime          time.Time `bson:"endTime"`
	Status           string    `bson:"status"` // "upcoming", "active", "completed"
	Participants     []string  `bson:"participants"`
	RequiredPlan     string    `bson:"requiredPlan"`
	PrizeDescription string    `bson:"prizeDescription"`
	ReminderSent     bool      `bson:"reminderSent"`
	CreatedAt        time.Time `bson:"createdAt"`
}
