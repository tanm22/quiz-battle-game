import 'package:flutter/material.dart';

/// Renders an avatar locally as a colored circle with the first letter of
/// the seed. No network call, no image decode — always works on every
/// device regardless of network or image-load state.
///
/// We still save a real URL (UI Avatars) to the backend for the
/// `user.avatarUrl` field; this widget is purely a render-side choice
/// so previews are reliable on the device while the saved URL stays
/// usable by any future client that wants to actually fetch an image.
class LocalAvatar extends StatelessWidget {
  /// Single character to render in the center. Capitalized automatically.
  final String letter;
  final Color background;
  final double size;
  final BorderRadiusGeometry? borderRadius;

  const LocalAvatar({
    super.key,
    required this.letter,
    required this.background,
    this.size = 64,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final shape = borderRadius == null ? BoxShape.circle : BoxShape.rectangle;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: borderRadius,
        color: background,
      ),
      child: Text(
        letter.isEmpty ? '?' : letter[0].toUpperCase(),
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.42,
          letterSpacing: 0,
        ),
      ),
    );
  }
}
