// Package notif holds the canonical notification category list shared
// between services/scoring (which validates UpdateNotificationPrefs
// inputs) and services/notification (which classifies events at
// dispatch time). Keeping a single source of truth prevents the two
// sides from drifting — adding a new category in one place without the
// other would silently break either mute toggles or routing.
package notif

// Categories enumerates every category the §4.6 policy gate
// recognises. To add one:
//  1. Append to this list.
//  2. Add the routing-key → category mapping in CategoryFromEvent.
//  3. Add a UI affordance in the Flutter notification settings screen.
var Categories = []string{
	CategoryFriendRequest,
	CategoryFriendChallenge,
	CategoryMatchInvite,
	CategoryStreak,
	CategoryDailyReward,
	CategoryReferral,
	CategoryTournament,
	CategoryPremium,
}

// Named constants so callers don't pass typo'd literals into mute lists.
const (
	CategoryFriendRequest   = "friend_request"
	CategoryFriendChallenge = "friend_challenge"
	CategoryMatchInvite     = "match_invite"
	CategoryStreak          = "streak"
	CategoryDailyReward     = "daily_reward"
	CategoryReferral        = "referral"
	CategoryTournament      = "tournament"
	CategoryPremium         = "premium"
	// CategoryOther is the catch-all the policy gate uses for events
	// it doesn't recognise. Not a user-mutable category — never
	// returned by IsKnown — so a mute on "other" is rejected.
	CategoryOther = "other"
)

// IsKnown returns true if c is a category users can mute. The
// catch-all "other" returns false on purpose: muting it would silence
// every unclassified event and that's a footgun.
func IsKnown(c string) bool {
	for _, k := range Categories {
		if k == c {
			return true
		}
	}
	return false
}

// CategoryFromEvent maps a RabbitMQ event string (the value of the
// "event" field in the payload, which mirrors the routing key) to a
// category. An unknown event resolves to CategoryOther — the policy
// gate still applies quiet hours and the daily cap, but mute and
// dedup don't have a meaningful category to key off, so unknown
// events effectively bypass those two gates.
func CategoryFromEvent(event string) string {
	switch event {
	case "notif.friend.request_received", "notif.friend.request_accepted":
		return CategoryFriendRequest
	case "notif.friend.challenge":
		return CategoryFriendChallenge
	case "notif.match.invite":
		return CategoryMatchInvite
	case "notif.streak.warning":
		return CategoryStreak
	case "notif.daily.reward":
		return CategoryDailyReward
	case "notif.referral.converted":
		return CategoryReferral
	case "notif.tournament.remind",
		"notif.tournament.finished",
		"notif.tournament.rank_changed":
		return CategoryTournament
	case "notif.premium.activated",
		"notif.premium.expiry",
		"notif.premium.expired",
		// "premium.expired" (bare, no notif. prefix) is a legacy routing
		// key emitted by services/payment when a plan expires. It
		// predates the notif.* convention and is consumed by the
		// premium-expiry-queue bound to premium.*. Listed here so the
		// gate categorises it correctly; not a sign of a routing bug.
		"premium.expired":
		return CategoryPremium
	}
	return CategoryOther
}
