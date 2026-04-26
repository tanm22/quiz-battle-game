package notif

import "testing"

// TestCategoryFromEvent_KnownAndUnknown is the wire-contract guard
// between scoring's UpdateNotificationPrefs validator and the
// notification policy gate. Adding a new event must add a row here so
// the two packages don't silently diverge.
func TestCategoryFromEvent_KnownAndUnknown(t *testing.T) {
	cases := map[string]string{
		"notif.friend.request_received":  CategoryFriendRequest,
		"notif.friend.request_accepted":  CategoryFriendRequest,
		"notif.friend.challenge":         CategoryFriendChallenge,
		"notif.match.invite":             CategoryMatchInvite,
		"notif.streak.warning":           CategoryStreak,
		"notif.daily.reward":             CategoryDailyReward,
		"notif.referral.converted":       CategoryReferral,
		"notif.tournament.remind":        CategoryTournament,
		"notif.tournament.finished":      CategoryTournament,
		"notif.tournament.rank_changed":  CategoryTournament,
		"notif.premium.activated":        CategoryPremium,
		"notif.premium.expired":          CategoryPremium,
		"notif.premium.expiry":           CategoryPremium,
		"premium.expired":                CategoryPremium, // legacy bare key from services/payment
		"notif.something.never_seen_yet": CategoryOther,
	}
	for event, want := range cases {
		if got := CategoryFromEvent(event); got != want {
			t.Errorf("CategoryFromEvent(%q) = %q, want %q", event, got, want)
		}
	}
}

// TestIsKnown_RejectsCatchAll guards the contract that
// UpdateNotificationPrefs uses: users CANNOT mute "other" because that
// would silence every unclassified event — a footgun. Categories the
// product has named are mutable; the catch-all is not.
func TestIsKnown_RejectsCatchAll(t *testing.T) {
	if IsKnown(CategoryOther) {
		t.Errorf("IsKnown(%q) = true, want false (catch-all is not user-mutable)", CategoryOther)
	}
	for _, c := range Categories {
		if !IsKnown(c) {
			t.Errorf("IsKnown(%q) = false, want true (declared in Categories)", c)
		}
	}
}
