import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_sizing.dart';
import '../theme/app_typography.dart';

/// Standard primary call-to-action button for the whole app.
///
/// The filled variant is the brand pill from the Login "LOG IN" button:
/// an orange → coral → teal gradient with a soft two-tone glow. The
/// outlined variant is the same pill shape with a faint stroke.
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

  /// The brand CTA gradient, left to right.
  static const LinearGradient gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      AppColors.ctaGradientStart,
      AppColors.ctaGradientMid,
      AppColors.ctaGradientEnd,
    ],
  );

  @override
  Widget build(BuildContext context) {
    final isFilled = variant == PrimaryButtonVariant.filled;
    final radius = BorderRadius.circular(AppRadius.pill);
    // Dim only when truly disabled; a loading button keeps full colour.
    final dimmed = !isLoading && !_canTap;

    return Opacity(
      opacity: dimmed ? 0.5 : 1,
      child: Container(
        height: AppSizing.buttonHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: isFilled ? gradient : null,
          border: isFilled ? null : Border.all(color: AppColors.stroke),
          boxShadow: isFilled && !dimmed ? AppShadows.ctaGlow : null,
        ),
        child: Material(
          color: AppColors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: _canTap ? onPressed : null,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: isLoading
                    ? const SizedBox(
                        key: ValueKey('loading'),
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textPrimary),
                        ),
                      )
                    : Text(
                        label,
                        key: const ValueKey('label'),
                        style: AppTypography.button.copyWith(
                          color: AppColors.textPrimary,
                          letterSpacing: 0.4,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum PrimaryButtonVariant { filled, outlined }
