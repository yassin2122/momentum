import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/muscle.dart';
import '../body/body_geometry.dart';

/// How one muscle is drawn at a moment in time.
@immutable
class _MuscleLook {
  const _MuscleLook(this.fill, this.glow);

  final Color fill;

  /// 0 = no bloom, 1 = full bloom.
  final double glow;

  static _MuscleLook lerp(_MuscleLook a, _MuscleLook b, double t) =>
      _MuscleLook(Color.lerp(a.fill, b.fill, t)!, lerpDouble(a.glow, b.glow, t)!);
}

/// The body map: a dark silhouette with every muscle as its own vector
/// region, lit cyan/blue by [intensities] (0–1) and [selected].
///
/// Colour changes animate. With [onMuscleTap] set, taps resolve to the
/// topmost muscle under the finger (null on empty space).
class MuscleMapView extends StatefulWidget {
  const MuscleMapView({
    required this.view,
    this.intensities = const {},
    this.selected,
    this.onMuscleTap,
    this.semanticLabel,
    super.key,
  });

  final BodyView view;
  final Map<Muscle, double> intensities;
  final Muscle? selected;
  final ValueChanged<Muscle?>? onMuscleTap;
  final String? semanticLabel;

  @override
  State<MuscleMapView> createState() => _MuscleMapViewState();
}

class _MuscleMapViewState extends State<MuscleMapView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: AppConstants.animMedium,
    value: 1,
  );
  late Map<Muscle, _MuscleLook> _from = _targetLooks();
  late Map<Muscle, _MuscleLook> _to = _from;

  static final _idle = _MuscleLook(AppColors.white.withValues(alpha: 0.05), 0);

  Map<Muscle, _MuscleLook> _targetLooks() => {
        for (final m in Muscle.values) m: _lookFor(m),
      };

  _MuscleLook _lookFor(Muscle m) {
    if (m == widget.selected) {
      return const _MuscleLook(AppColors.hubSkyLight, 1);
    }
    final t = (widget.intensities[m] ?? 0).clamp(0.0, 1.0);
    if (t <= 0) return _idle;
    final hue = Color.lerp(
        AppColors.heatmapActiveStart, AppColors.heatmapActiveEnd, t)!;
    return _MuscleLook(hue.withValues(alpha: 0.45 + 0.55 * t), 0.35 + 0.5 * t);
  }

  Map<Muscle, _MuscleLook> get _current => {
        for (final m in Muscle.values)
          m: _MuscleLook.lerp(_from[m]!, _to[m]!, _anim.value),
      };

  @override
  void didUpdateWidget(MuscleMapView old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected ||
        !_sameIntensities(old.intensities, widget.intensities)) {
      _from = _current;
      _to = _targetLooks();
      _anim.forward(from: 0);
    }
  }

  static bool _sameIntensities(Map<Muscle, double> a, Map<Muscle, double> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _onTapUp(TapUpDetails details, Size size) {
    final fit = BodyGeometry.fit(size);
    final local = (details.localPosition - fit.offset) / fit.scale;
    widget.onMuscleTap!(BodyGeometry.hitTest(widget.view, local));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel,
      image: widget.onMuscleTap == null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final paint = AnimatedBuilder(
            animation: _anim,
            builder: (context, _) => CustomPaint(
              size: size,
              painter: _BodyPainter(view: widget.view, looks: _current),
            ),
          );
          if (widget.onMuscleTap == null) return paint;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTapUp(d, size),
            child: paint,
          );
        },
      ),
    );
  }
}

class _BodyPainter extends CustomPainter {
  _BodyPainter({required this.view, required this.looks});

  final BodyView view;
  final Map<Muscle, _MuscleLook> looks;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = BodyGeometry.fit(size);
    canvas
      ..save()
      ..translate(fit.offset.dx, fit.offset.dy)
      ..scale(fit.scale);
    final hair = 1 / fit.scale; // 1 device-independent pixel

    canvas.drawPath(
      BodyGeometry.silhouette,
      Paint()..color = AppColors.hubCardTop.withValues(alpha: 0.85),
    );

    for (final shape in BodyGeometry.shapes(view)) {
      final look = looks[shape.muscle]!;
      if (look.glow > 0.01) {
        canvas.drawPath(
          shape.path,
          Paint()
            ..color = look.fill.withValues(alpha: 0.55 * look.glow)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * hair),
        );
      }
      canvas
        ..drawPath(shape.path, Paint()..color = look.fill)
        ..drawPath(
          shape.path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8 * hair
            ..color = AppColors.white.withValues(alpha: 0.12 + 0.3 * look.glow),
        );
    }

    canvas.drawPath(
      BodyGeometry.silhouette,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2 * hair
        ..color = AppColors.heatmapWireframe,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BodyPainter old) =>
      old.view != view || !identical(old.looks, looks);
}
