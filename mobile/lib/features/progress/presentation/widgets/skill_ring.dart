import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Circular progress ring with a blue sweep, used for skill progress on
/// the Dashboard and the Skill detail page. [child] sits in the middle.
class SkillRing extends StatelessWidget {
  const SkillRing({
    required this.progress,
    required this.size,
    this.strokeWidth = 5,
    this.child,
    super.key,
  });

  /// 0–1.
  final double progress;
  final double size;
  final double strokeWidth;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) => CustomPaint(
          painter: _RingPainter(value, strokeWidth),
          child: child,
        ),
        child: child == null ? null : Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.value, this.strokeWidth);

  final double value;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2 + 1);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = AppColors.hubTrackStrong;
    canvas.drawArc(arcRect, 0, math.pi * 2, false, track);

    if (value <= 0) return;
    final sweep = math.pi * 2 * value;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: const [
          AppColors.hubBarStart,
          AppColors.hubEyebrow,
          AppColors.hubSkyLight,
        ],
        stops: [0, value * 0.7, value],
        transform: const GradientRotation(-math.pi / 2),
      ).createShader(rect);
    canvas.drawArc(arcRect, -math.pi / 2, sweep, false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.strokeWidth != strokeWidth;
}
