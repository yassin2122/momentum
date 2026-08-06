import 'package:flutter/material.dart';
import '../../../../core/theme/app_spacing.dart';
import 'social_auth_button_tile.dart';

/// Full-width social auth options list:
/// - Continue with Apple
/// - Continue with Google
/// - Continue with Email
class SocialAuthRow extends StatelessWidget {
  const SocialAuthRow({
    this.onGooglePressed,
    this.onApplePressed,
    this.onEmailPressed,
    this.onDiscordPressed,
    super.key,
  });

  final VoidCallback? onGooglePressed;
  final VoidCallback? onApplePressed;
  final VoidCallback? onEmailPressed;
  final VoidCallback? onDiscordPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SocialAuthButtonTile(
          provider: SocialTileProvider.apple,
          onPressed: onApplePressed,
        ),
        const SizedBox(height: AppSpacing.sm),
        SocialAuthButtonTile(
          provider: SocialTileProvider.google,
          onPressed: onGooglePressed,
        ),
        const SizedBox(height: AppSpacing.sm),
        SocialAuthButtonTile(
          provider: SocialTileProvider.email,
          onPressed: onEmailPressed,
        ),
      ],
    );
  }
}
