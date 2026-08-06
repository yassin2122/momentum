import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Mixed-weight footer prompt: body text + tappable link in one line.
///
/// "Don't have an account? **Sign up**" — the link portion renders
/// at medium weight in [AppColors.accentLink] and uses a
/// [TapGestureRecognizer] so the tap target covers only the link word,
/// not the whole line.
///
/// [bodyText] and [linkText] are separate so the widget is reusable for
/// Sign Up → Log In, Forgot Password → back, etc.
class AuthFooterPrompt extends StatelessWidget {
  const AuthFooterPrompt({
    required this.bodyText,
    required this.linkText,
    required this.onLinkTap,
    super.key,
  });

  final String bodyText;
  final String linkText;
  final VoidCallback onLinkTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: RichText(
        text: TextSpan(
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
          children: [
            TextSpan(text: '$bodyText '),
            TextSpan(
              text: linkText,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.accentLink,
                fontSize: 14,
                fontWeight: AppTypography.medium,
              ),
              recognizer: TapGestureRecognizer()..onTap = onLinkTap,
            ),
          ],
        ),
      ),
    );
  }
}
