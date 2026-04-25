import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../../providers/game_state.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/local_avatar.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _displayNameCtl = TextEditingController();
  int _avatarIndex = 0;
  bool _saving = false;
  String? _error;

  // Preset avatars are rendered locally as colored letter circles —
  // no network required, so previews are instant on any device. The
  // backend still receives a real URL (the matching ui-avatars.com
  // entry) so future clients that want a fetchable image can use it.
  static const _presets = <_PresetAvatar>[
    _PresetAvatar(
      'F',
      Color(0xFFEA580C),
      'https://ui-avatars.com/api/?name=Fox&background=EA580C&color=fff&size=128&bold=true',
    ),
    _PresetAvatar(
      'O',
      Color(0xFF6D59C4),
      'https://ui-avatars.com/api/?name=Owl&background=6D59C4&color=fff&size=128&bold=true',
    ),
    _PresetAvatar(
      'P',
      Color(0xFF059669),
      'https://ui-avatars.com/api/?name=Panda&background=059669&color=fff&size=128&bold=true',
    ),
    _PresetAvatar(
      'T',
      Color(0xFFE11D48),
      'https://ui-avatars.com/api/?name=Tiger&background=E11D48&color=fff&size=128&bold=true',
    ),
    _PresetAvatar(
      'K',
      Color(0xFF0891B2),
      'https://ui-avatars.com/api/?name=Koala&background=0891B2&color=fff&size=128&bold=true',
    ),
    _PresetAvatar(
      'P',
      Color(0xFFE8940A),
      'https://ui-avatars.com/api/?name=Penguin&background=E8940A&color=fff&size=128&bold=true',
    ),
  ];

  // Becomes true when the user signed in with Google and has a real
  // photo URL — that goes at index 0 and is rendered via Image.network
  // (with a LocalAvatar fallback if the photo fails to load).
  late final bool _hasGooglePhoto;
  String? _googlePhotoUrl;
  late final int _avatarCount;

  String _avatarUrlAt(int index) {
    if (_hasGooglePhoto && index == 0) return _googlePhotoUrl!;
    return _presets[index - (_hasGooglePhoto ? 1 : 0)].url;
  }

  @override
  void initState() {
    super.initState();
    final auth = AuthService();
    _displayNameCtl.text = auth.username ?? '';
    // If the user came in via Google, their photo URL is already on the
    // server-side UserProfile. Prepend it as the default avatar so the
    // spec's "use your Google photo" path is honored.
    final googlePhoto = auth.avatarUrl;
    if (googlePhoto != null && googlePhoto.isNotEmpty) {
      _hasGooglePhoto = true;
      _googlePhotoUrl = googlePhoto;
    } else {
      _hasGooglePhoto = false;
    }
    _avatarCount = _presets.length + (_hasGooglePhoto ? 1 : 0);
  }

  @override
  void dispose() {
    _displayNameCtl.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _displayNameCtl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Pick a display name');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService().updateProfile(
        displayName: name,
        avatarUrl: _avatarUrlAt(_avatarIndex),
      );
      if (!mounted) return;
      ref.read(gameStateProvider.notifier).navigateToOnboardingTopicPicker();
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
                'Set up your profile',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pick a display name and an avatar. You can change these later.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 32),
              const Text(
                'Display name',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _displayNameCtl,
                maxLength: 30,
                style: const TextStyle(color: AppColors.text),
                decoration: InputDecoration(
                  hintText: 'e.g. Alice',
                  hintStyle: const TextStyle(color: AppColors.textDim),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.button,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Choose an avatar',
                style: TextStyle(
                  color: AppColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemCount: _avatarCount,
                itemBuilder: (_, i) {
                  final selected = i == _avatarIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _avatarIndex = i),
                    child: AnimatedContainer(
                      duration: AppDurations.quick,
                      decoration: BoxDecoration(
                        borderRadius: AppRadius.card,
                        border: Border.all(
                          color: selected ? AppColors.primary : AppColors.border,
                          width: selected ? 3 : 1,
                        ),
                        color: AppColors.surface,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _renderAvatar(i),
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
                        : const Text(
                            'Continue',
                            style: TextStyle(
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

  /// Builds the i-th avatar tile. The Google-photo slot (index 0 when
  /// signed in via Google) uses Image.network with a LocalAvatar fallback
  /// so a failed photo load still renders something sensible. Preset
  /// slots are pure-Dart LocalAvatar — no network involved.
  Widget _renderAvatar(int i) {
    if (_hasGooglePhoto && i == 0) {
      return ClipOval(
        child: Image.network(
          _googlePhotoUrl!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const LocalAvatar(
            letter: 'G',
            background: AppColors.accent,
          ),
        ),
      );
    }
    final preset = _presets[i - (_hasGooglePhoto ? 1 : 0)];
    return LocalAvatar(letter: preset.letter, background: preset.background);
  }
}

class _PresetAvatar {
  final String letter;
  final Color background;
  final String url;
  const _PresetAvatar(this.letter, this.background, this.url);
}
