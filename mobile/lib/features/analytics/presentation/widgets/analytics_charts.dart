import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/services/body_trend.dart';

/// Hand-drawn charts for Analytics. Custom painters keep each feature's
/// look distinct and need no extra dependency.

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

// ─────────────────────────────────────────────────────────────────────
// Composition ring (distribution)
// ─────────────────────────────────────────────────────────────────────

final class RingSegment {
  const RingSegment(this.value, this.color);

  final double value;
  final Color color;
}

/// A donut of [segments] with [center] inside.
///
/// It sweeps itself in on first show; after that, new data morphs each
/// segment from its old share to its new one (so switching a time range
/// reads as the same chart changing, not a new chart). Selecting a segment
/// lifts it and dims the rest smoothly.
class CompositionRing extends StatefulWidget {
  const CompositionRing({
    required this.segments,
    required this.center,
    this.size = 220,
    this.thickness = 18,
    this.selected,
    super.key,
  });

  final List<RingSegment> segments;
  final Widget center;
  final double size;
  final double thickness;

  /// Index of a segment to lift; others dim.
  final int? selected;

  @override
  State<CompositionRing> createState() => _CompositionRingState();
}

class _CompositionRingState extends State<CompositionRing>
    with TickerProviderStateMixin {
  late final AnimationController _data =
      AnimationController(vsync: this, duration: AppConstants.animSlow * 2);
  late final AnimationController _sel = AnimationController(
      vsync: this, duration: AppConstants.animMedium, value: 1);

  late List<RingSegment> _from = widget.segments;
  late List<RingSegment> _to = widget.segments;
  bool _sweeping = true; // first show: sweep in rather than morph
  bool _started = false;
  late int? _prevSelected = widget.selected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion(context) ? _data.value = 1 : _data.forward();
  }

  static bool _same(List<RingSegment> a, List<RingSegment> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].value != b[i].value || a[i].color != b[i].color) return false;
    }
    return true;
  }

  /// Segments as drawn right now, padded so old and new line up.
  List<RingSegment> get _current {
    final t = Curves.easeInOutCubic.transform(_data.value);
    if (_sweeping || t >= 1) return _to;
    final n = math.max(_from.length, _to.length);
    return [
      for (var i = 0; i < n; i++)
        RingSegment(
          lerpDouble(
            i < _from.length ? _from[i].value : 0,
            i < _to.length ? _to[i].value : 0,
            t,
          )!,
          i < _to.length ? _to[i].color : _from[i].color,
        ),
    ];
  }

  @override
  void didUpdateWidget(CompositionRing old) {
    super.didUpdateWidget(old);
    final reduce = _reduceMotion(context);
    if (!_same(old.segments, widget.segments)) {
      _from = _current;
      _to = widget.segments;
      _sweeping = false;
      _data.duration = reduce ? Duration.zero : AppConstants.animSlow;
      _data.forward(from: 0);
    }
    if (old.selected != widget.selected) {
      _prevSelected = old.selected;
      _sel.duration = reduce ? Duration.zero : AppConstants.animMedium;
      _sel.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _data.dispose();
    _sel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: widget.size,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: Listenable.merge([_data, _sel]),
          builder: (context, child) {
            final s = Curves.easeOutCubic.transform(_sel.value);
            final selected = widget.selected;
            final prev = _prevSelected;
            final segments = _current;
            return CustomPaint(
              painter: _RingPainter(
                segments: segments,
                thickness: widget.thickness,
                progress:
                    _sweeping ? Curves.easeOutCubic.transform(_data.value) : 1,
                emphasis: [
                  for (var i = 0; i < segments.length; i++)
                    (i == selected ? s : 0.0) +
                        (i == prev && prev != selected ? 1 - s : 0.0),
                ],
                dim: lerpDouble(
                    prev == null ? 0 : 1, selected == null ? 0 : 1, s)!,
              ),
              child: child,
            );
          },
          child: Center(child: widget.center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.segments,
    required this.thickness,
    required this.progress,
    required this.emphasis,
    required this.dim,
  });

  final List<RingSegment> segments;
  final double thickness;

  /// First-show sweep, 0–1.
  final double progress;

  /// Per segment, 0–1: how lifted it is.
  final List<double> emphasis;

  /// 0–1: how much non-lifted segments are dimmed.
  final double dim;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - thickness / 2 - 4,
    );
    // Tick ring outside the donut — the brushed-metal bezel.
    final bezel = Paint()
      ..color = AppColors.silverDeep
      ..strokeWidth = 1;
    final outer = size.shortestSide / 2 - 1;
    for (var i = 0; i < 60; i++) {
      final a = i / 60 * 2 * math.pi;
      final len = i % 5 == 0 ? 5.0 : 2.5;
      final c = size.center(Offset.zero);
      canvas.drawLine(
        c + Offset(math.cos(a), math.sin(a)) * (outer - len),
        c + Offset(math.cos(a), math.sin(a)) * outer,
        bezel,
      );
    }

    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..color = AppColors.analyticsTrack,
    );

    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total <= 0) return;
    const gap = 0.035; // radians between segments
    var start = -math.pi / 2;
    final sweepAll = 2 * math.pi * progress;
    for (var i = 0; i < segments.length; i++) {
      final full = segments[i].value / total * 2 * math.pi;
      final visible =
          math.min(full, math.max(0.0, sweepAll - (start + math.pi / 2)));
      if (visible > gap) {
        final e = (i < emphasis.length ? emphasis[i] : 0.0).clamp(0.0, 1.0);
        canvas.drawArc(
          rect.inflate(2 * e),
          start + gap / 2,
          visible - gap,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.butt
            ..strokeWidth = thickness + 4 * e
            ..color =
                segments[i].color.withValues(alpha: 1 - 0.7 * dim * (1 - e)),
        );
      }
      start += full;
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.dim != dim ||
      old.thickness != thickness ||
      !listEquals(old.emphasis, emphasis) ||
      !identical(old.segments, segments);
}

