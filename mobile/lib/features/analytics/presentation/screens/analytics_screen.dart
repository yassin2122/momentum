import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/motion.dart';
import '../../../muscle_map/domain/entities/muscle.dart';
import '../../../muscle_map/domain/services/muscle_highlight.dart';
import '../../../muscle_map/presentation/providers/muscle_map_providers.dart';
import '../../../muscle_map/presentation/widgets/muscle_map_view.dart';
import '../../../workouts/domain/services/weight_units.dart';
import '../../domain/entities/body_progress.dart';
import '../../domain/entities/muscle_group_distribution.dart';
import '../../domain/services/body_trend.dart';
import '../providers/analytics_providers.dart';
import '../widgets/analytics_chrome.dart';
import '../widgets/analytics_charts.dart';

/// Entry point from the Dashboard's Analytics button: one tile per
/// feature, each with its own shape and a live preview of real data.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() async {
      ref
        ..invalidate(muscleActivityProvider)
        ..invalidate(muscleGroupDistributionProvider)
        ..invalidate(bodyProgressProvider)
        ..invalidate(recoveryOverviewProvider);
    }

    return AnalyticsScaffold(
      eyebrow: 'Train · Analytics',
      title: 'Analytics',
      subtitle: 'Built only from what you log.',
      accent: AppColors.analyticsTeal,
      onRefresh: refresh,
      children: [
        _HologramTile(onTap: () => context.push(AppRoutes.muscleMap)),
        const SizedBox(height: AppSpacing.sm),
        _DistributionTile(
            onTap: () => context.push(AppRoutes.analyticsDistribution)),
        const SizedBox(height: AppSpacing.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _BodyTile(
                    onTap: () => context.push(AppRoutes.analyticsBody)),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _RecoveryTile(
                    onTap: () => context.push(AppRoutes.analyticsRecovery)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Icon(LucideIcons.lock,
                size: AppSizing.iconSm, color: AppColors.silverDim),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                'Body photos and check-ins are private to you. A Captain '
                'only sees body stats if you turn on that permission.',
                style:
                    AppTypography.caption.copyWith(color: AppColors.silverDim),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Small arrow chip in a tile's corner.
class _Go extends StatelessWidget {
  const _Go({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSpacing.xl,
      height: AppSpacing.xl,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Icon(LucideIcons.arrowRight, size: AppSizing.iconSm, color: color),
    );
  }
}

class _TileTitle extends StatelessWidget {
  const _TileTitle({required this.kicker, required this.title, this.color});

  final String kicker;
  final String title;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          kicker.toUpperCase(),
          style: AppTypography.overline
              .copyWith(color: color ?? AppColors.silverDim),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          title,
          style: AppTypography.titleLarge.copyWith(
            color: AppColors.silverBright,
            fontWeight: AppTypography.bold,
          ),
        ),
      ],
    );
  }
}

// ── 1. Hologram: tall hero, body on the right ──────────────────────────

