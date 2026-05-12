// Button family — three flavors used across the revamp:
//
//   PrimaryButton      — coral filled CTA, glow shadow, press-scale 0.97
//   OutlinedPillButton — primary outline on surfaceHi, pill-shaped
//   SecondaryButton    — surfaceHi filled, white text, subtle press
//
// All three share an identical constructor surface (label / icon /
// onPressed / loading / expanded / height) so callers can swap flavors
// by changing the type name. Loading state replaces the label with a
// 20px CircularProgressIndicator and disables onPressed so a flaky
// retry doesn't double-fire.

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Primary CTA — coral filled, glow shadow, press scale.
class PrimaryButton extends StatefulWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final double height;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.height = 56,
  });

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  bool get _disabled => widget.onPressed == null || widget.loading;

  @override
  Widget build(BuildContext context) {
    final button = AnimatedScale(
      scale: _pressed ? 0.97 : 1.0,
      duration: const Duration(milliseconds: 80),
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.lg),
          boxShadow: _disabled
              ? null
              : const [
                  BoxShadow(
                    color: AppColors.primaryGlow,
                    blurRadius: 16,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        child: Material(
          color: _disabled ? AppColors.surfaceHi : AppColors.primary,
          borderRadius: BorderRadius.circular(Radii.lg),
          child: InkWell(
            borderRadius: BorderRadius.circular(Radii.lg),
            onTap: _disabled ? null : widget.onPressed,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            child: Center(
              child: widget.loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(AppColors.textOnPri),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (widget.icon != null) ...[
                          Icon(
                            widget.icon,
                            size: 20,
                            color: _disabled
                                ? AppColors.textDim
                                : AppColors.textOnPri,
                          ),
                          const SizedBox(width: Spacing.sm),
                        ],
                        Flexible(
                          child: Text(
                            widget.label,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.h3.copyWith(
                              color: _disabled
                                  ? AppColors.textDim
                                  : AppColors.textOnPri,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
    return widget.expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Pill-shaped outlined button — primary outline on surfaceHi.
class OutlinedPillButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final double height;

  const OutlinedPillButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = false,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final button = SizedBox(
      height: height,
      child: OutlinedButton(
        onPressed: disabled ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppColors.surfaceHi,
          foregroundColor: AppColors.primary,
          disabledForegroundColor: AppColors.textDim,
          side: BorderSide(
            color: disabled ? AppColors.border : AppColors.primary,
            width: 1,
          ),
          padding: const EdgeInsets.symmetric(horizontal: Spacing.lg),
          shape: const StadiumBorder(),
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 18),
                    const SizedBox(width: Spacing.xs),
                  ],
                  Text(label, style: AppText.body.copyWith(fontWeight: FontWeight.w700)),
                ],
              ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Secondary action — surfaceHi filled, white text. Less visually
/// loud than PrimaryButton; used for "Cancel" / "Maybe later".
class SecondaryButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final double height;

  const SecondaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.height = 56,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final button = SizedBox(
      height: height,
      child: FilledButton(
        onPressed: disabled ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.surfaceHi,
          foregroundColor: AppColors.text,
          disabledBackgroundColor: AppColors.surfaceHi,
          disabledForegroundColor: AppColors.textDim,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.lg),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 20),
                    const SizedBox(width: Spacing.sm),
                  ],
                  Text(label, style: AppText.h3),
                ],
              ),
      ),
    );
    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}
