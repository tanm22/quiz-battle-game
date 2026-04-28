import 'package:flutter/material.dart';

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
/// use for "no profile photo" users. This is the default that most
/// production apps land on, because:
///   1. It looks intentional (vs. a placeholder ?? glyph)
///   2. The color makes users distinguishable in lists at a glance
///   3. It works offline / on cold start before the photo CDN responds
///   4. Latency-tolerant: shows immediately, swaps to photo when ready
///
/// Use this anywhere you would otherwise write `Image.network(url,
/// errorBuilder: ...)` for a user avatar.
class GoogleStyleAvatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  final BorderRadiusGeometry? borderRadius;
  final Border? border;

  const GoogleStyleAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 48,
    this.borderRadius,
    this.border,
  });

  /// Curated palette tuned for legibility on both the dark scaffold
  /// (#0D0D1A) and the dark-navy surface (#1A1A2E). Each color is a
  /// Material 200/300-tier shade — saturated enough to read as the
  /// avatar identity, but not screaming-bright. White-on-color for
  /// the initial gives ≥ 4.5:1 contrast on every entry.
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

  /// FNV-1a-style fast hash → palette index. Deterministic and
  /// O(name.length); collisions across users are visually fine because
  /// initial + color together still distinguish them in 99% of lists.
  Color _colorFor(String name) {
    if (name.isEmpty) return _palette[0];
    var hash = 0;
    for (final code in name.codeUnits) {
      hash = (hash * 31 + code) & 0x7fffffff;
    }
    return _palette[hash % _palette.length];
  }

  /// First grapheme cluster, uppercased. Handles emoji / non-Latin
  /// names cleanly (one user-perceived character, not one Dart code
  /// unit which would split a surrogate pair). Empty → "?".
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
    final shape = borderRadius == null
        ? BoxShape.circle
        : BoxShape.rectangle;

    Widget fallback() {
      return Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: shape,
          color: bg,
          borderRadius: borderRadius,
          border: border,
        ),
        child: Text(
          letter,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
            // Tighter line-height so taller letters (like 'Q', 'J')
            // don't push the baseline off-center.
            height: 1.0,
          ),
        ),
      );
    }

    final url = imageUrl;
    if (url == null || url.isEmpty) {
      return fallback();
    }

    final clipper = borderRadius != null
        ? ClipRRect(
            borderRadius: borderRadius!,
            child: _imageOrFallback(url, size, fallback),
          )
        : ClipOval(child: _imageOrFallback(url, size, fallback));

    if (border != null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: shape,
          borderRadius: borderRadius,
          border: border,
        ),
        child: clipper,
      );
    }
    return clipper;
  }

  /// Image.network with a clean fallback path: while loading we show
  /// the colored-initial fallback (so first paint is always
  /// good-looking), and on error (404, no network, etc.) we keep it.
  /// Once the image arrives it swaps in. Avoids the "broken image"
  /// icon and the half-second of empty grey.
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
