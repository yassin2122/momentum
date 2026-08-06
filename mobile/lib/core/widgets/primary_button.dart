import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Standard primary call-to-action button for the whole app.
///
/// Shows a loading spinner in place of the label when [isLoading] is true,
/// and disables tap handling while loading to prevent double-submits.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    this.variant = PrimaryButtonVariant.filled,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;
  final PrimaryButtonVariant variant;

  bool get _canTap => isEnabled && !isLoading && onPressed != null;

  @override
  Widget build(BuildContext context) {
    final isFilled = variant == PrimaryButtonVariant.filled;

    return SizedBox(
      height: AppSizing.buttonHeight,
      child: ElevatedButton(
        onPressed: _canTap ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFilled ? AppColors.primary : Colors.transparent,
          disabledBackgroundColor:
              isFilled ? AppColors.primaryMuted : Colors.transparent,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          side: isFilled
              ? BorderSide.none
              : const BorderSide(color: AppColors.stroke),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isLoading
              ? const SizedBox(
                  key: ValueKey('loading'),
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.textPrimary),
                  ),
                )
              : Text(
                  label,
                  key: const ValueKey('label'),
                  style: AppTypography.button,
                ),
        ),
      ),
    );
  }
}

enum PrimaryButtonVariant { filled, outlined }
