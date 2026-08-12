import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Centered footer row — e.g. "Don't have an account? Sign up".
/// [onLinkTap] fires only when the styled link portion is tapped, not
/// the surrounding body text.
class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    super.key,
    required this.bodyText,
    required this.linkText,
    required this.onLinkTap,
  });

  final String bodyText;
  final String linkText;
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            '$bodyText ',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          GestureDetector(
            onTap: onLinkTap,
            child: Text(
              linkText,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.accentLink,
                fontWeight: AppTypography.semiBold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
