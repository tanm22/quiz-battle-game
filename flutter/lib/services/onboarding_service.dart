import 'package:shared_preferences/shared_preferences.dart';

/// Tracks onboarding progress locally so the app can resume the flow even
/// before the backend round-trip (faster perceived startup).
class OnboardingService {
  static const _kCarouselSeen = 'onboarding_carousel_seen';
  static const _kCompleted    = 'onboarding_completed';

  static Future<bool> hasSeenCarousel() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kCarouselSeen) ?? false;
  }

  static Future<void> markCarouselSeen() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kCarouselSeen, true);
  }

  static Future<bool> isCompleted() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kCompleted) ?? false;
  }

  static Future<void> markCompleted() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kCompleted, true);
  }

  static Future<void> reset() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kCarouselSeen);
    await p.remove(_kCompleted);
  }
}
