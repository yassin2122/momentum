import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../sample/achievements_sample_data.dart';
import 'svg_path.dart';

/// Hexagonal achievement medallion (design/canvas: ach/Badge).
///
/// Earned badges wear their rarity's material; locked and in-progress
/// ones are graphite, and in-progress ones show a progress arc in the
/// rarity accent. Legendary and mythic badges get a slowly turning edge
/// and a light sweep when [animated] (and motion isn't reduced).
class AchievementBadge extends StatefulWidget {
  const AchievementBadge({
    required this.achievement,
    required this.size,
    this.animated = false,
    this.forceEarned = false,
    super.key,
  });

  final Achievement achievement;

  /// Width; height is 1.1 × width.
  final double size;
  final bool animated;

  /// Draw as earned regardless of state (unlock moment).
  final bool forceEarned;

  @override
  State<AchievementBadge> createState() => _AchievementBadgeState();
}

class _AchievementBadgeState extends State<AchievementBadge>
    with TickerProviderStateMixin {
  AnimationController? _clock;

  bool get _wantsMotion {
    final a = widget.achievement;
    final earned = widget.forceEarned || a.isEarned;
    return widget.animated &&
        earned &&
        (a.rarity == Rarity.legendary ||
            a.rarity == Rarity.mythic ||
            a.rarity == Rarity.epic);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncClock();
  }

  @override
  void didUpdateWidget(AchievementBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncClock();
  }

  void _syncClock() {
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_wantsMotion && !reduce) {
      _clock ??= AnimationController(
        vsync: this,
        duration: const Duration(seconds: 9),
      )..repeat();
    } else {
      _clock?.dispose();
      _clock = null;
    }
  }

  @override
  void dispose() {
    _clock?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.achievement;
    final earned = widget.forceEarned || a.isEarned;
    final label = '${a.title}, ${a.rarity.label}'
        '${earned ? '' : a.state == AchievementState.inProgress ? ', ${a.progressLabel ?? 'in progress'}' : ', locked'}';

    Widget paint(double t) => CustomPaint(
          size: Size(widget.size, widget.size * 1.1),
          painter: _BadgePainter(
            rarity: a.rarity,
            glyph: achievementGlyphs[a.slug] ?? '',
            earned: earned,
            progress: a.state == AchievementState.inProgress && !earned
                ? a.progress
                : null,
            showNew: a.state == AchievementState.isNew && !widget.forceEarned,
            t: t,
          ),
        );

    final clock = _clock;
    return Semantics(
      label: label,
      image: true,
      excludeSemantics: true,
      child: RepaintBoundary(
        child: clock == null
            ? paint(0)
            : AnimatedBuilder(
                animation: clock,
                builder: (context, _) => paint(clock.value),
              ),
      ),
    );
  }
}

class _BadgePainter extends CustomPainter {
  _BadgePainter({
    required this.rarity,
    required this.glyph,
    required this.earned,
    required this.progress,
    required this.showNew,
    required this.t,
  });

  final Rarity rarity;
  final String glyph;
  final bool earned;
  final double? progress;
  final bool showNew;

  /// 0–1 animation phase.
  final double t;

  static final Path _outer = parseSvgPath(
    'M42.21 13.50 Q50.00 9.00 57.79 13.50 L82.04 27.50 Q89.84 32.00 89.84 '
    '41.00 L89.84 69.00 Q89.84 78.00 82.04 82.50 L57.79 96.50 Q50.00 101.00 '
    '42.21 96.50 L17.96 82.50 Q10.16 78.00 10.16 69.00 L10.16 41.00 Q10.16 '
    '32.00 17.96 27.50 Z',
  );
  static final Path _rim = parseSvgPath(
    'M19.69 29.50 L43.07 16.00 Q50.00 12.00 56.93 16.00 L80.31 29.50',
  );
  static final Path _inner = parseSvgPath(
    'M43.94 19.50 Q50.00 16.00 56.06 19.50 L77.71 32.00 Q83.77 35.50 83.77 '
    '42.50 L83.77 67.50 Q83.77 74.50 77.71 78.00 L56.06 90.50 Q50.00 94.00 '
    '43.94 90.50 L22.29 78.00 Q16.23 74.50 16.23 67.50 L16.23 42.50 Q16.23 '
    '35.50 22.29 32.00 Z',
  );
  static final Map<String, Path> _glyphCache = {};

