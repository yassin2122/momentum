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

/// A planet's level path: seven skill nodes climbing from the bottom, the
/// current one in spinning gold, the rest blue (done) or grey (locked),
/// plus the violet elite trial branch. Sample data.
class PlanetScreen extends StatefulWidget {
  const PlanetScreen({required this.planetId, super.key});

  final String planetId;

  @override
  State<PlanetScreen> createState() => _PlanetScreenState();
}

/// Node layout on the 390 × 844 design canvas: centre and label side.
final class _NodeSpot {
  const _NodeSpot(this.x, this.y, {this.labelRight = true});

  final double x;
  final double y;
  final bool labelRight;
}

class _PlanetScreenState extends State<PlanetScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );

  static const _spots = [
    _NodeSpot(200, 738),
    _NodeSpot(282, 640, labelRight: false),
    _NodeSpot(170, 556),
    _NodeSpot(88, 462),
    _NodeSpot(190, 372),
    _NodeSpot(282, 268, labelRight: false),
    _NodeSpot(180, 160),
  ];
  static const _elite = _NodeSpot(318, 470);

  /// The elite branch leaves from this node.
  static const int _eliteFrom = 4;

  static const double _doneSize = 52;
  static const double _currentSize = 60;
  static const double _lockedSize = 46;
  static const double _calloutWidth = 188;

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

  void _back() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.universe);

  void _openSkill(PlanetSkill s) => context.push(AppRoutes.skillPath(s.id));

  @override
  Widget build(BuildContext context) {
    final planet = planetById(widget.planetId);
    if (planet == null) {
      return HubPage(
        bottomPadding: AppSpacing.xl,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: HubBackButton(onPressed: _back),
          ),
          const SizedBox(height: AppSpacing.md),
          const HubMessageCard(
            icon: LucideIcons.orbit,
            title: 'Planet not found',
            message: 'This planet isn\'t on your map yet.',
          ),
        ],
      );
    }

    final currentIndex =
        planet.skills.indexWhere((s) => s.state == SkillNodeState.current);

    return Scaffold(
      backgroundColor: AppColors.spaceBase,
      body: LayoutBuilder(
        builder: (context, c) {
          final sx = c.maxWidth / 390;
          final sy = c.maxHeight / 844;
          Offset at(_NodeSpot s) => Offset(s.x * sx, s.y * sy);
          final points = [for (final s in _spots) at(s)];
          final top = MediaQuery.paddingOf(context).top;

          return SpaceBackdrop(
            nebulas: const [
              Nebula(Alignment(-0.6, -0.5), 0.6, AppColors.nebulaGreen),
              Nebula(Alignment(0.6, 0.1), 0.7, AppColors.nebulaIndigo),
              Nebula(Alignment(0, 1), 0.8, AppColors.nebulaDeep),
            ],
            child: Stack(
              children: [
                // Home planet looming bottom-left, a neighbour far away.
                Positioned(
                  left: -150 * sx,
                  top: 560 * sy,
                  width: 360 * sx,
                  height: 352 * sx,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.85,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: planet.glow.withValues(alpha: 0.45),
                              blurRadius: 60,
                              spreadRadius: -20,
                            ),
                          ],
                        ),
                        child: Image.asset(
                          planet.image,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
                    ),
                  ),
                ),
                // Path.
                Positioned.fill(
                  child: IgnorePointer(
                    child: AnimatedBuilder(
                      animation: _clock,
                      builder: (context, _) => CustomPaint(
                        painter: _PathPainter(
                          points: points,
                          litUpTo: currentIndex < 0
                              ? points.length - 1
                              : currentIndex,
                          elite: at(_elite),
                          eliteFrom: points[_eliteFrom],
                          flow: _clock.value * 25,
                        ),
                      ),
                    ),
                  ),
                ),
                // Nodes and labels.
                for (var i = 0; i < planet.skills.length && i < _spots.length; i++)
                  ..._node(planet.skills[i], i, points[i], c.maxWidth),
                // Elite trial.
                ..._eliteTrial(planet, at(_elite)),
                // Header.
                Positioned(
                  left: AppSpacing.sm + 2,
                  right: AppSpacing.sm + 2,
                  top: top + AppSpacing.xxs,
                  child: Row(
                    children: [
                      HubBackButton(
                        onPressed: _back,
                        fill: AppColors.hudFill,
                        semanticLabel: 'Back to universe',
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${planet.name} planet',
                              style: AppTypography.headlineMedium.copyWith(
                                color: AppColors.hubTextBright,
                                fontWeight: AppTypography.extraBold,
                              ),
                            ),
                            Text(
                              'Galaxy I · ${planet.certified} of '
                              '${planet.skills.length} certified',
                              style: AppTypography.labelMedium
                                  .copyWith(color: AppColors.gameTextSubtle),
                            ),
                          ],
                        ),
                      ),
                      HudCapsule(
                        icon: Icons.star_rounded,
                        iconColor: AppColors.gameGold,
                        label: '${planet.stars}/${planet.totalStars}',
                        semanticLabel:
                            '${planet.stars} of ${planet.totalStars} stars',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _node(PlanetSkill s, int i, Offset p, double width) {
    final spot = _spots[i];
    switch (s.state) {
      case SkillNodeState.done:
        return [
          _centered(
            p,
            _doneSize,
            _DoneNode(number: i + 1, onTap: () => _openSkill(s), skill: s),
          ),
          _label(p, _doneSize, spot.labelRight,
              _NodeLabel(name: s.name, stars: s.tier.stars, starsFirst: !spot.labelRight)),
        ];
      case SkillNodeState.locked:
        return [
          _centered(p, _lockedSize, _LockedNode(skill: s)),
          _label(p, _lockedSize, spot.labelRight,
              _NodeLabel(name: s.name, locked: true, starsFirst: !spot.labelRight)),
        ];
      case SkillNodeState.current:
        final ringBox = _currentSize * 104 / 60;
        final calloutLeft = p.dx > width / 2
            ? AppSpacing.md + 6
            : p.dx + ringBox / 2 + AppSpacing.xs;
        return [
          // Warm glow.
          Positioned(
            left: p.dx - 60,
            top: p.dy - 60,
            width: 120,
            height: 120,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.gameGold.withValues(alpha: 0.45),
                      AppColors.gameGold.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.65],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: p.dx - ringBox / 2,
            top: p.dy - ringBox / 2,
            width: ringBox,
            height: ringBox,
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _clock,
                builder: (context, _) => CustomPaint(
                  painter: _CurrentRingsPainter(_clock.value),
                ),
              ),
            ),
          ),
          _centered(
            p,
            _currentSize,
            _CurrentNode(number: i + 1, onTap: () => _openSkill(s), skill: s),
          ),
          Positioned(
            left: calloutLeft,
            top: p.dy - 46,
            width: _calloutWidth,
            child: _CurrentCallout(skill: s, onContinue: () => _openSkill(s)),
          ),
        ];
    }
  }

  List<Widget> _eliteTrial(SkillPlanet planet, Offset p) {
    const w = 60.0;
    const h = 66.0;
    final unlocked = planet.eliteUnlocked;
    return [
      Positioned(
        left: p.dx - w / 2,
        top: p.dy - h / 2,
        width: w,
        height: h,
        child: Semantics(
          button: true,
          label: unlocked
              ? planet.eliteTrialName
              : '${planet.eliteTrialName}, locked until Master',
          excludeSemantics: true,
          child: GestureDetector(
            onTap: () => ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(
                    unlocked
                        ? 'Elite trials open in a future update.'
                        : 'Reach Master on every skill here to unlock the '
                            'elite trial.',
                  ),
                ),
              ),
            child: CustomPaint(painter: _HexPainter(locked: !unlocked)),
          ),
        ),
      ),
      Positioned(
        left: p.dx - 48,
        top: p.dy + h / 2 + AppSpacing.xxs,
        width: 96,
        child: IgnorePointer(
          child: Column(
            children: [
              Text(
                planet.eliteTrialName,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.hubTextBright,
                  fontWeight: AppTypography.bold,
                ),
              ),
              Text(
                unlocked ? 'Ready' : 'Unlocks at Master',
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.gameEliteText),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _centered(Offset p, double size, Widget child) => Positioned(
        left: p.dx - size / 2,
        top: p.dy - size / 2,
        width: size,
        height: size,
        child: child,
      );

  Widget _label(Offset p, double nodeSize, bool right, Widget child) {
    const labelHeight = 30.0;
    final gap = nodeSize / 2 + AppSpacing.xs;
    return Positioned(
      left: right ? p.dx + gap : null,
      right: right ? null : MediaQuery.sizeOf(context).width - p.dx + gap,
      top: p.dy - labelHeight / 2,
      height: labelHeight,
      child: IgnorePointer(child: child),
    );
  }
}

class _DoneNode extends StatelessWidget {
  const _DoneNode({
    required this.number,
    required this.onTap,
    required this.skill,
  });

  final int number;
  final VoidCallback onTap;
  final PlanetSkill skill;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Skill $number, ${skill.name}, ${skill.tier.label}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gameBlueLight, width: 3),
            gradient: const RadialGradient(
              center: Alignment(0, -0.3),
              colors: [
                AppColors.gameBlueDeep,
                AppColors.gameNodeMid,
                AppColors.gameNodeEdge,
              ],
              stops: [0, 0.6, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.gameBlue.withValues(alpha: 0.2),
                spreadRadius: 5,
              ),
              BoxShadow(
                color: AppColors.gameBlue.withValues(alpha: 0.67),
                blurRadius: 22,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: AppTypography.titleLarge.copyWith(
              color: AppColors.white,
              fontWeight: AppTypography.extraBold,
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentNode extends StatelessWidget {
  const _CurrentNode({
    required this.number,
    required this.onTap,
    required this.skill,
  });

  final int number;
  final VoidCallback onTap;
  final PlanetSkill skill;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Skill $number, ${skill.name}, in progress',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.gameGoldPale, width: 3),
            gradient: const RadialGradient(
              center: Alignment(0, -0.3),
              colors: [
                AppColors.gameGoldLight,
                AppColors.gameGoldDeep,
                AppColors.gameGoldDark,
              ],
              stops: [0, 0.55, 1],
            ),
            boxShadow: AppShadows.gameGoldGlow,
          ),
          alignment: Alignment.center,
          child: Text(
            '$number',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.white,
              fontWeight: AppTypography.extraBold,
              shadows: const [
                Shadow(color: AppColors.gameGoldDark, blurRadius: 3),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LockedNode extends StatelessWidget {
  const _LockedNode({required this.skill});

  final PlanetSkill skill;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${skill.name}, locked',
      excludeSemantics: true,
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.gameLockedBorder, width: 2),
          ),
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            colors: [AppColors.gameLockedTop, AppColors.gameLockedBottom],
          ),
        ),
        child: const Icon(
          LucideIcons.lock,
          size: AppSizing.iconSm,
          color: AppColors.gameLockedText,
        ),
      ),
    );
  }
}

