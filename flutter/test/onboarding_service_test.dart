import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiz_battle/services/onboarding_service.dart';

void main() {
  group('OnboardingService', () {
    setUp(() {
      // Reset to a known-empty state before every test. The mocked
      // SharedPreferences instance is process-global, so without this
      // tests would bleed state into each other.
      SharedPreferences.setMockInitialValues({});
    });

    test('hasSeenCarousel defaults to false on a fresh install', () async {
      expect(await OnboardingService.hasSeenCarousel(), isFalse);
    });

    test('markCarouselSeen flips the flag', () async {
      expect(await OnboardingService.hasSeenCarousel(), isFalse);
      await OnboardingService.markCarouselSeen();
      expect(await OnboardingService.hasSeenCarousel(), isTrue);
    });

    test('reset clears the carousel flag', () async {
      await OnboardingService.markCarouselSeen();
      expect(await OnboardingService.hasSeenCarousel(), isTrue);

      await OnboardingService.reset();

      expect(await OnboardingService.hasSeenCarousel(), isFalse);
    });
  });
}
