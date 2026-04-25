import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../../providers/game_state.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class TopicPickerScreen extends ConsumerStatefulWidget {
  const TopicPickerScreen({super.key});

  @override
  ConsumerState<TopicPickerScreen> createState() => _TopicPickerScreenState();
}

class _TopicPickerScreenState extends ConsumerState<TopicPickerScreen> {
  // Slug → display label + icon + tinted bg.
  // Slugs match what the backend stores in user.preferredTopics.
  static const _topics = <_Topic>[
    _Topic('science', 'Science', Icons.science, AppColors.secondary, AppColors.cyanBg),
    _Topic('history', 'History', Icons.menu_book, AppColors.accent, AppColors.accentBg),
    _Topic('geography', 'Geography', Icons.public, AppColors.success, AppColors.emeraldBg),
    _Topic('sports', 'Sports', Icons.sports_basketball, AppColors.danger, AppColors.roseBg),
    _Topic('technology', 'Technology', Icons.memory, AppColors.primary, AppColors.orangeBg),
    _Topic('movies', 'Movies', Icons.movie, AppColors.gold, AppColors.goldBg),
    _Topic('music', 'Music', Icons.music_note, AppColors.primarySoft, AppColors.orangeBg),
    _Topic('gaming', 'Gaming', Icons.sports_esports, AppColors.accent, AppColors.accentBg),
  ];

  final Set<String> _selected = <String>{};
  bool _saving = false;
  String? _error;

  Future<void> _continue() async {
    if (_selected.isEmpty) {
      setState(() => _error = 'Pick at least one topic');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService().updateProfile(
        preferredTopics: _selected.toList(),
      );
      if (!mounted) return;
      ref.read(gameStateProvider.notifier).navigateToOnboardingPermissionPrime();
    } on GrpcError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Failed to save';
          _saving = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ScaffoldGradientBackground(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            children: [
              const Text(
                'What are you into?',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick a few topics so we can match you against opponents who like the same stuff.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.4,
                ),
                itemCount: _topics.length,
                itemBuilder: (_, i) {
                  final t = _topics[i];
                  final selected = _selected.contains(t.slug);
                  return GestureDetector(
                    onTap: () => setState(() {
                      if (selected) {
                        _selected.remove(t.slug);
                      } else {
                        _selected.add(t.slug);
                      }
                    }),
                    child: AnimatedContainer(
                      duration: AppDurations.quick,
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.card,
                        border: Border.all(
                          color: selected ? t.color : AppColors.border,
                          width: selected ? 2 : 1,
                        ),
                        color: selected ? t.tintedBg : AppColors.surface,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: [
                          Icon(t.icon, color: t.color, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            t.label,
                            style: const TextStyle(
                              color: AppColors.text,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          if (selected)
                            Icon(Icons.check_circle, color: t.color, size: 20),
                        ],
                      ),
                    ),
                  );
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 13),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    borderRadius: AppRadius.button,
                  ),
                  child: ElevatedButton(
                    onPressed: _saving ? null : _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.button),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _selected.isEmpty
                                ? 'Pick at least one'
                                : 'Continue (${_selected.length} selected)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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

class _Topic {
  final String slug;
  final String label;
  final IconData icon;
  final Color color;
  final Color tintedBg;
  const _Topic(this.slug, this.label, this.icon, this.color, this.tintedBg);
}
