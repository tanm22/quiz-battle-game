import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grpc/grpc.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/local_avatar.dart';

/// Lets an existing (already-onboarded) user change their display name,
/// avatar, and preferred topics in one place. Reachable from the
/// Profile tab. Saves all three fields in a single UpdateProfile call.
class EditProfileScreen extends ConsumerStatefulWidget {
  /// Pre-fills the form. Caller should pass the current values from
  /// the user's profile so the screen reflects today's state and the
  /// user only needs to tweak what they want.
  final String displayName;
  final String avatarUrl;
  final List<String> preferredTopics;

  const EditProfileScreen({
    super.key,
    required this.displayName,
    required this.avatarUrl,
    required this.preferredTopics,
  });

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
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

  late final TextEditingController _displayNameCtl;
  late int _avatarIndex;
  late Set<String> _selectedTopics;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _displayNameCtl = TextEditingController(text: widget.displayName);
    _selectedTopics = widget.preferredTopics.toSet();
    final preset = presetFromAvatarUrl(widget.avatarUrl);
    _avatarIndex = preset == null
        ? 0
        : kPresetAvatars.indexWhere((p) => p.url == widget.avatarUrl);
    if (_avatarIndex < 0) _avatarIndex = 0;
  }

  @override
  void dispose() {
    _displayNameCtl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _displayNameCtl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Display name cannot be empty');
      return;
    }
    if (_selectedTopics.isEmpty) {
      setState(() => _error = 'Pick at least one topic');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService().updateProfile(
        displayName: name,
        avatarUrl: kPresetAvatars[_avatarIndex].url,
        preferredTopics: _selectedTopics.toList(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
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
              'Avatar',
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
              itemCount: kPresetAvatars.length,
              itemBuilder: (_, i) {
                final selected = i == _avatarIndex;
                final preset = kPresetAvatars[i];
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
                      child: LocalAvatar(
                        glyph: preset.glyph,
                        background: preset.color,
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Preferred topics',
              style: TextStyle(
                color: AppColors.text,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _topics.map((t) {
                final selected = _selectedTopics.contains(t.slug);
                return GestureDetector(
                  onTap: () => setState(() {
                    if (selected) {
                      _selectedTopics.remove(t.slug);
                    } else {
                      _selectedTopics.add(t.slug);
                    }
                  }),
                  child: AnimatedContainer(
                    duration: AppDurations.quick,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: AppRadius.pill,
                      border: Border.all(
                        color: selected ? t.color : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                      color: selected ? t.tintedBg : AppColors.surface,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, color: t.color, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          t.label,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (selected) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.check_circle, color: t.color, size: 16),
                        ],
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: AppColors.danger, fontSize: 13),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppGradients.primary,
                  borderRadius: AppRadius.button,
                ),
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
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
                          'Save changes',
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
