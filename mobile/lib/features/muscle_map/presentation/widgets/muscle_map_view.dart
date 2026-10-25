import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
///
/// With [zoomToHighlight] the camera frames the most-lit muscles (see
/// [BodyGeometry.focusFrame]) and glides when they change — use it for
/// small or exercise-specific maps; leave it off to show the whole body.
class MuscleMapView extends ConsumerStatefulWidget {
  const MuscleMapView({
    required this.view,
    this.intensities = const {},
    this.selected,
    this.onMuscleTap,
    this.semanticLabel,
    this.zoomToHighlight = false,
    this.scanIn = false,
    super.key,
  });

  final bool zoomToHighlight;

  /// Reveal the body with a one-time cyan scan line, top to bottom, the
  /// first time it's drawn — the hologram's signature moment. Off by
  /// default so small maps elsewhere in the app stay quiet.
  final bool scanIn;
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
    final hue =
        Color.lerp(AppColors.anatomyCyanDeep, AppColors.anatomyCyan, t)!;
    return MuscleLook(
      Color.alphaBlend(
          hue.withValues(alpha: 0.45 + 0.5 * t), AppColors.anatomyBody),
      0.3 + 0.6 * t,
    );
  }

  @override
  ConsumerState<MuscleMapView> createState() => MuscleMapViewState();
}