class _NodeLabel extends StatelessWidget {
  const _NodeLabel({
    required this.name,
    this.stars = 0,
    this.locked = false,
    this.starsFirst = false,
  });

  final String name;
  final int stars;
  final bool locked;
  final bool starsFirst;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      style: AppTypography.labelLarge.copyWith(
        color: locked ? AppColors.gameLockedText : AppColors.hubTextBright,
        fontWeight: AppTypography.semiBold,
      ),
    );
    final starRow = TierStars(count: stars);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm - 2),
      decoration: BoxDecoration(
        color: locked ? AppColors.hudFill : AppColors.gameLabelFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
          color: AppColors.white.withValues(alpha: locked ? 0.07 : 0.1),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: locked
            ? [text]
            : starsFirst
                ? [starRow, const SizedBox(width: AppSpacing.xs - 1), text]
                : [text, const SizedBox(width: AppSpacing.xs - 1), starRow],
      ),
    );
  }
}

class _CurrentCallout extends StatelessWidget {
  const _CurrentCallout({required this.skill, required this.onContinue});

  final PlanetSkill skill;
  final VoidCallback onContinue;

  static const double _ctaHeight = 34;

  @override
  Widget build(BuildContext context) {
    final pct = (skill.progress * 100).round();
    final radius = BorderRadius.circular(AppRadius.medium - 1);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md - 2,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.gamePanelBottom,
        borderRadius: BorderRadius.circular(AppRadius.hubCard),
        border: Border.all(color: AppColors.gameGold.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppColors.gameGoldDeep.withValues(alpha: 0.18),
            blurRadius: 24,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  skill.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.extraBold,
                  ),
                ),
              ),
              Text(
                '$pct%',
                style: AppTypography.numeric(AppTypography.labelLarge).copyWith(
                  color: AppColors.gameGoldLight,
                  fontWeight: AppTypography.extraBold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs - 2),
          HubProgressBar(
            value: skill.progress,
            height: 5,
            colors: const [AppColors.gameGoldDeep, AppColors.gameGoldLight],
            track: AppColors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: AppSpacing.xs - 2),
          Text(
            '${skill.objectivesDone} of ${skill.objectives.length} objectives',
            style:
                AppTypography.labelSmall.copyWith(color: AppColors.gameTextBody),
          ),
          const SizedBox(height: AppSpacing.xs),
          Material(
            color: AppColors.transparent,
            borderRadius: radius,
            child: InkWell(
              borderRadius: radius,
              onTap: onContinue,
              child: Ink(
                height: _ctaHeight,
                decoration: BoxDecoration(
                  borderRadius: radius,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppColors.gameGoldLight, AppColors.gameGoldDeep],
                  ),
                ),
                child: Center(
                  child: Text(
                    'Continue',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.gameGoldInk,
                      fontWeight: AppTypography.extraBold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Glowing path through the nodes, the locked tail and the elite branch.
class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.points,
    required this.litUpTo,
    required this.elite,
    required this.eliteFrom,
    required this.flow,
  });

  final List<Offset> points;

  /// Segments up to this node index are lit.
  final int litUpTo;
  final Offset elite;
  final Offset eliteFrom;

  /// Animation phase; one unit = one dash cycle.
  final double flow;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final lit = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i <= litUpTo && i < points.length; i++) {
      lit.lineTo(points[i].dx, points[i].dy);
    }

    final halo = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppColors.gameBlue.withValues(alpha: 0.25);
    canvas.drawPath(lit, halo);

    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.gamePathDash;
    _dashed(canvas, lit, dash, 10, 8, phase: (flow % 1) * 18);

    final rest = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.gameLockedTop;
    for (var i = math.max(1, litUpTo + 1); i < points.length; i++) {
      final seg = Path()
        ..moveTo(points[i - 1].dx, points[i - 1].dy)
        ..lineTo(points[i].dx, points[i].dy);
      _dashed(canvas, seg, rest, 2, 10);
    }

    final branch = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..color = AppColors.gameElite.withValues(alpha: 0.7);
    _dashed(
      canvas,
      Path()
        ..moveTo(eliteFrom.dx, eliteFrom.dy)
        ..lineTo(elite.dx, elite.dy),
      branch,
      1,
      10,
    );
  }

  void _dashed(
    Canvas canvas,
    Path path,
    Paint paint,
    double on,
    double off, {
    double phase = 0,
  }) {
    for (final m in path.computeMetrics()) {
      var d = -phase;
      while (d < m.length) {
        final start = math.max(0.0, d);
        final end = math.min(m.length, d + on);
        if (end > start) canvas.drawPath(m.extractPath(start, end), paint);
        d += on + off;
      }
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.flow != flow || old.litUpTo != litUpTo || old.points != points;
}

/// Spinning gold ring with arrow ticks and a dashed white inner ring
/// around the current node.
class _CurrentRingsPainter extends CustomPainter {
  _CurrentRingsPainter(this.t);

  /// 0–1 over the 40 s clock.
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final unit = size.width / 104;

    // Outer gold ring: 8 s per turn → 5 turns per clock loop.
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(t * math.pi * 2 * 5);
    canvas.drawCircle(
      Offset.zero,
      48 * unit,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5 * unit
        ..color = AppColors.gameGold,
    );
    final tick = Paint()..color = AppColors.white;
    for (final a in const [0.0, math.pi / 2, math.pi]) {
      canvas
        ..save()
        ..rotate(a);
      final p = Path()
        ..moveTo(0, -52 * unit)
        ..lineTo(-6 * unit, -43 * unit)
        ..lineTo(6 * unit, -43 * unit)
        ..close();
      canvas
        ..drawPath(p, tick)
        ..restore();
    }
    canvas.restore();

    // Inner dashed ring: 5 s per turn, reversed → 8 turns per loop.
    canvas
      ..save()
      ..translate(c.dx, c.dy)
      ..rotate(-t * math.pi * 2 * 8);
    final ring =
        Path()..addOval(Rect.fromCircle(center: Offset.zero, radius: 39 * unit));
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * unit
      ..strokeCap = StrokeCap.round
      ..color = AppColors.white;
    for (final m in ring.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(
          m.extractPath(d, math.min(m.length, d + 44 * unit)),
          dash,
        );
        d += 62 * unit;
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CurrentRingsPainter old) => old.t != t;
}

/// Violet hexagon with a lightning bolt — the elite trial.
class _HexPainter extends CustomPainter {
  const _HexPainter({required this.locked});

  final bool locked;

  @override
  void paint(Canvas canvas, Size size) {
    final sx = size.width / 60;
    final sy = size.height / 66;
    Offset p(double x, double y) => Offset(x * sx, y * sy);

    final hex = Path()
      ..moveTo(p(30, 2).dx, p(30, 2).dy)
      ..lineTo(p(57, 17.5).dx, p(57, 17.5).dy)
      ..lineTo(p(57, 48.5).dx, p(57, 48.5).dy)
      ..lineTo(p(30, 64).dx, p(30, 64).dy)
      ..lineTo(p(3, 48.5).dx, p(3, 48.5).dy)
      ..lineTo(p(3, 17.5).dx, p(3, 17.5).dy)
      ..close();

    canvas.drawShadow(hex, AppColors.skillViolet, 8, false);
    canvas.drawPath(
      hex,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.gameElite, AppColors.gameEliteDeep],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      hex,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = AppColors.gameEliteLight,
    );

    final bolt = Path()
      ..moveTo(p(33, 16).dx, p(33, 16).dy)
      ..lineTo(p(21, 36).dx, p(21, 36).dy)
      ..lineTo(p(30, 36).dx, p(30, 36).dy)
      ..lineTo(p(27, 51).dx, p(27, 51).dy)
      ..lineTo(p(39, 30).dx, p(39, 30).dy)
      ..lineTo(p(30, 30).dx, p(30, 30).dy)
      ..close();
    canvas.drawPath(bolt, Paint()..color = AppColors.white);

    if (locked) {
      final badge = p(50, 56);
      final r = 10 * sx;
      canvas
        ..drawCircle(badge, r, Paint()..color = AppColors.gameNodeEdge)
        ..drawCircle(
          badge,
          r,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = AppColors.gameEliteLight,
        );
      // Tiny padlock.
      final body = Rect.fromCenter(
        center: badge.translate(0, 1.5 * sx),
        width: 8 * sx,
        height: 6 * sx,
      );
      final lockPaint = Paint()..color = AppColors.gameEliteLight;
      canvas.drawRRect(
        RRect.fromRectAndRadius(body, Radius.circular(1.2 * sx)),
        lockPaint,
      );
      canvas.drawArc(
        Rect.fromCenter(
          center: badge.translate(0, -1.5 * sx),
          width: 5 * sx,
          height: 6 * sx,
        ),
        math.pi,
        math.pi,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4 * sx
          ..color = AppColors.gameEliteLight,
      );
    }
  }

  @override
  bool shouldRepaint(_HexPainter old) => old.locked != locked;
}
