import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../../providers/game_state.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

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

  // Preset avatar URLs — UI Avatars is more reliable than DiceBear on
  // some emulator network setups. Each emits a colored circle with the
  // initial. Swap for app-owned bucket later.
  static const _presetAvatars = <String>[
    'https://ui-avatars.com/api/?name=Fox&background=EA580C&color=fff&size=128&bold=true',
    'https://ui-avatars.com/api/?name=Owl&background=6D59C4&color=fff&size=128&bold=true',
    'https://ui-avatars.com/api/?name=Panda&background=059669&color=fff&size=128&bold=true',
    'https://ui-avatars.com/api/?name=Tiger&background=E11D48&color=fff&size=128&bold=true',
    'https://ui-avatars.com/api/?name=Koala&background=0891B2&color=fff&size=128&bold=true',
    'https://ui-avatars.com/api/?name=Penguin&background=E8940A&color=fff&size=128&bold=true',
  ];

  late final List<String> _avatarOptions;

  @override
  void initState() {
    super.initState();
    final auth = AuthService();
    _displayNameCtl.text = auth.username ?? '';
    // If the user came in via Google, their photo URL is already on the
    // server-side UserProfile (auth_service exposes it as .avatarUrl after
    // signInWithGoogle). Prepend it as the default avatar so the spec's
    // "use your Google photo" path is honored.
    final googlePhoto = auth.avatarUrl;
    if (googlePhoto != null && googlePhoto.isNotEmpty) {
      _avatarOptions = <String>[googlePhoto, ..._presetAvatars];
    } else {
      _avatarOptions = _presetAvatars;
    }
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
        avatarUrl: _avatarOptions[_avatarIndex],
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
                itemCount: _avatarOptions.length,
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
                      child: ClipRRect(
                        borderRadius: AppRadius.card,
                        child: Image.network(
                          _avatarOptions[i],
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.person, color: AppColors.textDim),
                        ),
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
}
