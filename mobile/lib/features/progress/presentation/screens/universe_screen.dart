import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../sample/progress_sample_data.dart';
import '../widgets/game_ui.dart';

/// Galaxy I — the Calisthenics universe. Five planets (muscle groups)
/// orbit the selected one; tap a planet to bring it to the centre, then
/// enter it. Sample data (see `progress_sample_data.dart`).
class UniverseScreen extends StatefulWidget {
  const UniverseScreen({super.key});

  @override
  State<UniverseScreen> createState() => _UniverseScreenState();
}

class _UniverseScreenState extends State<UniverseScreen>
    with SingleTickerProviderStateMixin {
  String _selectedId = sampleSelectedPlanetId;

  /// Drives the orbit spin, centre float and glow pulse.
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  // Satellite slots on the 390 × 844 design canvas: (left, top, image box).
  static const _slots = <(double, double, double)>[
    (34, 196, 76),
    (262, 214, 76),
    (30, 470, 70),
    (266, 458, 76),
  ];
  static const double _centerLeft = 115;
  static const double _centerTop = 307;
  static const double _centerSize = 160;
  static const double _labelWidth = 96;

  @override
  Widget build(BuildContext context) {
    final selected = planetById(_selectedId) ?? samplePlanets.first;
    final satellites = samplePlanets.where((p) => p.id != selected.id).toList();

    return Scaffold(
      backgroundColor: AppColors.spaceBase,
      body: LayoutBuilder(
        builder: (context, c) {
          final sx = c.maxWidth / 390;
          // Compress vertically on short screens, never stretch past design.
          final sy = math.min(1.0, c.maxHeight / 844);
          final top = MediaQuery.paddingOf(context).top;
          double y(double v) => top + (v - 46) * sy;

          return SpaceBackdrop(
            nebulas: const [
              Nebula(Alignment(0.7, -0.64), 0.75, AppColors.nebulaViolet),
              Nebula(Alignment(-0.7, 0.4), 0.85, AppColors.nebulaTeal),
              Nebula(Alignment(0, -0.1), 0.6, AppColors.nebulaBlue),
            ],
            child: Stack(
              children: [
                // Orbit guide ellipse.
                Positioned(
                  left: (195 - 158) * sx,
                  top: y(385 - 190),
                  width: 316 * sx,
                  height: 380 * sy,
                  child: const IgnorePointer(
                    child: CustomPaint(painter: _DashedEllipsePainter()),
                  ),
                ),
                // Glow pulse behind the centre planet.
                Positioned(
                  left: 55 * sx,
                  top: y(245),
                  width: 280 * sx,
                  height: 280 * sx,
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _clock,
                      builder: (context, _) {
                        final t = (math.sin(_clock.value * math.pi * 20) + 1) / 2;
                        return Transform.scale(
                          scale: 1 + 0.06 * t,
                          child: Opacity(
                            opacity: 0.55 + 0.35 * t,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    selected.glow.withValues(alpha: 0.55),
                                    selected.glow.withValues(alpha: 0.18),
                                    selected.glow.withValues(alpha: 0),
                                  ],
                                  stops: const [0, 0.38, 0.68],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Two counter-rotating orbit rings.
                _ring(
                  left: 80 * sx,
                  top: y(270),
                  size: 230 * sx,
                  turnsPerLoop: 1,
                  dashed: true,
                ),
                _ring(
                  left: 100 * sx,
                  top: y(290),
                  size: 190 * sx,
                  turnsPerLoop: -2,
                  dashed: false,
                ),
                // Satellites.
                for (var i = 0; i < satellites.length && i < _slots.length; i++)
                  AnimatedPositioned(
                    key: ValueKey(satellites[i].id),
                    duration: AppConstants.animSlow,
                    curve: Curves.easeOutCubic,
                    left: _slots[i].$1 * sx,
                    top: y(_slots[i].$2),
                    width: _labelWidth * sx,
                    child: _Satellite(
                      planet: satellites[i],
                      imageSize: _slots[i].$3 * sx,
                      onTap: () =>
                          setState(() => _selectedId = satellites[i].id),
                    ),
                  ),
                // Selected planet, floating.
                AnimatedPositioned(
                  key: ValueKey(selected.id),
                  duration: AppConstants.animSlow,
                  curve: Curves.easeOutCubic,
                  left: _centerLeft * sx,
                  top: y(_centerTop),
                  width: _centerSize * sx,
                  height: _centerSize * sx,
                  child: AnimatedBuilder(
                    animation: _clock,
                    builder: (context, child) {
                      final t = math.sin(_clock.value * math.pi * 16);
                      return Transform.translate(
                        offset: Offset(0, -3.5 - 3.5 * t),
                        child: child,
                      );
                    },
                    child: Semantics(
                      button: true,
                      label: '${selected.name} planet, selected',
                      child: GestureDetector(
                        onTap: () =>
                            context.push(AppRoutes.planetPath(selected.id)),
                        child: _PlanetArt(
                          image: selected.image,
                          glow: selected.glow,
                          strong: true,
                        ),
                      ),
                    ),
                  ),
                ),
                // HUD.
                Positioned(
                  left: AppSpacing.sm + 2,
                  right: AppSpacing.sm + 2,
                  top: top + AppSpacing.xxs,
                  child: Row(
                    children: [
                      HudCapsule(
                        icon: LucideIcons.flame,
                        iconColor: AppColors.streakFlameStart,
                        label: '${sampleHud.streakDays}',
                        semanticLabel: '${sampleHud.streakDays} day streak',
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      HudCapsule(
                        icon: LucideIcons.zap,
                        iconColor: AppColors.gameBlueLight,
                        label: groupThousands(sampleHud.xp),
                        semanticLabel: '${sampleHud.xp} XP',
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      HudCapsule(
                        icon: LucideIcons.star,
                        iconColor: AppColors.gameGold,
                        label: '${sampleHud.stars}',
                        semanticLabel: '${sampleHud.stars} stars earned',
                      ),
                      const Spacer(),
                      HudCapsule(
                        icon: LucideIcons.trophy,
                        iconColor: AppColors.gameGoldLight,
                        label: 'Badges',
                        semanticLabel: 'Achievements',
                        onTap: () => context.go(AppRoutes.achievements),
                      ),
                    ],
                  ),
                ),
                // Title + locked galaxies.
                Positioned(
                  left: AppSpacing.md + 2,
                  right: AppSpacing.sm + 2,
                  top: y(98),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Galaxy I',
                              style: AppTypography.labelLarge
                                  .copyWith(color: AppColors.gameTextSubtle),
                            ),
                            Text(
                              'Foundations',
                              style: AppTypography.displaySmall.copyWith(
                                color: AppColors.hubTextBright,
                                fontWeight: AppTypography.extraBold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _LockedGalaxiesChip(
                        onTap: () => context.go(AppRoutes.progress),
                      ),
                    ],
                  ),
                ),
                // Selected-planet panel.
                Positioned(
                  left: AppSpacing.sm + 2,
                  right: AppSpacing.sm + 2,
                  bottom: kNavClearance - AppSpacing.lg,
                  child: _SelectedPanel(planet: selected),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _ring({
    required double left,
    required double top,
    required double size,
    required double turnsPerLoop,
    required bool dashed,
  }) {
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: IgnorePointer(
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, child) => Transform.rotate(
            angle: _clock.value * math.pi * 2 * turnsPerLoop,
            child: child,
          ),
          child: CustomPaint(painter: _OrbitRingPainter(dashed: dashed)),
        ),
      ),
    );
  }
}

class _PlanetArt extends StatelessWidget {
  const _PlanetArt({
    required this.image,
    required this.glow,
    this.strong = false,
  });

  final String image;
  final Color glow;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: glow.withValues(alpha: strong ? 0.55 : 0.35),
            blurRadius: strong ? 34 : 18,
            spreadRadius: strong ? -6 : -4,
          ),
        ],
      ),
      child: Image.asset(
        image,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: glow),
        ),
      ),
    );
  }
}

class _Satellite extends StatelessWidget {
  const _Satellite({
    required this.planet,
    required this.imageSize,
    required this.onTap,
  });

  final SkillPlanet planet;
  final double imageSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pct = (planet.progress * 100).round();
    return Semantics(
      button: true,
      label: '${planet.name} planet, $pct percent',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: imageSize,
              child: _PlanetArt(image: planet.image, glow: planet.glow),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              planet.name,
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.hubTextBright,
                fontWeight: AppTypography.bold,
              ),
            ),
            Text(
              '$pct%',
              style: AppTypography.numeric(AppTypography.labelMedium).copyWith(
                color: AppColors.hubSkyLight,
                fontWeight: AppTypography.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LockedGalaxiesChip extends StatelessWidget {
  const _LockedGalaxiesChip({required this.onTap});

  final VoidCallback onTap;

  static const List<double> _grayscale = [
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0, //
    0, 0, 0, 0.55, 0,
  ];

  Widget _thumb(String image) => ColorFiltered(
        colorFilter: const ColorFilter.matrix(_grayscale),
        child: Image.asset(
          image,
          width: AppSpacing.lg + 4,
          height: AppSpacing.lg + 4,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Semantics(
      button: true,
      label: 'Galaxies II and III are locked',
      excludeSemantics: true,
      child: Material(
        color: AppColors.hudFill,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.hubNavBorder),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxs + 2,
              AppSpacing.xxs + 1,
              AppSpacing.sm - 2,
              AppSpacing.xxs + 1,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _thumb(ProgressArt.planetLockedA),
                Transform.translate(
                  offset: const Offset(-AppSpacing.xs, 0),
                  child: _thumb(ProgressArt.planetLockedB),
                ),
                const Icon(
                  LucideIcons.lock,
                  size: AppSizing.iconSm - 4,
                  color: AppColors.gameTextSubtle,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '2 locked',
                  style: AppTypography.labelMedium
                      .copyWith(color: AppColors.gameTextSubtle),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedPanel extends StatelessWidget {
  const _SelectedPanel({required this.planet});

  final SkillPlanet planet;

  @override
  Widget build(BuildContext context) {
    final pct = (planet.progress * 100).round();
    return AnimatedSwitcher(
      duration: AppConstants.animMedium,
      child: Container(
        key: ValueKey(planet.id),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.large),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gamePanelTop, AppColors.gamePanelBottom],
          ),
          border: Border.all(
            color: AppColors.hubEyebrow.withValues(alpha: 0.3),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.gameBlue.withValues(alpha: 0.18),
              blurRadius: 40,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    '${planet.name} planet',
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.hubTextBright,
                      fontWeight: AppTypography.extraBold,
                    ),
                  ),
                ),
                Text(
                  '$pct%',
                  style: AppTypography.numeric(AppTypography.headlineMedium)
                      .copyWith(
                    color: AppColors.hubEyebrow,
                    fontWeight: AppTypography.extraBold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm - 2),
            Row(
              children: [
                Text(
                  '${planet.certified} of ${planet.skills.length} skills '
                  'certified',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.gameTextBody),
                ),
                const SizedBox(width: AppSpacing.sm - 2),
                const Icon(
                  Icons.star_rounded,
                  size: AppSizing.iconSm - 2,
                  color: AppColors.gameGoldLight,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '${planet.stars} of ${planet.totalStars} stars',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.gameGoldLight,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm - 2),
            GameCtaButton(
              label: 'Enter ${planet.name} planet',
              onTap: () => context.push(AppRoutes.planetPath(planet.id)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glowing blue game CTA ("Enter Pull planet").
class GameCtaButton extends StatelessWidget {
  const GameCtaButton({required this.label, required this.onTap, super.key});

  final String label;
  final VoidCallback onTap;

  static const double _height = 50;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.hubCard);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: AppShadows.gameBlueGlow,
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Ink(
            height: _height,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.hubEyebrow, AppColors.gameBlueDeep],
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.white,
                  fontWeight: AppTypography.extraBold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedEllipsePainter extends CustomPainter {
  const _DashedEllipsePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.gamePathDash.withValues(alpha: 0.16);
    final path = Path()..addOval(Offset.zero & size);
    _drawDashed(canvas, path, paint, 3, 7);
  }

  @override
  bool shouldRepaint(_DashedEllipsePainter oldDelegate) => false;
}

class _OrbitRingPainter extends CustomPainter {
  const _OrbitRingPainter({required this.dashed});

  final bool dashed;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2 * (dashed ? 108 / 115 : 90 / 95);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = dashed ? 1.5 : 1
      ..color = dashed
          ? AppColors.hubSkyLight.withValues(alpha: 0.55)
          : AppColors.hubEyebrow.withValues(alpha: 0.35);
    final path = Path()..addOval(Rect.fromCircle(center: c, radius: r));
    if (dashed) {
      _drawDashed(canvas, path, paint, 4, 10);
      // The little moon riding the outer ring.
      canvas.drawCircle(
        Offset(c.dx, c.dy - r),
        4,
        Paint()..color = AppColors.white,
      );
    } else {
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbitRingPainter oldDelegate) =>
      oldDelegate.dashed != dashed;
}

void _drawDashed(Canvas canvas, Path path, Paint paint, double on, double off) {
  for (final metric in path.computeMetrics()) {
    var d = 0.0;
    while (d < metric.length) {
      canvas.drawPath(metric.extractPath(d, d + on), paint);
      d += on + off;
    }
  }
}
