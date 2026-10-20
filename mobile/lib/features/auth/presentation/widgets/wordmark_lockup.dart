import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Brand wordmark + tagline stacked lockup, centred.
///
/// "GRIT" is rendered as tracked-out bold caps — a logotype treatment,
/// not a headline — per §3 of the spec.  The tagline below uses
/// [AppColors.textSecondary] at a quieter weight so it reads as a brand
/// promise rather than a UI label.
///
/// Both elements are static; animation is handled by the parent
/// [LoginScreen]'s staggered entrance.
class WordmarkLockup extends StatelessWidget {
  const WordmarkLockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Wordmark ─────────────────────────────────────────────────────
        // displayMedium (34 px, 700) + aggressive letter-spacing matches
        // "32–34 px / Bold / +6–8%" from spec §3.
        Text(
          'GRIT',
          style: AppTypography.displayMedium.copyWith(
            letterSpacing: 34 * 0.07, // 7% of fontSize ≈ 2.38 px
            color: AppColors.textPrimary,
            fontWeight: AppTypography.bold,
          ),
        ),
        const SizedBox(height: 4),
        // ── Tagline ──────────────────────────────────────────────────────
        Text(
          'Train. Progress. Become.',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 15,
            fontWeight: AppTypography.regular,
            letterSpacing: 0,
          ),
        ),
      ],
    );
  }
}