class _HologramTile extends ConsumerWidget {
  const _HologramTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = ref.watch(muscleActivityProvider);
    final data = report.valueOrNull;
    final intensities = data?.intensities ?? const <Muscle, double>{};
    final trained = data?.byMuscle.length ?? 0;
    // Grows with the user's text size so the copy never clips.
    final height =
        math.max(248.0, MediaQuery.textScalerOf(context).scale(16) / 16 * 248);
    return Semantics(
      button: true,
      label: 'Muscle hologram',
      child: PressScale(
        builder: (context, onHighlight) => Material(
          color: AppColors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.cardLarge),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.cardLarge),
              border: Border.all(
                  color: AppColors.anatomyCyan.withValues(alpha: 0.22)),
              gradient: RadialGradient(
                center: const Alignment(0.55, 0),
                radius: 0.9,
                colors: [
                  AppColors.anatomyCyanDeep.withValues(alpha: 0.35),
                  AppColors.anatomyBody,
                ],
              ),
            ),
            child: InkWell(
              onTap: onTap,
              onHighlightChanged: onHighlight,
              child: Stack(
                children: [
                  // Faint scan lines — the hologram's signature.
                  const Positioned.fill(
                      child: CustomPaint(painter: _ScanLines())),
                  Positioned(
                    right: -AppSpacing.md,
                    top: AppSpacing.sm,
                    bottom: AppSpacing.sm,
                    width: 200,
                    child: IgnorePointer(
                      child: MuscleMapView(
                        view: MuscleHighlight.bestView(intensities),
                        intensities: intensities,
                        semanticLabel: 'Body map preview',
                        scanIn: true,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _TileTitle(
                          kicker: 'Hologram',
                          title: 'Muscle\nhologram',
                          color: AppColors.anatomyCyan,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'Front & back · tap any muscle',
                          style: AppTypography.caption
                              .copyWith(color: AppColors.silverDim),
                        ),
                        const Spacer(),
                        AnalyticsSwap(
                          child: report.isLoading && data == null
                              ? const AnalyticsSkeleton(
                                  key: ValueKey('loading'),
                                  height: 40,
                                  width: 110,
                                )
                              : report.hasError && data == null
                                  ? Text(
                                      "Couldn't load",
                                      key: const ValueKey('error'),
                                      style: AppTypography.labelMedium
                                          .copyWith(color: AppColors.silverDim),
                                    )
                                  : Column(
                                      key: const ValueKey('data'),
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        AnimatedNumber(
                                          value: trained.toDouble(),
                                          builder: (context, v) => Text(
                                            '${v.round()}',
                                            style: AppTypography.numeric(
                                                    AppTypography.displayMedium)
                                                .copyWith(
                                                    color: AppColors
                                                        .anatomyCyanBright),
                                          ),
                                        ),
                                        Text(
                                          trained == 0
                                              ? 'No trained muscles\nin ${data?.windowDays ?? 14} days'
                                              : '${trained == 1 ? 'muscle' : 'muscles'} trained\n'
                                                  'in ${data!.windowDays} days',
                                          style: AppTypography.labelMedium
                                              .copyWith(
                                                  color: AppColors.silver),
                                        ),
                                      ],
                                    ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        const _Go(color: AppColors.anatomyCyan),
                      ],
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

class _ScanLines extends CustomPainter {
  const _ScanLines();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.anatomyCyan.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    for (var y = 0.0; y < size.height; y += 4) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(_ScanLines old) => false;
}

// ── 2. Distribution: wide strip with a composition bar ─────────────────

/// Teal shades for the top groups, deepest last; "Other" is silver.
const List<Color> distributionPalette = AppColors.analyticsSeries;

class _DistributionTile extends ConsumerWidget {
  const _DistributionTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async =
        ref.watch(muscleGroupDistributionProvider(DistributionRange.weeks4));
    final d = async.valueOrNull;
    return AnalyticsPanel(
      onTap: onTap,
      tint: AppColors.analyticsTeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _TileTitle(
                  kicker: 'Distribution · 4 weeks',
                  title: 'Working sets by muscle group',
                  color: AppColors.analyticsTeal,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              _Go(color: AppColors.analyticsTeal),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          AnalyticsSwap(
            child: async.isLoading && d == null
                ? const AnalyticsSkeleton(key: ValueKey('loading'), height: 44)
                : async.hasError && d == null
                    ? Text("Couldn't load your workouts.",
                        key: const ValueKey('error'),
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.silverDim))
                    : d == null || d.isEmpty
                        ? Text('Finish a workout to see where your sets go.',
                            key: const ValueKey('empty'),
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.silverDim))
                        : _CompositionBar(key: const ValueKey('data'), d: d),
          ),
        ],
      ),
    );
  }
}

class _CompositionBar extends StatelessWidget {
  const _CompositionBar({required this.d, super.key});

  final MuscleGroupDistribution d;

  @override
  Widget build(BuildContext context) {
    final top = d.groups.where((g) => g.primarySets > 0).take(4).toList();
    final other =
        d.totalPrimarySets - top.fold<int>(0, (s, g) => s + g.primarySets);
    final total = d.totalPrimarySets;
    if (total == 0) {
      return Text('Only assisting sets logged so far.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.silverDim));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Sweeps in left to right once, like the ring it summarises.
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration:
              reduceMotionOf(context) ? Duration.zero : AppConstants.animSlow,
          curve: Curves.easeOutCubic,
          builder: (context, t, child) => ClipRect(
            child: Align(
              alignment: Alignment.centerLeft,
              widthFactor: t,
              child: child,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (var i = 0; i < top.length; i++)
                    Expanded(
                      flex: top[i].primarySets,
                      child: Container(
                        margin: const EdgeInsets.only(right: 2),
                        color: distributionPalette[i],
                      ),
                    ),
                  if (other > 0)
                    Expanded(
                        flex: other,
                        child: Container(color: AppColors.silverDeep)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.xxs,
          children: [
            for (var i = 0; i < top.length; i++)
              _Legend(
                color: distributionPalette[i],
                text:
                    '${top[i].label} ${(top[i].primarySets / total * 100).round()}%',
              ),
            if (other > 0)
              _Legend(
                color: AppColors.silverDeep,
                text: 'Other ${(other / total * 100).round()}%',
              ),
          ],
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.text});

  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AppSpacing.xxs),
        Text(text,
            style: AppTypography.labelMedium.copyWith(color: AppColors.silver)),
      ],
    );
  }
}

// ── 3. Body: steel numeral + sparkline ─────────────────────────────────

class _BodyTile extends ConsumerWidget {
  const _BodyTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(bodyProgressProvider);
    final unit = ref.watch(bodyWeightUnitProvider);
    final d = async.valueOrNull;
    final weights = d == null
        ? const <TrendPoint>[]
        : BodyTrend.series(d.entries, BodyMeasure.weight);
    final last = weights.isEmpty ? null : weights.last;
    return AnalyticsPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TileTitle(
              kicker: 'Body',
              title: 'Body\nprogress',
              color: AppColors.analyticsSteel),
          const SizedBox(height: AppSpacing.md),
          AnalyticsSwap(
            child: async.isLoading && d == null
                ? const AnalyticsSkeleton(key: ValueKey('loading'), height: 56)
                : last == null
                    ? Text(
                        async.hasError
                            ? "Couldn't load"
                            : 'Log your first\nweigh-in',
                        key: const ValueKey('empty'),
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.silverDim),
                      )
                    : Column(
                        key: const ValueKey('data'),
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Flexible(
                                child: AnimatedNumber(
                                  value: WeightUnits.fromKg(last.value, unit),
                                  builder: (context, v) => MetalText(
                                    // One decimal while counting; the
                                    // exact value once it lands.
                                    WeightUnits.format(v ==
                                            WeightUnits.fromKg(last.value, unit)
                                        ? v
                                        : (v * 10).round() / 10),
                                    style: AppTypography.numeric(
                                        AppTypography.headlineLarge),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xxs),
                              Text(unit.dbValue,
                                  style: AppTypography.labelMedium
                                      .copyWith(color: AppColors.silverDim)),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: reduceMotionOf(context)
                                ? Duration.zero
                                : AppConstants.animSlow * 2,
                            curve: Curves.easeOutCubic,
                            builder: (context, t, _) => SizedBox(
                              height: 28,
                              child: CustomPaint(
                                size: const Size(double.infinity, 28),
                                painter: _Sparkline(
                                  weights.length > 20
                                      ? weights.sublist(weights.length - 20)
                                      : weights,
                                  progress: t,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
          ),
          const Spacer(),
          const SizedBox(height: AppSpacing.sm),
          const Align(
            alignment: Alignment.centerRight,
            child: _Go(color: AppColors.analyticsSteel),
          ),
        ],
      ),
    );
  }
}

class _Sparkline extends CustomPainter {
  _Sparkline(this.points, {this.progress = 1});

  final List<TrendPoint> points;

  /// 0–1: how much of the line is drawn, left to right.
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) {
      canvas.drawLine(
          Offset(0, size.height / 2),
          Offset(size.width, size.height / 2),
          Paint()..color = AppColors.silverDeep);
      return;
    }
    var lo = points.first.value, hi = points.first.value;
    for (final p in points) {
      if (p.value < lo) lo = p.value;
      if (p.value > hi) hi = p.value;
    }
    final span = hi - lo < 0.1 ? 0.1 : hi - lo;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i / (points.length - 1) * size.width;
      final y =
          size.height - (points[i].value - lo) / span * (size.height - 4) - 2;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas
      ..save()
      ..clipRect(
          Rect.fromLTWH(-2, -2, size.width * progress + 4, size.height + 4))
      ..drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = AppColors.analyticsSteel,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_Sparkline old) =>
      old.progress != progress || old.points != points;
}

// ── 4. Recovery: today's state as three meters ─────────────────────────

class _RecoveryTile extends ConsumerWidget {
  const _RecoveryTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recoveryOverviewProvider);
    final today = async.valueOrNull?.today;
    return AnalyticsPanel(
      onTap: onTap,
      tint: AppColors.analyticsDusk,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TileTitle(
              kicker: 'Recovery',
              title: 'Daily\ncheck-in',
              color: AppColors.analyticsDusk),
          const SizedBox(height: AppSpacing.md),
          AnalyticsSwap(
            child: async.isLoading && async.valueOrNull == null
                ? const AnalyticsSkeleton(key: ValueKey('loading'), height: 56)
                : async.hasError && async.valueOrNull == null
                    ? Text("Couldn't load",
                        key: const ValueKey('error'),
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.silverDim))
                    : today == null
                        ? Container(
                            key: const ValueKey('empty'),
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.sm,
                                vertical: AppSpacing.xs),
                            decoration: BoxDecoration(
                              color: AppColors.analyticsDuskSoft,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.pill),
                              border: Border.all(
                                  color: AppColors.analyticsDusk
                                      .withValues(alpha: 0.35)),
                            ),
                            child: Text(
                              'Check in · 20 sec',
                              style: AppTypography.labelMedium.copyWith(
                                  color: AppColors.analyticsDusk,
                                  fontWeight: AppTypography.semiBold),
                            ),
                          )
                        : Column(
                            key: const ValueKey('data'),
                            children: [
                              _MeterRow(label: 'Energy', value: today.energy),
                              const SizedBox(height: AppSpacing.xxs),
                              _MeterRow(label: 'Sore', value: today.soreness),
                              const SizedBox(height: AppSpacing.xxs),
                              _MeterRow(label: 'Fatigue', value: today.fatigue),
                            ],
                          ),
          ),
          const Spacer(),
          const SizedBox(height: AppSpacing.sm),
          const Align(
            alignment: Alignment.centerRight,
            child: _Go(color: AppColors.analyticsDusk),
          ),
        ],
      ),
    );
  }
}

class _MeterRow extends StatelessWidget {
  const _MeterRow({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(label,
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.silverDim)),
        ),
        Flexible(
          child: PipMeter(
              value: value, color: AppColors.analyticsDusk, pipWidth: 9),
        ),
      ],
    );
  }
}