  @override
  void paint(Canvas canvas, Size size) {
    final m = earned ? rarity.palette : AchievementPalette.locked;
    final scale = size.width / 100;
    canvas
      ..save()
      ..scale(scale);
    const box = Rect.fromLTWH(0, 0, 100, 110);
    const center = Offset(50, 55);

    // Frame.
    canvas.drawPath(
      _outer,
      Paint()
        ..shader = LinearGradient(
          begin: const Alignment(-0.6, -1),
          end: const Alignment(0.2, 1),
          colors: [m.frameTop, m.frameMid, m.frameBottom],
          stops: const [0, 0.55, 1],
        ).createShader(box),
    );
    canvas.drawPath(
      _outer,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = m.edgeWidth
        ..shader = LinearGradient(
          colors: [m.edgeLight, m.edgeMid, m.edgeDark, m.edgeLight],
          stops: const [0, 0.35, 0.7, 1],
          transform: GradientRotation(t * math.pi * 2),
        ).createShader(box),
    );
    if (m.rimOpacity > 0) {
      canvas.drawPath(
        _rim,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.1
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.white.withValues(alpha: m.rimOpacity),
      );
    }

    // Inner plate.
    canvas
      ..drawPath(
        _inner,
        Paint()
          ..shader = LinearGradient(
            begin: const Alignment(-0.4, -1),
            end: Alignment.bottomCenter,
            colors: [m.innerTop, m.innerBottom],
          ).createShader(box),
      )
      ..drawPath(
        _inner,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = m.innerEdge,
      );

    // Glow and rings.
    if (m.glowOpacity > 0) {
      canvas.drawCircle(
        center,
        31,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0, -0.1),
            colors: [
              m.glow.withValues(alpha: m.glowOpacity),
              m.glow.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: 31)),
      );
    }
    void ring(double r, double opacity, double width) {
      if (opacity <= 0) return;
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = m.ring.withValues(alpha: opacity),
      );
    }

    ring(30, m.ringOpacity, 0.8);
    ring(33, m.outerRingOpacity, 0.6);
    if (m.tickOpacity > 0) {
      final tick = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = m.ring.withValues(alpha: m.tickOpacity);
      const circumference = 2 * math.pi * 33;
      const step = 2.6; // 0.5 on, 2.1 off
      for (var d = 0.0; d < circumference; d += step) {
        final a = d / 33;
        final a2 = (d + 0.5) / 33;
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: 33),
          a,
          a2 - a,
          false,
          tick,
        );
      }
    }

    // Progress arc (in-progress only).
    final p = progress;
    if (p != null) {
      final arcRect = Rect.fromCircle(center: center, radius: 33);
      canvas.drawCircle(
        center,
        33,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = AchievementPalette.progressTrack,
      );
      if (p > 0) {
        canvas.drawArc(
          arcRect,
          -math.pi / 2,
          math.pi * 2 * p.clamp(0.0, 1.0),
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.2
            ..strokeCap = StrokeCap.round
            ..color = rarity.palette.accent,
        );
      }
    }

    // Glyph: 24-unit art at translate(34 39) scale(1.333).
    if (glyph.isNotEmpty) {
      final g = _glyphCache.putIfAbsent(glyph, () => parseSvgPath(glyph));
      canvas
        ..save()
        ..translate(34, 39)
        ..scale(4 / 3)
        ..drawPath(
          g,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..color = m.glyph.withValues(alpha: earned ? 1 : 0.55),
        )
        ..restore();
    }

    // Light sweep across the frame.
    if (earned && m.sweepOpacity > 0) {
      // Sweep runs for the first 40% of each 4.5–6 s loop.
      final phase = (t * 2) % 1;
      if (phase < 0.4) {
        final x = -10 + (phase / 0.4) * 160;
        canvas
          ..save()
          ..clipPath(_outer)
          ..transform(Matrix4.skewX(-0.32).storage);
        final sweep = Rect.fromLTWH(x - 30, 0, 34, 110);
        canvas
          ..drawRect(
            sweep,
            Paint()
              ..shader = LinearGradient(
                colors: [
                  AppColors.white.withValues(alpha: 0),
                  AppColors.white.withValues(alpha: m.sweepOpacity),
                  AppColors.white.withValues(alpha: 0),
                ],
              ).createShader(sweep),
          )
          ..restore();
      }
    }

    // NEW pill.
    if (showNew) {
      const pill = Rect.fromLTWH(64, 3, 32, 15);
      canvas.drawRRect(
        RRect.fromRectAndRadius(pill, const Radius.circular(7.5)),
        Paint()..color = AppColors.achNewPill,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: 'NEW',
          style: AppTypography.labelSmall.copyWith(
            fontSize: 8.5,
            height: 1,
            letterSpacing: 0.6,
            fontWeight: AppTypography.extraBold,
            color: AppColors.phaseInk,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp
        ..paint(
          canvas,
          Offset(pill.center.dx - tp.width / 2, pill.center.dy - tp.height / 2),
        )
        ..dispose();
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_BadgePainter old) =>
      old.t != t ||
      old.earned != earned ||
      old.progress != progress ||
      old.rarity != rarity ||
      old.glyph != glyph ||
      old.showNew != showNew;
}
