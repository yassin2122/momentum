import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Shared headline + subcopy pair for all auth screens.
///
/// Renamed from `AuthHeader` to `AuthHeaderText` per §8 of the design
/// spec — the `AuthHeader` name was ambiguous (it sounded like a full
/// screen header including logo); `AuthHeaderText` signals it is
/// specifically the "Welcome back!" + subtitle text block only.
///
/// Both the original class name and the new one are exported so that
/// any existing call sites using [AuthHeader] keep compiling without
/// changes — [AuthHeader] is an alias pointing to [AuthHeaderText].
class AuthHeaderText extends StatelessWidget {
  const AuthHeaderText({
    required this.title,
    required this.subtitle,
    super.key,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.headlineLarge.copyWith(
            color: AppColors.textPrimary,
            fontWeight: AppTypography.bold,
            fontSize: 24,
            letterSpacing: 0,
          ),
        )
            .animate()
            .fadeIn(duration: 300.ms)
            .slideY(begin: 0.08, end: 0, curve: Curves.easeOut),
        const SizedBox(height: AppSpacing.xs),
        Text(
          subtitle,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 15,
          ),
        )
            .animate()
            .fadeIn(delay: 100.ms, duration: 300.ms),
      ],
    );
  }
}

/// Backward-compat alias — existing call sites that import [AuthHeader]
/// continue to compile unchanged.
typedef AuthHeader = AuthHeaderText;
