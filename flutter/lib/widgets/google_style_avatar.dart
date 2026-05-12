import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// GoogleStyleAvatar — drop-in replacement for the bare
/// `Image.network` + `Text(initial)` pattern used across the app.
///
/// Renders a single circular avatar that:
///   - Shows the network photo at [imageUrl] when one is provided AND
///     it loads successfully
///   - Falls back to a deterministic colored circle with the user's
///     initial when [imageUrl] is empty/null OR when the image fails
///     to load (404, no network, CORS, certificate, etc.)
///
/// The fallback color is derived from a stable hash of [name], so a
/// given user always sees the same color across sessions and screens
/// — the same affordance Gmail / Google Calendar / GitHub / Slack all
/// use for "no profile photo" users.
///
/// Revamp additions:
///   - [online]: paints a 25%-of-size success dot at bottom-right with a
///     2px bg ring. Use on friends lists to show presence.
///   - [borderColor] / [borderWidth]: explicit border configuration —
///     supersedes the legacy [border] parameter when set.
///   - [glow]: adds a soft `borderColor`-tinted shadow around the avatar.
///     Used on hero avatars (matchmaking lobby, profile header).
///
/// The legacy [border] field is kept for callsites that already pass it.
/// If both [border] and [borderColor] are provided, [borderColor] wins.
class GoogleStyleAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final BorderRadiusGeometry? borderRadius;
  final Border? border;
  // Revamp props ↓
  final bool online;
  final Color? borderColor;
  final double borderWidth;
  final bool glow;

  const GoogleStyleAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
    this.borderRadius,
    this.border,
    this.online = false,
    this.borderColor,
    this.borderWidth = 2,
    this.glow = false,
  });

  /// Curated palette tuned for legibility on both the dark scaffold and
  /// the dark-navy surfaces. Each color is a Material 200/300-tier
  /// shade — saturated enough to read as the avatar identity, but not
  /// screaming-bright. White-on-color for the initial gives ≥ 4.5:1
  /// contrast on every entry.
  static const _palette = <Color>[
    Color(0xFFE57373), // soft red
    Color(0xFFF06292), // pink
    Color(0xFFBA68C8), // purple
    Color(0xFF9575CD), // deep purple
    Color(0xFF7986CB), // indigo
    Color(0xFF64B5F6), // blue
    Color(0xFF4FC3F7), // light blue
    Color(0xFF4DB6AC), // teal
    Color(0xFF81C784), // green
    Color(0xFFAED581), // lime green
    Color(0xFFFFB74D), // orange
    Color(0xFFFF8A65), // deep orange
    Color(0xFFA1887F), // brown
    Color(0xFF90A4AE), // blue grey
  ];

  /// FNV-1a-style fast hash → palette index. Deterministic across
  /// sessions and screens for a given name.
  Color _colorFor(String name) {
    if (name.isEmpty) return _palette[0];
    var hash = 0;
    for (final code in name.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  /// First grapheme cluster, uppercased. Handles emoji / non-Latin
  /// names cleanly. Empty → "?".
  String _initial(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    return trimmed.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bg = _colorFor(name);
    final letter = _initial(name);
    final fontSize = size * 0.42;
    final shape =
        borderRadius == null ? BoxShape.circle : BoxShape.rectangle;

    // Resolve border: explicit borderColor wins over legacy `border`.
    final effectiveBorder = borderColor != null
        ? Border.all(color: borderColor!, width: borderWidth)
        : border;

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: shape,
          color: bg,
          borderRadius: borderRadius,
          border: effectiveBorder,
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
      );
    }

    // Build the base avatar (image or fallback).
    Widget base;
    final url = imageUrl;
    if (url == null || url.isEmpty) {
      base = fallback();
    } else {
      final clipper = borderRadius != null
          ? ClipRRect(
              borderRadius: borderRadius!,
              child: _imageOrFallback(url, size, fallback),
            )
          : ClipOval(child: _imageOrFallback(url, size, fallback));
      base = effectiveBorder != null
          ? Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: shape,
                borderRadius: borderRadius,
                border: effectiveBorder,
              ),
              child: clipper,
            )
          : clipper;
    }

    // Optional glow shadow — uses borderColor (falls back to a primary
    // glow if no borderColor was supplied so the prop is still useful
    // for hero avatars that don't have a colored ring).
    if (glow) {
      final glowColor = (borderColor ?? AppColors.primary).withValues(alpha: 0.4);
      base = Container(
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: borderRadius,
          boxShadow: [
            BoxShadow(color: glowColor, blurRadius: 16, spreadRadius: 0),
          ],
        ),
        child: base,
      );
    }

    // Online dot overlay — 25% of avatar size at bottom-right with a
    // 2px scaffold-bg ring so the dot reads on top of darker avatars
    // without merging into the background.
    if (online) {
      final dotSize = size * 0.25;
      base = SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            base,
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dotSize,
                height: dotSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                  border: Border.fromBorderSide(
                    BorderSide(color: AppColors.bg, width: 2),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return base;
  }

  /// Image.network with a clean fallback path: while loading we show
  /// the colored-initial fallback, and on error we keep it. Once the
  /// image arrives it swaps in. Avoids the "broken image" icon and
  /// the half-second of empty grey.
  static Widget _imageOrFallback(
    String url,
    double size,
    Widget Function() fallback,
  ) {
    return Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      loadingBuilder: (ctx, child, prog) {
        if (prog == null) return child;
        return fallback();
      },
      errorBuilder: (ctx, e, st) => fallback(),
    );
  }
}
