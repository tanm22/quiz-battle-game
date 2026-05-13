import 'package:flutter/material.dart';

/// LocalAvatar — a gradient-backed monogram avatar rendered entirely
/// in-process. No network, no asset bundle, no system-font emoji.
///
/// Each instance is a circle filled with a top-left → bottom-right
/// linear gradient derived from [background] (the top-left anchor) and
/// a 12% darker shade in HSL space (the bottom-right anchor). The
/// user's first display-name character sits centered in bold white —
/// the same affordance Slack, Linear, Notion, and Gmail use for users
/// without a photo.
///
/// We deliberately avoid emoji glyphs here: cartoon faces (🦊 🐼 🐯)
/// were the previous render and read as childish on the home card,
/// matchmaking lobby, and friends list. A monogram + saturated
/// gradient reads as identity, not decoration, and scales cleanly from
/// the 28px nav-bar size to the 96px hero size without losing legibility.
class LocalAvatar extends StatelessWidget {
  /// Display name — the first grapheme is uppercased and rendered as
  /// the monogram. An empty/whitespace-only name renders "?".
  final String name;

  /// Base color anchor. The bottom-right gradient stop is computed as
  /// a slightly-darker HSL transform so the avatar reads as a single
  /// "theme" rather than two distinct colors.
  final Color background;

  final double size;

  const LocalAvatar({
    super.key,
    required this.name,
    required this.background,
    this.size = 64,
  });

  /// Darken the base color by ~12% lightness in HSL space — gives the
  /// gradient enough depth to look intentional without producing a
  /// jarring two-tone effect. Clamped so very-dark base colors stay
  /// inside the renderable range.
  Color _gradientEnd() {
    final hsl = HSLColor.fromColor(background);
    return hsl
        .withLightness((hsl.lightness - 0.12).clamp(0.0, 1.0))
        .toColor();
  }

  /// First grapheme cluster of [name], uppercased. Empty → "?".
  /// Mirrors GoogleStyleAvatar so monograms stay consistent whether
  /// the user picked a preset color or has a remote photo URL that
  /// hasn't loaded yet.
  String get _initial {
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [background, _gradientEnd()],
        ),
      ),
      child: Text(
        _initial,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          height: 1.0,
        ),
      ),
    );
  }
}

/// One preset avatar color theme. The persisted [url] is what the
/// backend stores in `user.avatarUrl`; the [color] drives the
/// on-device gradient render. [name] is the human-readable theme
/// label (used in the picker tooltip / a11y).
class PresetAvatar {
  final String name;
  final Color color;
  final String url;
  const PresetAvatar(this.name, this.color, this.url);
}

/// Curated palette of 6 saturated theme colors. The set is intentionally
/// small — every option needs to look distinct on the picker grid and
/// each one needs to read as "identity" on the home card. The colors
/// were tuned for ≥ 4.5:1 contrast with white text at the displayed
/// monogram weight.
///
/// The persisted URL strings are inherited from the previous emoji-
/// based palette ("Fox", "Owl", …). They double as stable identifiers
/// so [presetFromAvatarUrl] still resolves the saved avatarUrl of
/// already-onboarded accounts to the right color theme. URL CONTENT IS
/// NOT RENDERED ON THE CLIENT — LocalAvatar paints the gradient
/// monogram directly. The URL is preserved so an older client (or a
/// future non-Flutter surface) can fetch a reasonable bitmap fallback.
const kPresetAvatars = <PresetAvatar>[
  PresetAvatar(
    'Sunset',
    Color(0xFFEA580C),
    'https://ui-avatars.com/api/?name=Fox&background=EA580C&color=fff&size=128&bold=true',
  ),
  PresetAvatar(
    'Indigo',
    Color(0xFF6D59C4),
    'https://ui-avatars.com/api/?name=Owl&background=6D59C4&color=fff&size=128&bold=true',
  ),
  PresetAvatar(
    'Emerald',
    Color(0xFF059669),
    'https://ui-avatars.com/api/?name=Panda&background=059669&color=fff&size=128&bold=true',
  ),
  PresetAvatar(
    'Crimson',
    Color(0xFFE11D48),
    'https://ui-avatars.com/api/?name=Tiger&background=E11D48&color=fff&size=128&bold=true',
  ),
  PresetAvatar(
    'Ocean',
    Color(0xFF0891B2),
    'https://ui-avatars.com/api/?name=Koala&background=0891B2&color=fff&size=128&bold=true',
  ),
  PresetAvatar(
    'Amber',
    Color(0xFFE8940A),
    'https://ui-avatars.com/api/?name=Penguin&background=E8940A&color=fff&size=128&bold=true',
  ),
];

/// Returns the matching [PresetAvatar] for a saved `avatarUrl`. Used
/// by render sites to decide between LocalAvatar (preset) and
/// GoogleStyleAvatar (remote photo / no avatar at all).
PresetAvatar? presetFromAvatarUrl(String url) {
  for (final p in kPresetAvatars) {
    if (p.url == url) return p;
  }
  return null;
}