// ─────────────────────────────────────────────────────────────────────
// Column bars (weekly sets, daily load)
// ─────────────────────────────────────────────────────────────────────

/// Simple column bars with optional labels under each bar. Bars grow in on
/// first show, and glide from their old heights to new ones when the data
/// changes (a different count of bars regrows from zero).
class ColumnBars extends StatefulWidget {
  const ColumnBars({
    required this.values,
    required this.color,
    this.labels,
    this.height = 96,
    this.highlightLast = true,
    this.showValues = false,
    super.key,
  });

  final List<double> values;
  final List<String>? labels;
  final Color color;
  final double height;
  final bool highlightLast;
  final bool showValues;

  @override
  State<ColumnBars> createState() => _ColumnBarsState();
}

class _ColumnBarsState extends State<ColumnBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppConstants.animSlow);
  late List<double> _from = List.filled(widget.values.length, 0);
  bool _started = false;

  /// Bar heights as fractions of the tallest, so a rescale glides too.
  static List<double> _fractions(List<double> v) {
    final max = v.fold<double>(0, math.max);
    return [for (final x in v) max <= 0 ? 0.0 : x / max];
  }

  List<double> get _current {
    final to = _fractions(widget.values);
    final t = Curves.easeOutCubic.transform(_c.value);
    return [
      for (var i = 0; i < to.length; i++)
        lerpDouble(i < _from.length ? _from[i] : 0, to[i], t)!,
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion(context) ? _c.value = 1 : _c.forward();
  }

  @override
  void didUpdateWidget(ColumnBars old) {
    super.didUpdateWidget(old);
    if (listEquals(old.values, widget.values)) return;
    // Snapshot what's on screen (computed against the old values).
    final oldTo = _fractions(old.values);
    final t = Curves.easeOutCubic.transform(_c.value);
    _from = old.values.length == widget.values.length
        ? [
            for (var i = 0; i < oldTo.length; i++)
              lerpDouble(i < _from.length ? _from[i] : 0, oldTo[i], t)!,
          ]
        : List.filled(widget.values.length, 0);
    _c.duration =
        _reduceMotion(context) ? Duration.zero : AppConstants.animSlow;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final values = widget.values;
    final height = widget.height;
    final showValues = widget.showValues;
    final highlightLast = widget.highlightLast;
    final color = widget.color;
    final labels = widget.labels;
    return Column(
      children: [
        SizedBox(
          height: height,
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final frac = _current;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < values.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            if (showValues && values[i] > 0)
                              Text(
                                values[i].round().toString(),
                                style: AppTypography.numeric(
                                        AppTypography.labelSmall)
                                    .copyWith(color: AppColors.silverDim),
                              ),
                            Container(
                              height: math.max(3.0,
                                  frac[i] * (height - (showValues ? 16 : 0))),
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppRadius.small / 2)),
                                gradient: values[i] <= 0
                                    ? null
                                    : LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          highlightLast &&
                                                  i == values.length - 1
                                              ? color
                                              : color.withValues(alpha: 0.7),
                                          color.withValues(alpha: 0.25),
                                        ],
                                      ),
                                color: values[i] <= 0
                                    ? AppColors.analyticsTrack
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        if (labels != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              for (final l in labels)
                Expanded(
                  child: Text(
                    l,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.silverDim),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Trend line (body metrics)
// ─────────────────────────────────────────────────────────────────────

/// An interactive line chart: drag or tap to read a point.
class TrendLineChart extends StatefulWidget {
  const TrendLineChart({
    required this.points,
    required this.format,
    this.average,
    this.goal,
    this.color = AppColors.analyticsSteel,
    this.height = 200,
    super.key,
  });

  final List<TrendPoint> points;

  /// Optional smoothed line drawn under the raw points.
  final List<TrendPoint>? average;

  /// Optional dashed target line.
  final double? goal;
  final String Function(double) format;
  final Color color;
  final double height;

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart>
    with SingleTickerProviderStateMixin {
  int? _active;
  static final _day = DateFormat('d MMM');

  /// Draws the line in left to right: on first show, and again whenever
  /// the series changes (a new measure or range).
  late final AnimationController _draw =
      AnimationController(vsync: this, duration: AppConstants.animSlow * 2);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _reduceMotion(context) ? _draw.value = 1 : _draw.forward();
  }

  @override
  void dispose() {
    _draw.dispose();
    super.dispose();
  }

  /// Series are rebuilt on every parent build, so compare by content.
  static bool _same(List<TrendPoint>? a, List<TrendPoint>? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null || a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].date != b[i].date || a[i].value != b[i].value) return false;
    }
    return true;
  }

  void _pick(Offset local, double width) {
    final n = widget.points.length;
    if (n == 0) return;
    final i = n == 1
        ? 0
        : ((local.dx - _TrendPainter.leftPad) /
                (width - _TrendPainter.leftPad - _TrendPainter.rightPad) *
                (n - 1))
            .round()
            .clamp(0, n - 1)
            .toInt();
    if (i != _active) {
      // A light tick per point while scrubbing, like reading a dial.
      HapticFeedback.selectionClick();
      setState(() => _active = i);
    }
  }

  @override
  void didUpdateWidget(TrendLineChart old) {
    super.didUpdateWidget(old);
    if (_same(old.points, widget.points) && old.goal == widget.goal) return;
    _active = null;
    _draw.duration =
        _reduceMotion(context) ? Duration.zero : AppConstants.animSlow;
    _draw.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final pts = widget.points;
    final active =
        _active == null || _active! >= pts.length ? null : pts[_active!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: AppSpacing.lg,
          child: AnimatedOpacity(
            opacity: active == null ? 0 : 1,
            duration: AppConstants.animFast,
            child: active == null
                ? const SizedBox.shrink()
                : Text(
                    '${widget.format(active.value)} · ${_day.format(active.date)}',
                    style: AppTypography.numeric(AppTypography.labelLarge)
                        .copyWith(color: AppColors.silverBright),
                  ),
          ),
        ),
        LayoutBuilder(
          builder: (context, c) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanDown: (d) => _pick(d.localPosition, c.maxWidth),
            onPanUpdate: (d) => _pick(d.localPosition, c.maxWidth),
            child: Semantics(
              label: pts.isEmpty
                  ? 'No data'
                  : 'Trend from ${widget.format(pts.first.value)} on '
                      '${_day.format(pts.first.date)} to '
                      '${widget.format(pts.last.value)} on ${_day.format(pts.last.date)}',
              child: RepaintBoundary(
                child: AnimatedBuilder(
                  animation: _draw,
                  builder: (context, _) => CustomPaint(
                    size: Size(c.maxWidth, widget.height),
                    painter: _TrendPainter(
                      points: pts,
                      average: widget.average,
                      goal: widget.goal,
                      color: widget.color,
                      progress: Curves.easeOutCubic.transform(_draw.value),
                      active: _active,
                      format: widget.format,
                      labelStyle:
                          AppTypography.numeric(AppTypography.labelSmall)
                              .copyWith(color: AppColors.silverDim),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (pts.length >= 2) ...[
          const SizedBox(height: AppSpacing.xxs),
          Padding(
            padding: const EdgeInsets.only(left: _TrendPainter.leftPad),
            child: Row(
              children: [
                Text(_day.format(pts.first.date),
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.silverDim)),
                const Spacer(),
                Text(_day.format(pts.last.date),
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.silverDim)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.average,
    required this.goal,
    required this.color,
    required this.progress,
    required this.active,
    required this.format,
    required this.labelStyle,
  });

  static const double leftPad = 44;
  static const double rightPad = 8;
  static const double topPad = 8;
  static const double bottomPad = 8;

  final List<TrendPoint> points;
  final List<TrendPoint>? average;
  final double? goal;
  final Color color;
  final double progress;
  final int? active;
  final String Function(double) format;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final values = [
      for (final p in points) p.value,
      if (goal != null) goal!,
    ];
    var lo = values.reduce(math.min);
    var hi = values.reduce(math.max);
    if (hi - lo < 1e-6) {
      lo -= 1;
      hi += 1;
    }
    final padV = (hi - lo) * 0.12;
    lo -= padV;
    hi += padV;

    final w = size.width - leftPad - rightPad;
    final h = size.height - topPad - bottomPad;
    final t0 = points.first.date.millisecondsSinceEpoch.toDouble();
    final t1 = points.last.date.millisecondsSinceEpoch.toDouble();
    double x(DateTime d) => points.length == 1
        ? leftPad + w / 2
        : leftPad + (d.millisecondsSinceEpoch - t0) / (t1 - t0) * w;
    double y(double v) => topPad + (1 - (v - lo) / (hi - lo)) * h;

    // Grid: three silver hairlines with value labels.
    final grid = Paint()
      ..color = AppColors.analyticsHairline
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final v = lo + (hi - lo) * i / 2;
      final gy = y(v);
      canvas.drawLine(
          Offset(leftPad, gy), Offset(size.width - rightPad, gy), grid);
      final tp = TextPainter(
        text: TextSpan(text: format(v), style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout(maxWidth: leftPad - 6);
      tp.paint(canvas, Offset(0, gy - tp.height / 2));
    }

    canvas.save();
    canvas.clipRect(
        Rect.fromLTWH(0, 0, leftPad + w * progress + rightPad, size.height));

    if (goal != null) {
      final gy = y(goal!);
      final dash = Paint()
        ..color = AppColors.analyticsTeal.withValues(alpha: 0.8)
        ..strokeWidth = 1.2;
      for (var dx = leftPad; dx < size.width - rightPad; dx += 8) {
        canvas.drawLine(Offset(dx, gy),
            Offset(math.min(dx + 4, size.width - rightPad), gy), dash);
      }
    }

    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(points[i].date), y(points[i].value));
      if (i == 0) {
        line.moveTo(o.dx, o.dy);
      } else {
        line.lineTo(o.dx, o.dy);
      }
    }

    if (points.length > 1) {
      final fill = Path.from(line)
        ..lineTo(x(points.last.date), size.height - bottomPad)
        ..lineTo(x(points.first.date), size.height - bottomPad)
        ..close();
      canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0)],
          ).createShader(Offset.zero & size),
      );
    }

    final avg = average;
    if (avg != null && avg.length > 1) {
      final p = Path();
      for (var i = 0; i < avg.length; i++) {
        final o = Offset(x(avg[i].date), y(avg[i].value));
        if (i == 0) {
          p.moveTo(o.dx, o.dy);
        } else {
          p.lineTo(o.dx, o.dy);
        }
      }
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.analyticsTeal.withValues(alpha: 0.55),
      );
    }

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    final dot = Paint()..color = color;
    final ring = Paint()..color = AppColors.analyticsBgBottom;
    final showDots = points.length <= 40;
    for (var i = 0; i < points.length; i++) {
      final o = Offset(x(points[i].date), y(points[i].value));
      if (i == active) {
        canvas
          ..drawLine(
              Offset(o.dx, topPad),
              Offset(o.dx, size.height - bottomPad),
              Paint()
                ..color = AppColors.silverEdge
                ..strokeWidth = 1)
          ..drawCircle(o, 6, Paint()..color = color.withValues(alpha: 0.25))
          ..drawCircle(o, 4, ring)
          ..drawCircle(o, 3, dot);
      } else if (showDots || i == points.length - 1) {
        canvas
          ..drawCircle(o, 3, ring)
          ..drawCircle(o, 2, dot);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.points != points ||
      old.average != average ||
      old.goal != goal ||
      old.progress != progress ||
      old.active != active ||
      old.color != color;
}

// ─────────────────────────────────────────────────────────────────────
// Five-step meter (recovery scales)
// ─────────────────────────────────────────────────────────────────────

/// Five pips filled up to [value] (1–5).
class PipMeter extends StatelessWidget {
  const PipMeter({
    required this.value,
    required this.color,
    this.max = 5,
    this.pipWidth = 14,
    super.key,
  });

  final int value;
  final int max;
  final Color color;
  final double pipWidth;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= max; i++) ...[
          if (i > 1) const SizedBox(width: 3),
          AnimatedContainer(
            // Pips light up one after another when the value changes.
            duration: _reduceMotion(context)
                ? Duration.zero
                : AppConstants.animFast + Duration(milliseconds: 40 * i),
            curve: Curves.easeOutCubic,
            width: pipWidth,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              color: i <= value ? color : AppColors.analyticsTrack,
            ),
          ),
        ],
      ],
    );
  }
}
