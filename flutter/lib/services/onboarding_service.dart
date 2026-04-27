import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the pre-signup intro carousel has been seen on this
/// device. The "onboarding completed" state intentionally does NOT
/// live here — that flag is owned by the server (via the user record's
/// `onboardingCompleted` field) and mirrored on AuthService. Keeping a
/// parallel local flag here would be a desync risk.
class OnboardingService {
  static const _kCarouselSeen = 'onboarding_carousel_seen';

  static Future<bool> hasSeenCarousel() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kCarouselSeen) ?? false;
  }

  static Future<void> markCarouselSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kCarouselSeen, true);
  }

  static Future<void> reset() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kCarouselSeen);
  }
}
