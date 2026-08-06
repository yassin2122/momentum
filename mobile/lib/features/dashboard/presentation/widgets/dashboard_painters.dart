import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

// =============================================================================
// ActivityRingsPainter — three concentric rings: Move (red/outer),
// Exercise (green/middle), Stand (cyan/inner). Directly mirrors Apple
// Watch Activity ring conventions per spec §13.
//
// Parameters:
//   moveProgress    0.0–1.0  fraction of Move ring filled
//   exerciseProgress                        Exercise ring
//   standProgress                           Stand ring
//   strokeWidth     ring stroke in logical pixels (default 9)
//   gap             spacing between rings in logical pixels (default 4)
// =============================================================================
class ActivityRingsPainter extends CustomPainter {
  const ActivityRingsPainter({
    required this.moveProgress,
    required this.exerciseProgress,
    required this.standProgress,
    this.strokeWidth = 9.0,
    this.gap = 4.0,
  });

  final double moveProgress;
  final double exerciseProgress;
  final double standProgress;
  final double strokeWidth;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = (size.shortestSide / 2) - strokeWidth / 2;

    // Outer = Move (red), Middle = Exercise (green), Inner = Stand (cyan)
    _drawRing(canvas, center, maxRadius,
        AppColors.ringTrack, AppColors.ringMove, moveProgress);
    _drawRing(canvas, center, maxRadius - strokeWidth - gap,
        AppColors.ringTrack, AppColors.ringExercise, exerciseProgress);
    _drawRing(canvas, center, maxRadius - (strokeWidth + gap) * 2,
        AppColors.ringTrack, AppColors.ringStand, standProgress);
  }

  void _drawRing(Canvas canvas, Offset center, double radius,
      Color trackColor, Color fillColor, double progress) {
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Full track (background ring)
    canvas.drawArc(rect, -math.pi / 2, 2 * math.pi, false, trackPaint);

    // Filled arc — clockwise from 12 o'clock
    if (progress > 0) {
      canvas.drawArc(
          rect, -math.pi / 2, 2 * math.pi * progress.clamp(0, 1), false,
          fillPaint);
    }
  }

  @override
  bool shouldRepaint(ActivityRingsPainter old) =>
      old.moveProgress != moveProgress ||
      old.exerciseProgress != exerciseProgress ||
      old.standProgress != standProgress;
}

// =============================================================================
// MuscleHeatmapPainter — simplified anatomical front-torso wireframe
// with an animated warm overlay on the active muscle groups.
//
// The wireframe is built from bezier paths that approximate a stylised
// male upper-body silhouette (chest, shoulders, abs).  The overlay is a
// radial gradient that pulses between [overlayOpacity] values to draw
// the user's eye.  Both layers are drawn in pure Canvas so the component
// can animate without any raster asset.
// =============================================================================
class MuscleHeatmapPainter extends CustomPainter {
  const MuscleHeatmapPainter({required this.glowOpacity});

  /// 0.0–1.0; driven by the repeating sine animation on the card.
  final double glowOpacity;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Wireframe paths ────────────────────────────────────────────────
    final wirePaint = Paint()
      ..color = AppColors.heatmapWireframe
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Torso outline
    final torso = Path();
    torso.moveTo(w * 0.35, h * 0.05); // left shoulder top
    torso.cubicTo(w * 0.15, h * 0.12, w * 0.10, h * 0.28, w * 0.18, h * 0.70);
    torso.lineTo(w * 0.30, h * 0.95);
    torso.lineTo(w * 0.70, h * 0.95);
    torso.lineTo(w * 0.82, h * 0.70);
    torso.cubicTo(w * 0.90, h * 0.28, w * 0.85, h * 0.12, w * 0.65, h * 0.05);
    torso.close();
    canvas.drawPath(torso, wirePaint);

    // Chest divider (sternum line)
    canvas.drawLine(Offset(w * 0.50, h * 0.08), Offset(w * 0.50, h * 0.42),
        wirePaint);

    // Pec curves
    final leftPec = Path();
    leftPec.moveTo(w * 0.18, h * 0.18);
    leftPec.cubicTo(w * 0.20, h * 0.38, w * 0.38, h * 0.42, w * 0.50, h * 0.40);
    canvas.drawPath(leftPec, wirePaint);

    final rightPec = Path();
    rightPec.moveTo(w * 0.82, h * 0.18);
    rightPec.cubicTo(w * 0.80, h * 0.38, w * 0.62, h * 0.42, w * 0.50, h * 0.40);
    canvas.drawPath(rightPec, wirePaint);

    // Abs (3 horizontal lines)
    for (int i = 0; i < 3; i++) {
      final y = h * (0.44 + i * 0.13);
      canvas.drawLine(Offset(w * 0.35, y), Offset(w * 0.65, y), wirePaint);
    }

    // Shoulder caps
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.20, h * 0.15),
        width: w * 0.18, height: h * 0.14), math.pi * 0.7, math.pi, false,
        wirePaint);
    canvas.drawArc(Rect.fromCenter(center: Offset(w * 0.80, h * 0.15),
        width: w * 0.18, height: h * 0.14), math.pi * 1.3, -math.pi, false,
        wirePaint);

    // ── Active muscle overlay (chest + shoulders) ──────────────────────
    // Save/restore so the clip doesn't leak.
    canvas.save();
    canvas.clipPath(torso);

    // Chest glow — radial gradient centred on the pec area
    final chestGlow = RadialGradient(
      center: const Alignment(0, -0.20),
      radius: 0.75,
      colors: [
        AppColors.heatmapActiveEnd.withValues(alpha: glowOpacity * 0.85),
        AppColors.heatmapActiveStart.withValues(alpha: glowOpacity * 0.55),
        AppColors.heatmapActiveStart.withValues(alpha: 0.0),
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final glowPaint = Paint()
      ..shader = chestGlow.createShader(
          Rect.fromLTWH(0, 0, w, h))
      ..blendMode = BlendMode.srcOver;
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), glowPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(MuscleHeatmapPainter old) =>
      old.glowOpacity != glowOpacity;
}

// =============================================================================
// HexagonClipper — clips a container to a regular hexagon (flat-top).
// Used for the skill badge background.
// =============================================================================
class HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => _hexPath(size);

  @override
  bool shouldReclip(HexagonClipper old) => false;

  static Path _hexPath(Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.shortestSide / 2;
    final path = Path();
    for (int i = 0; i < 6; i++) {
      final angle = (math.pi / 3) * i - math.pi / 6; // flat-top orientation
      final x = cx + r * math.cos(angle);
      final y = cy + r * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }
}

// =============================================================================
// HexagonPainter — draws the violet gradient hex fill + outer glow border.
// Separate from the clipper so we can paint the glow *outside* the clip.
// =============================================================================
class HexagonPainter extends CustomPainter {
  const HexagonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final path = HexagonClipper._hexPath(size);

    // Outer glow
    final glowPaint = Paint()
      ..color = AppColors.skillViolet.withValues(alpha: 0.45)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glowPaint);

    // Fill — violet gradient
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.skillVioletLight, AppColors.skillViolet],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(path, fillPaint);
  }

  @override
  bool shouldRepaint(HexagonPainter old) => false;
}
