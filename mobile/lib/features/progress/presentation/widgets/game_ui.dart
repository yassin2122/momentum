import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Shared pieces for the game screens (Universe, Planet): the deep-space
/// backdrop and the HUD capsules.

/// One soft nebula wash on the space backdrop.
final class Nebula {
  const Nebula(this.center, this.radius, this.color);

  final Alignment center;
  final double radius;
  final Color color;
}

/// Deep-space canvas: base colour, nebula washes and a scatter of stars.
class SpaceBackdrop extends StatelessWidget {
  const SpaceBackdrop({required this.nebulas, this.child, super.key});

  final List<Nebula> nebulas;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: AppColors.spaceBase),
        for (final n in nebulas)
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: n.center,
                radius: n.radius,
                colors: [n.color, n.color.withValues(alpha: 0)],
                stops: const [0, 0.7],
              ),
            ),
          ),
        const CustomPaint(painter: _StarsPainter()),
        if (child != null) child!,
      ],
    );
  }
}

class _StarsPainter extends CustomPainter {
  const _StarsPainter();

  // (x, y, radius, opacity) on the 390 × 844 design canvas.
  static const _stars = <(double, double, double, double)>[
    (22, 140, 1, .7),
    (64, 300, .8, .5),
    (120, 180, 1.2, .6),
    (250, 150, .8, .6),
    (352, 320, 1.1, .7),
    (300, 410, .7, .5),
    (40, 430, 1, .6),
    (160, 590, .8, .5),
    (370, 560, 1.2, .6),
    (210, 250, .6, .5),
    (90, 610, 1, .4),
    (330, 200, .7, .6),
    (18, 560, .8, .5),
    (276, 560, .9, .5),
    (185, 140, 1, .5),
    (30, 720, .9, .5),
    (240, 690, .7, .4),
    (350, 780, 1, .5),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 390;
    final sy = size.height / 844;
    final paint = Paint();
    for (final (x, y, r, o) in _stars) {
      paint.color = AppColors.gameStar.withValues(alpha: o);
      canvas.drawCircle(Offset(x * sx, y * sy), r, paint);
    }
  }

  @override
  bool shouldRepaint(_StarsPainter oldDelegate) => false;
}

/// Rounded translucent capsule used in the game HUD.
class HudCapsule extends StatelessWidget {
  const HudCapsule({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.semanticLabel,
    this.onTap,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String semanticLabel;
  final VoidCallback? onTap;

  static const double height = 34;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: AppColors.hudFill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.hudBorder),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: SizedBox(
            height: height,
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.xs,
                right: AppSpacing.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: AppSizing.iconSm + 2, color: iconColor),
                  const SizedBox(width: AppSpacing.xxs + 2),
                  Text(
                    label,
                    style: AppTypography.numeric(AppTypography.labelLarge)
                        .copyWith(
                      color: AppColors.hubTextBright,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled gold star / dim star row for a skill's tier (0–3).
class TierStars extends StatelessWidget {
  const TierStars({required this.count, this.size = 12, super.key});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$count of 3 stars',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Icon(
              Icons.star_rounded,
              size: size,
              color: i < count
                  ? AppColors.gameGold
                  : AppColors.white.withValues(alpha: 0.18),
            ),
        ],
      ),
    );
  }
}

/// Formats 3420 → "3,420".
String groupThousands(int value) {
  final s = value.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}
