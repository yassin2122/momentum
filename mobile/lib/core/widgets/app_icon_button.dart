import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Standard circular icon-only button. Always meets the minimum touch
/// target regardless of the icon's own size, per the large-touch-target
/// design principle.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.size = AppSizing.iconMd,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;

  /// True for a `surface`-filled circular background (e.g. floating over
  /// content); false for a bare icon (e.g. inside an app bar).
  final bool filled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: filled ? AppColors.surface : Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: AppSizing.minTouchTarget,
          height: AppSizing.minTouchTarget,
          child: Icon(
            icon,
            size: size,
            color: onPressed == null
                ? AppColors.textDisabled
                : AppColors.textPrimary,
          ),
        ),
      ),
    );

    return button;
  }
}
