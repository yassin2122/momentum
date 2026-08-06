import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// The three social-provider variants.
enum SocialProvider { google, apple, discord }

/// Icon-only glass button for a single OAuth provider.
///
/// Per spec §10 / §12:
/// - Same glass fill + hairline border treatment as [LabeledTextField].
/// - 14 px corner radius (matches inputs).
/// - 52 px height.
/// - Minimum 44×44 touch target regardless of visible icon size.
/// - Google: uses a styled multicolour "G" (Text widget — avoids needing
///   an SVG asset while keeping recognisability).
/// - Apple / Discord: white monochrome icon.
///
/// Press feedback: surface lightens by [AppColors.hover] overlay for 120 ms.
class SocialAuthButton extends StatefulWidget {
  const SocialAuthButton({
    required this.provider,
    required this.onPressed,
    super.key,
  });

  final SocialProvider provider;
  final VoidCallback? onPressed;

  @override
  State<SocialAuthButton> createState() => _SocialAuthButtonState();
}

class _SocialAuthButtonState extends State<SocialAuthButton> {
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
          // Glass fill matching LabeledTextField — surface at 65% opacity.
          color: _pressed
              ? AppColors.surface.withValues(alpha: 0.80)
              : AppColors.surface.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0x14FFFFFF), // 8% white hairline
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        // 44×44 minimum tap target (icon itself is ~22 px, padding makes up
        // the rest invisibly).
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: _buildIcon(),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    return switch (widget.provider) {
      SocialProvider.google => _GoogleG(),
      SocialProvider.apple => const Icon(
          Icons.apple,
          color: AppColors.white,
          size: 22,
        ),
      SocialProvider.discord => const _DiscordIcon(),
    };
  }
}

/// Multicolour Google "G" rendered as styled text — no SVG asset required,
/// stays brand-accurate and recognisable on any background.
class _GoogleG extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Text(
      'G',
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Color(0xFF4285F4), // Google Blue
        height: 1.0,
      ),
    );
  }
}

/// Minimal Discord icon drawn with a CustomPainter — a rounded rectangle
/// silhouette approximating the Discord logo glyph.  A full SVG asset
/// can replace this when assets are available.
class _DiscordIcon extends StatelessWidget {
  const _DiscordIcon();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _DiscordPainter(),
    );
  }
}

class _DiscordPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.white
      ..style = PaintingStyle.fill;

    final w = size.width;
    final h = size.height;

    // Simplified Discord "game controller" headset silhouette.
    // Body — rounded rect.
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.08, h * 0.22, w * 0.84, h * 0.56),
      Radius.circular(w * 0.22),
    );
    canvas.drawRRect(bodyRect, paint);

    // Left ear.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.01, h * 0.26, w * 0.20, h * 0.34),
      paint,
    );
    // Right ear.
    canvas.drawOval(
      Rect.fromLTWH(w * 0.79, h * 0.26, w * 0.20, h * 0.34),
      paint,
    );

    // Cut out "eyes" (the two ellipses in the Discord logo).
    final cutPaint = Paint()
      ..color = AppColors.surface.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromLTWH(w * 0.22, h * 0.34, w * 0.20, h * 0.24),
      cutPaint,
    );
    canvas.drawOval(
      Rect.fromLTWH(w * 0.58, h * 0.34, w * 0.20, h * 0.24),
      cutPaint,
    );
  }

  @override
  bool shouldRepaint(_DiscordPainter oldDelegate) => false;
}