class MuscleMapViewState extends ConsumerState<MuscleMapView>
    with TickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: AppConstants.animMedium,
    value: 1,
  );

  /// First-draw scan reveal (1 = fully shown, no scan line).
  late final AnimationController _scan = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    value: widget.scanIn ? 0 : 1,
  );
  bool _scanScheduled = false;

  /// One-shot halo ripple from a newly selected muscle (1 = settled).
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );

  bool get _reduceMotion =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduceMotion) _scan.value = 1;
  }

  /// Starts the scan once the body geometry is ready to draw.
  void _maybeStartScan() {
    if (_scanScheduled || _scan.value >= 1) return;
    _scanScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scan.forward();
    });
  }

  late Map<Muscle, MuscleLook> _from = _targetLooks();
  late Map<Muscle, MuscleLook> _to = _from;

  Map<Muscle, MuscleLook> _targetLooks() => {
        for (final m in Muscle.values)
          m: MuscleMapView.targetLook(
            widget.intensities[m] ?? 0,
            selected: m == widget.selected,
          ),
      };

  /// The looks on screen. At rest this is the very same [_to] map every
  /// time, so the painter (which compares by identity) skips repainting
  /// when the parent rebuilds; a fresh map is built only mid-transition.
  Map<Muscle, MuscleLook> get _current {
    if (_anim.value >= 1) return _to;
    return {
      for (final m in Muscle.values)
        m: MuscleLook.lerp(
          _from[m]!,
          _to[m]!,
          Curves.easeOutCubic.transform(_anim.value),
        ),
    };
  }

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
      final reduceMotion = _reduceMotion;
      _anim.duration = reduceMotion ? Duration.zero : AppConstants.animMedium;
      _anim.forward(from: 0);
      if (widget.selected != null &&
          old.selected != widget.selected &&
          !reduceMotion) {
        _pulse.forward(from: 0);
      }
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
    _scan.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// The frame currently on screen (mid-glide included), for hit tests.
  Rect? _shownFrame;

  // Last camera frame and what it was computed from: focusFrame measures
  // region bounds, which is too much work to redo on every parent rebuild.
  Rect? _frameCache;
  BodyGeometry? _frameGeometry;
  Size? _frameSize;
  Map<Muscle, double>? _frameIntensities;
  Muscle? _frameSelected;

  Rect _targetFrame(BodyGeometry geometry, Size size) {
    if (!widget.zoomToHighlight || size.isEmpty) return geometry.bodyFrame;
    final cached = _frameCache;
    if (cached != null &&
        identical(_frameGeometry, geometry) &&
        _frameSize == size &&
        _frameSelected == widget.selected &&
        _sameIntensities(_frameIntensities!, widget.intensities)) {
      return cached;
    }
    final lit = {
      ...widget.intensities,
      if (widget.selected != null) widget.selected!: 1.0,
    };
    _frameGeometry = geometry;
    _frameSize = size;
    _frameSelected = widget.selected;
    _frameIntensities = widget.intensities;
    return _frameCache =
        geometry.focusFrame(lit, aspect: size.width / size.height);
  }

  void _onTapUp(TapUpDetails details, Size size, BodyGeometry geometry) {
    final fit = geometry.fit(size, frame: _shownFrame);
    final local = (details.localPosition - fit.offset) / fit.scale;
    final muscle = geometry.hitTest(local);
    if (muscle != null) HapticFeedback.selectionClick();
    widget.onMuscleTap!(muscle);
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
          _maybeStartScan();
          final reduceMotion = _reduceMotion;
          final paint = RepaintBoundary(
            child: TweenAnimationBuilder<Rect?>(
              tween: RectTween(end: _targetFrame(geometry, size)),
              duration: reduceMotion ? Duration.zero : AppConstants.animSlow,
              curve: Curves.easeInOutCubic,
              builder: (context, frame, _) {
                _shownFrame = frame;
                return AnimatedBuilder(
                  animation: Listenable.merge([_anim, _scan, _pulse]),
                  builder: (context, _) => CustomPaint(
                    size: size,
                    painter: _HologramPainter(
                      geometry: geometry,
                      looks: _current,
                      frame: frame,
                      scan: Curves.easeInOutCubic.transform(_scan.value),
                      pulse: _pulse.value,
                      pulseMuscle: widget.selected,
                    ),
                  ),
                );
              },
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
  _HologramPainter({
    required this.geometry,
    required this.looks,
    required this.frame,
    required this.scan,
    required this.pulse,
    required this.pulseMuscle,
  });

  final BodyGeometry geometry;
  final Map<Muscle, MuscleLook> looks;
  final Rect? frame;

  /// 0–1 scan-in reveal; 1 draws everything with no scan line.
  final double scan;

  /// 0–1 halo ripple progress around [pulseMuscle]; 1 = none.
  final double pulse;
  final Muscle? pulseMuscle;

  @override
  void paint(Canvas canvas, Size size) {
    if (scan <= 0) return;
    final scanY = size.height * scan;
    final fit = geometry.fit(size, frame: frame);
    canvas
      ..save()
      // Above the scan line only, while the scan runs.
      ..clipRect(scan < 1
          ? Rect.fromLTWH(0, 0, size.width, scanY)
          : Offset.zero & size)
      ..translate(fit.offset.dx, fit.offset.dy)
      ..scale(fit.scale);
    final hair = 1 / fit.scale; // one logical pixel in view-box units
    // Very small renders: drop the finest line work (face, fibres) — at
    // that size it only reads as noise.
    final tiny = fit.scale < 0.2;

    canvas.drawPath(
        geometry.silhouette, Paint()..color = AppColors.anatomyBody);

    final fill = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    // Paint order matters: later shapes cover earlier ones, as in the art.
    for (final part in geometry.parts) {
      if (part.isLine) {
        if (tiny) continue;
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
              AppColors.anatomyLine.withValues(
                  alpha: part.muscle == null ? (tiny ? 0.16 : 0.28) : 0.5),
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

    // Selection ripple: one soft cyan ring spreading out and fading.
    final ripple =
        pulseMuscle == null ? null : geometry.regionPath(pulseMuscle!);
    if (ripple != null && pulse < 1) {
      final p = Curves.easeOutCubic.transform(pulse);
      canvas.drawPath(
        ripple,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (2 + 10 * p) * hair
          ..color =
              AppColors.anatomyCyanBright.withValues(alpha: 0.55 * (1 - p))
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, (2 + 6 * p) * hair),
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

    if (scan < 1) _paintScanLine(canvas, size, scanY);
  }

  /// The bright scan front plus a faint glow trailing above it.
  void _paintScanLine(Canvas canvas, Size size, double y) {
    const trail = 28.0;
    // Fade the line out over the last tenth of the sweep.
    final fade = ((1 - scan) / 0.1).clamp(0.0, 1.0);
    canvas
      ..drawRect(
        Rect.fromLTWH(0, y - trail, size.width, trail),
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.anatomyCyan.withValues(alpha: 0),
              AppColors.anatomyCyan.withValues(alpha: 0.12 * fade),
            ],
          ).createShader(Rect.fromLTWH(0, y - trail, size.width, trail)),
      )
      ..drawRect(
        Rect.fromLTWH(0, y - 1, size.width, 1.5),
        Paint()
          ..shader = LinearGradient(colors: [
            AppColors.anatomyCyanBright.withValues(alpha: 0),
            AppColors.anatomyCyanBright.withValues(alpha: 0.9 * fade),
            AppColors.anatomyCyanBright.withValues(alpha: 0),
          ]).createShader(Rect.fromLTWH(0, y - 1, size.width, 1.5)),
      );
  }

  @override
  bool shouldRepaint(_HologramPainter old) =>
      !identical(old.geometry, geometry) ||
      !identical(old.looks, looks) ||
      old.frame != frame ||
      old.scan != scan ||
      old.pulse != pulse ||
      old.pulseMuscle != pulseMuscle;
}
