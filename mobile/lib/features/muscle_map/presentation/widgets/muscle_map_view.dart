import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/muscle.dart';
import '../body/body_geometry.dart';
import '../providers/muscle_map_providers.dart';

/// How one muscle is drawn at a moment in time.
@immutable
class MuscleLook {
  const MuscleLook(this.fill, this.glow);

  /// Opaque fill (opaque so the art's paint order hides covered shapes).
  final Color fill;

  /// 0 = unlit, 1 = full cyan halo.
  final double glow;

  static const idle = MuscleLook(AppColors.anatomyBody, 0);

  /// Exact at the ends, so a settled transition equals its target.
  static MuscleLook lerp(MuscleLook a, MuscleLook b, double t) {
    if (t <= 0) return a;
    if (t >= 1) return b;
    return MuscleLook(
      Color.lerp(a.fill, b.fill, t)!,
      lerpDouble(a.glow, b.glow, t)!,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MuscleLook && other.fill == fill && other.glow == glow;

  @override
  int get hashCode => Object.hash(fill, glow);

  @override
  String toString() => 'MuscleLook($fill, glow: $glow)';
}

/// The anatomy hologram: white line art on a near-black body, with each
/// muscle region lit electric cyan by [intensities] (0–1) and [selected].
///
/// Geometry comes from the SVG assets via [bodyAtlasProvider]; every muscle
/// is its own set of vector paths, so highlights never recolour the body.
/// Changes animate (instantly with reduced motion). With [onMuscleTap] set,
/// a tap resolves to the topmost muscle under the finger, or null.
class MuscleMapView extends ConsumerStatefulWidget {
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

  /// The look a muscle settles on for [intensity] (0–1) or when selected.
  static MuscleLook targetLook(double intensity, {bool selected = false}) {
    if (selected) {
      return MuscleLook(
        Color.alphaBlend(
          AppColors.anatomyCyanBright.withValues(alpha: 0.85),
          AppColors.anatomyBody,
        ),
        1,
      );
    }
    final t = intensity.clamp(0.0, 1.0);
    if (t <= 0) return MuscleLook.idle;
    final hue = Color.lerp(AppColors.anatomyCyanDeep, AppColors.anatomyCyan, t)!;
    return MuscleLook(
      Color.alphaBlend(hue.withValues(alpha: 0.45 + 0.5 * t), AppColors.anatomyBody),
      0.3 + 0.6 * t,
    );
  }

  @override
  ConsumerState<MuscleMapView> createState() => MuscleMapViewState();
}

class MuscleMapViewState extends ConsumerState<MuscleMapView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: AppConstants.animMedium,
    value: 1,
  );
  late Map<Muscle, MuscleLook> _from = _targetLooks();
  late Map<Muscle, MuscleLook> _to = _from;

  Map<Muscle, MuscleLook> _targetLooks() => {
        for (final m in Muscle.values)
          m: MuscleMapView.targetLook(
            widget.intensities[m] ?? 0,
            selected: m == widget.selected,
          ),
      };

  Map<Muscle, MuscleLook> get _current => {
        for (final m in Muscle.values)
          m: MuscleLook.lerp(
            _from[m]!,
            _to[m]!,
            Curves.easeOutCubic.transform(_anim.value),
          ),
      };

  /// What [muscle] looks like right now (mid-transition included).
  @visibleForTesting
  MuscleLook lookOf(Muscle muscle) => _current[muscle]!;

  @override
  void didUpdateWidget(MuscleMapView old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected ||
        !_sameIntensities(old.intensities, widget.intensities)) {
      _from = _current;
      _to = _targetLooks();
      final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      _anim.duration = reduceMotion ? Duration.zero : AppConstants.animMedium;
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

  void _onTapUp(TapUpDetails details, Size size, BodyGeometry geometry) {
    final fit = geometry.fit(size);
    final local = (details.localPosition - fit.offset) / fit.scale;
    widget.onMuscleTap!(geometry.hitTest(local));
  }

  @override
  Widget build(BuildContext context) {
    final geometry = ref.watch(bodyAtlasProvider).valueOrNull?[widget.view];
    return Semantics(
      label: widget.semanticLabel,
      image: widget.onMuscleTap == null,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          // Assets load once at startup-time speed; keep the space quiet
          // until then rather than flashing a spinner.
          if (geometry == null) return SizedBox.fromSize(size: size);
          final paint = RepaintBoundary(
            child: AnimatedBuilder(
              animation: _anim,
              builder: (context, _) => CustomPaint(
                size: size,
                painter: _HologramPainter(geometry: geometry, looks: _current),
              ),
            ),
          );
          if (widget.onMuscleTap == null) return paint;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _onTapUp(d, size, geometry),
            child: paint,
          );
        },
      ),
    );
  }
}

class _HologramPainter extends CustomPainter {
  _HologramPainter({required this.geometry, required this.looks});

  final BodyGeometry geometry;
  final Map<Muscle, MuscleLook> looks;

  @override
  void paint(Canvas canvas, Size size) {
    final fit = geometry.fit(size);
    canvas
      ..save()
      ..translate(fit.offset.dx, fit.offset.dy)
      ..scale(fit.scale);
    final hair = 1 / fit.scale; // one logical pixel in view-box units

    canvas.drawPath(geometry.silhouette, Paint()..color = AppColors.anatomyBody);

    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    // Paint order matters: later shapes cover earlier ones, as in the art.
    for (final part in geometry.parts) {
      if (part.isLine) {
        canvas.drawPath(
          part.path,
          stroke
            ..strokeWidth = 0.6 * hair
            ..color = AppColors.anatomyLine.withValues(alpha: 0.3),
        );
        continue;
      }
      final look = part.muscle == null ? null : looks[part.muscle];
      final lit = look?.glow ?? 0;
      canvas
        ..drawPath(part.path, fill..color = look?.fill ?? AppColors.anatomyBody)
        ..drawPath(
          part.path,
          stroke
            ..strokeWidth = (0.6 + 0.4 * lit) * hair
            ..color = Color.lerp(
              AppColors.anatomyLine
                  .withValues(alpha: part.muscle == null ? 0.28 : 0.5),
              AppColors.anatomyCyanBright,
              lit,
            )!,
        );
    }

    // A thin cyan halo around lit regions — subtle, one blur per region.
    for (final muscle in geometry.muscles) {
      final glow = looks[muscle]?.glow ?? 0;
      if (glow < 0.02) continue;
      canvas.drawPath(
        geometry.regionPath(muscle)!,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * hair
          ..color = AppColors.anatomyCyan.withValues(alpha: 0.45 * glow)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * hair),
      );
    }

    canvas.drawPath(
      geometry.silhouette,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1 * hair
        ..color = AppColors.anatomyLine.withValues(alpha: 0.85),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HologramPainter old) =>
      !identical(old.geometry, geometry) || !identical(old.looks, looks);
}
