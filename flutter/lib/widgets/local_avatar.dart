import 'package:flutter/material.dart';

/// Renders an avatar locally as a colored circle with an emoji glyph
/// in the center. No network call, no asset bundle — emoji glyphs are
/// part of the system font on every device, so this works offline,
/// on emulators, and in any image-loading edge case.
///
/// We still save a URL (UI Avatars) to the backend for the
/// `user.avatarUrl` field; this widget is purely a render-side choice
/// so previews are reliable on the device. The matching emoji and
/// color are derived from the URL via [presetFromAvatarUrl].
class LocalAvatar extends StatelessWidget {
  final String glyph;
  final Color background;
  final double size;

  const LocalAvatar({
    super.key,
    required this.glyph,
    required this.background,
    this.size = 64,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background,
      ),
      child: Text(
        glyph,
        style: TextStyle(fontSize: size * 0.55, height: 1),
      ),
    );
  }
}

/// One preset avatar — the emoji we render locally and the URL we
/// persist to the backend. Keeping both means a future client that
/// wants real images can fetch the URL, and our app stays pure-Dart
/// for instant previews.
class PresetAvatar {
  final String name;
  final String glyph;
  final Color color;
  final String url;
  const PresetAvatar(this.name, this.glyph, this.color, this.url);
}

/// Single source of truth used by profile setup, home avatar, and the
/// profile edit screen. Adding/changing a preset here updates all
/// surfaces at once.
const kPresetAvatars = <PresetAvatar>[
  PresetAvatar(
    'Fox', '🦊', Color(0xFFEA580C),
    'https://ui-avatars.com/api/?name=Fox&background=EA580C&color=fff&size=128&bold=true',
  ),
  PresetAvatar(
    'Owl', '🦉', Color(0xFF6D59C4),
    'https://ui-avatars.com/api/?name=Owl&background=6D59C4&color=fff&size=128&bold=true',
  ),
  PresetAvatar(
    'Panda', '🐼', Color(0xFF059669),
    'https://ui-avatars.com/api/?name=Panda&background=059669&color=fff&size=128&bold=true',
  ),
  PresetAvatar(
    'Tiger', '🐯', Color(0xFFE11D48),
    'https://ui-avatars.com/api/?name=Tiger&background=E11D48&color=fff&size=128&bold=true',
  ),
  PresetAvatar(
    'Koala', '🐨', Color(0xFF0891B2),
    'https://ui-avatars.com/api/?name=Koala&background=0891B2&color=fff&size=128&bold=true',
  ),
  PresetAvatar(
    'Penguin', '🐧', Color(0xFFE8940A),
    'https://ui-avatars.com/api/?name=Penguin&background=E8940A&color=fff&size=128&bold=true',
  ),
];

/// Returns the matching [PresetAvatar] for a saved `avatarUrl`, or
/// null if the URL isn't one of our presets (e.g. it's a Google photo
/// from Google sign-in, or a future bucket-hosted custom upload).
PresetAvatar? presetFromAvatarUrl(String url) {
  for (final p in kPresetAvatars) {
    if (p.url == url) return p;
  }
  return null;
}
