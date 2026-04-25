import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_state.dart';
import '../../services/onboarding_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/onboarding_slide.dart';

class OnboardingCarouselScreen extends ConsumerStatefulWidget {
  const OnboardingCarouselScreen({super.key});

  @override
  ConsumerState<OnboardingCarouselScreen> createState() => _OnboardingCarouselScreenState();
}

class _OnboardingCarouselScreenState extends ConsumerState<OnboardingCarouselScreen> {
  final PageController _pc = PageController();
  int _page = 0;

  static const _slides = <_SlideSpec>[
    _SlideSpec(
      icon: Icons.bolt_rounded,
      iconColor: AppColors.primary,
      iconBg: AppColors.orangeBg,
      title: 'Real-time quiz battles',
      body: 'Match with opponents at your level and race the clock, round by round.',
    ),
    _SlideSpec(
      icon: Icons.emoji_events_rounded,
      iconColor: AppColors.gold,
      iconBg: AppColors.goldBg,
      title: 'Climb the leaderboard',
      body: 'Rack up wins, earn coins, and chase weekly tournament prize pools.',
    ),
    _SlideSpec(
      icon: Icons.local_fire_department_rounded,
      iconColor: AppColors.danger,
      iconBg: AppColors.roseBg,
      title: 'Build a streak',
      body: 'Daily streak bonuses, coin rewards, and perks that grow as you do.',
    ),
  ];

  @override
  void dispose() {
    _pc.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await OnboardingService.markCarouselSeen();
    if (!mounted) return;
    // Carousel is pre-signup — send user to login next.
    ref.read(gameStateProvider.notifier).navigateToLogin();
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _slides.length - 1;
    return Scaffold(
      body: SafeArea(
        child: ScaffoldGradientBackground(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextButton(
                    onPressed: _finish,
                    child: const Text('Skip', style: TextStyle(color: AppColors.textMuted)),
                  ),
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _pc,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) {
                    final s = _slides[i];
                    return OnboardingSlide(
                      icon: s.icon,
                      iconColor: s.iconColor,
                      iconBg: s.iconBg,
                      title: s.title,
                      body: s.body,
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_slides.length, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: AppDurations.quick,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 22 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: active ? AppColors.primary : AppColors.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: SizedBox(
                  width: double.infinity,
                  child: DecoratedBox(
                    decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: AppRadius.button),
                    child: ElevatedButton(
                      onPressed: isLast
                          ? _finish
                          : () => _pc.nextPage(
                                duration: AppDurations.medium,
                                curve: Curves.easeOutCubic,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                      ),
                      child: Text(
                        isLast ? "Let's go" : 'Next',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideSpec {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String body;
  const _SlideSpec({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.body,
  });
}
