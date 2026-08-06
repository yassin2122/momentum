import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

enum SocialTileProvider { apple, google, email }

/// Styled full-width glass button for social/alternative sign in options:
/// "Continue with Apple", "Continue with Google", "Continue with Email".
class SocialAuthButtonTile extends StatefulWidget {
  const SocialAuthButtonTile({
    required this.provider,
    required this.onPressed,
    this.labelOverride,
    super.key,
  });

  final SocialTileProvider provider;
  final VoidCallback? onPressed;
  final String? labelOverride;

  @override
  State<SocialAuthButtonTile> createState() => _SocialAuthButtonTileState();
}

class _SocialAuthButtonTileState extends State<SocialAuthButtonTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        height: 52,
        decoration: BoxDecoration(
          color: _pressed
              ? AppColors.surface.withValues(alpha: 0.85)
              : AppColors.surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0x14FFFFFF),
            width: 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Text(
              widget.labelOverride ?? _labelForProvider(widget.provider),
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: AppTypography.semiBold,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _labelForProvider(SocialTileProvider provider) {
    return switch (provider) {
      SocialTileProvider.apple => 'Continue with Apple',
      SocialTileProvider.google => 'Continue with Google',
      SocialTileProvider.email => 'Continue with Email',
    };
  }

  Widget _buildIcon() {
    return switch (widget.provider) {
      SocialTileProvider.apple => const Icon(
          Icons.apple,
          color: AppColors.white,
          size: 22,
        ),
      SocialTileProvider.google => const Text(
          'G',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF4285F4),
            height: 1.0,
          ),
        ),
      SocialTileProvider.email => const Icon(
          Icons.email_outlined,
          color: AppColors.white,
          size: 20,
        ),
    };
  }
}
