package models

// PlayerInfo is stored as JSON in the room:{id}:players hash.
type PlayerInfo struct {
	UserID   string `json:"userId"`
	Username string `json:"username"`
	Rating   int32  `json:"rating"`
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

// User is the MongoDB document in the users collection.
type User struct {
	ID            string `bson:"_id"`
	Username      string `bson:"username"`
	PasswordHash  string `bson:"passwordHash"`
	Email         string `bson:"email,omitempty"`
	IsGuest       bool   `bson:"isGuest"`
	Rating        int32  `bson:"rating"`
	MatchesPlayed int32  `bson:"matchesPlayed"`
	Wins          int32  `bson:"wins"`
	CreatedAt     int64  `bson:"createdAt"`
}
