import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Social sign-in cluster: Apple + Google side by side, then a
/// full-width "Continue with Email" row beneath. Bundled into one
/// widget (rather than three separate ones) because the three options
/// always appear together as a single decision block on the auth
/// screen.
class SocialAuthRow extends StatelessWidget {
  const SocialAuthRow({
    super.key,
    required this.onApplePressed,
    required this.onGooglePressed,
    required this.onEmailPressed,
  });

  final VoidCallback onApplePressed;
  final VoidCallback onGooglePressed;
  final VoidCallback onEmailPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _OutlinedAuthButton(
                onPressed: onApplePressed,
                label: 'Continue with Apple',
                leading: const Icon(
                  Icons.apple,
                  size: AppSizing.iconMd,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _OutlinedAuthButton(
                onPressed: onGooglePressed,
                label: 'Continue with Google',
                leading: Image.asset(
                  'assets/images/auth/google_icon.png',
                  height: AppSizing.iconMd,
                  width: AppSizing.iconMd,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _OutlinedAuthButton(
          onPressed: onEmailPressed,
          label: 'Continue with Email',
          leading: const Icon(
            Icons.mail_outline_rounded,
            size: AppSizing.iconMd,
            color: AppColors.textPrimary,
          ),
          fullWidth: true,
        ),
      ],
    );
  }
}

class _OutlinedAuthButton extends StatelessWidget {
  const _OutlinedAuthButton({
    required this.onPressed,
    required this.label,
    required this.leading,
    this.fullWidth = false,
  });

  final VoidCallback onPressed;
  final String label;
  final Widget leading;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: AppSizing.buttonHeight,
      width: fullWidth ? double.infinity : null,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.stroke),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                leading,
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: AppTypography.medium,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
