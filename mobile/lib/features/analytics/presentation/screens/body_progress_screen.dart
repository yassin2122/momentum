import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/motion.dart';
import '../../../workouts/domain/entities/workout_enums.dart';
import '../../../workouts/domain/services/weight_units.dart';
import '../../domain/entities/body_progress.dart';
import '../../domain/services/body_trend.dart';
import '../providers/analytics_providers.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/analytics_chrome.dart';
import '../widgets/body_sheets.dart';

enum _ChartRange {
  m1(30, '1M'),
  m3(90, '3M'),
  y1(365, '1Y'),
  all(null, 'All');

  const _ChartRange(this.days, this.label);

  final int? days;
  final String label;
}

/// Bodyweight, measurements and private progress photos.
class BodyProgressScreen extends ConsumerStatefulWidget {
  const BodyProgressScreen({super.key});

  @override
  ConsumerState<BodyProgressScreen> createState() => _BodyProgressScreenState();
}

class _BodyProgressScreenState extends ConsumerState<BodyProgressScreen> {
  _ChartRange _range = _ChartRange.m3;

  void _addEntry() =>
      showAnalyticsSheet<void>(context, (_) => const AddBodyEntrySheet());

  void _addPhoto() =>
      showAnalyticsSheet<void>(context, (_) => const AddPhotoSheet());

  void _editGoal(BodyProgressData d) =>
      showAnalyticsSheet<void>(context, (_) => BodyGoalSheet(data: d));

  Future<void> _confirmDeleteEntry(BodyEntry e) async {
    final ok = await _confirm(
      context,
      title: 'Delete this entry?',
      message:
          'The measurement from ${DateFormat('d MMM yyyy').format(e.loggedOn)} '
          'will be removed.',
    );
    if (ok != true || !mounted) return;
    final r = await ref.read(bodyProgressRepositoryProvider).deleteEntry(e.id);
    if (!mounted) return;
    r.when(
      success: (_) => ref.invalidate(bodyProgressProvider),
      failure: (f) => _snack(f.message),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(bodyProgressProvider);
    final d = async.valueOrNull;
    final unit = ref.watch(bodyWeightUnitProvider);

    return AnalyticsScaffold(
      eyebrow: 'Bodyweight · measurements · photos',
      title: 'Body progress',
      accent: AppColors.analyticsSteel,
      glowCenter: const Alignment(-0.8, -1),
      onRefresh: () async => ref.invalidate(bodyProgressProvider),
      trailing: AnalyticsIconButton(
        icon: LucideIcons.plus,
        semanticLabel: 'Add measurement',
        color: AppColors.analyticsSteel,
        onPressed: _addEntry,
      ),
      children: [
        if (async.hasError && d == null)
          AnalyticsErrorPanel(
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(bodyProgressProvider),
          )
        else if (d == null)
          const Column(children: [
            AnalyticsSkeleton(height: 320),
            SizedBox(height: AppSpacing.sm),
            AnalyticsSkeleton(height: 96),
            SizedBox(height: AppSpacing.sm),
            AnalyticsSkeleton(height: 140),
          ])
        else if (d.entries.isEmpty) ...[
          AnalyticsEmptyPanel(
            icon: LucideIcons.ruler,
            title: 'Start your body log',
            message: 'Add your bodyweight or a measurement. One entry a '
                'week is plenty to see a trend.',
            accent: AppColors.analyticsSteel,
            actionLabel: 'Add first entry',
            onAction: _addEntry,
          ),
          const SizedBox(height: AppSpacing.lg),
          _PhotosSection(photos: d.photos, onAdd: _addPhoto),
        ] else ...[
          _TrendPanel(
            data: d,
            unit: unit,
            range: _range,
            onRange: (r) => setState(() => _range = r),
          ),
          const SizedBox(height: AppSpacing.sm),
          _GoalPanel(data: d, unit: unit, onEdit: () => _editGoal(d)),
          const SizedBox(height: AppSpacing.lg),
          _MeasurementGrid(data: d, unit: unit),
          const SizedBox(height: AppSpacing.lg),
          _PhotosSection(photos: d.photos, onAdd: _addPhoto),
          const SizedBox(height: AppSpacing.lg),
          _History(data: d, unit: unit, onDelete: _confirmDeleteEntry),
        ],
      ],
    );
  }
}

Future<bool?> _confirm(BuildContext context,
    {required String title, required String message}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.analyticsPanelTop,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large)),
      title: Text(title,
          style:
              AppTypography.titleLarge.copyWith(color: AppColors.silverBright)),
      content: Text(message,
          style: AppTypography.bodyMedium.copyWith(color: AppColors.silverDim)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Cancel',
              style:
                  AppTypography.labelLarge.copyWith(color: AppColors.silver)),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text('Delete',
              style: AppTypography.labelLarge
                  .copyWith(color: AppColors.analyticsCaution)),
        ),
      ],
    ),
  );
}

String _formatValue(BodyMeasure m, double canonical, WeightUnit unit) {
  if (m == BodyMeasure.weight) {
    return WeightUnits.format(WeightUnits.fromKg(canonical, unit));
  }
  return WeightUnits.format((canonical * 10).round() / 10);
}

String _unitOf(BodyMeasure m, WeightUnit unit) =>
    m == BodyMeasure.weight ? unit.dbValue : m.unit;

String _signed(double v) => v > 0
    ? '+${WeightUnits.format(v)}'
    : (v < 0 ? '−${WeightUnits.format(-v)}' : '0');

// ── Hero trend ─────────────────────────────────────────────────────────

class _TrendPanel extends ConsumerWidget {
  const _TrendPanel({
    required this.data,
    required this.unit,
    required this.range,
    required this.onRange,
  });

  final BodyProgressData data;
  final WeightUnit unit;
  final _ChartRange range;
  final ValueChanged<_ChartRange> onRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recorded = BodyTrend.recorded(data.entries);
    if (recorded.isEmpty) {
      // Only legacy height-only rows so far.
      return AnalyticsPanel(
        child: Text('Add your bodyweight or a measurement to see a trend.',
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.silverDim)),
      );
    }
    var measure = ref.watch(selectedBodyMeasureProvider);
    if (!recorded.contains(measure)) measure = recorded.first;

    final now = DateTime.now();
    final since = range.days == null
        ? null
        : DateTime(now.year, now.month, now.day - range.days!);
    final points = BodyTrend.series(data.entries, measure, since: since);
    final latest = BodyTrend.latest(data.entries, measure);
    final change = BodyTrend.change(points);
    final shownChange = change == null
        ? null
        : (measure == BodyMeasure.weight
            ? WeightUnits.fromKg(change.abs(), unit) * change.sign
            : (change * 10).round() / 10);
    final goalKg =
        measure == BodyMeasure.weight ? data.goal?.targetWeightKg : null;

    return AnalyticsPanel(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final m in recorded) ...[
                  _MeasureChip(
                    label: m.label,
                    selected: m == measure,
                    onTap: () => ref
                        .read(selectedBodyMeasureProvider.notifier)
                        .state = m,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      latest == null
                          ? 'No ${measure.label.toLowerCase()} yet'
                          : 'Latest · ${relativeDay(latest.date)}',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.silverDim),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: latest == null
                              ? MetalText(
                                  '—',
                                  style: AppTypography.numeric(
                                          AppTypography.displayLarge)
                                      .copyWith(fontSize: 52),
                                )
                              // Counts to the new value when the measure,
                              // unit or data changes.
                              : AnimatedNumber(
                                  value: latest.value,
                                  builder: (context, v) => MetalText(
                                    _formatValue(measure, v, unit),
                                    style: AppTypography.numeric(
                                            AppTypography.displayLarge)
                                        .copyWith(fontSize: 52),
                                  ),
                                ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Text(
                          _unitOf(measure, unit),
                          style: AppTypography.titleMedium
                              .copyWith(color: AppColors.silverDim),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (shownChange != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm, vertical: AppSpacing.xxs + 2),
                  decoration: BoxDecoration(
                    color: AppColors.analyticsSteelSoft,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(color: AppColors.analyticsPanelBorder),
                  ),
                  child: Text(
                    '${_signed(shownChange)} ${_unitOf(measure, unit)} · ${range.label}',
                    style: AppTypography.numeric(AppTypography.labelMedium)
                        .copyWith(color: AppColors.silverBright),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (points.isEmpty)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  'No ${measure.label.toLowerCase()} entries in this range.',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.silverDim),
                ),
              ),
            )
          else
            TrendLineChart(
              points: points,
              average: measure == BodyMeasure.weight && points.length >= 4
                  ? BodyTrend.rollingAverage(points)
                  : null,
              goal: goalKg,
              format: (v) => _formatValue(measure, v, unit),
              height: 180,
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AnalyticsSegmented<_ChartRange>(
                  options: _ChartRange.values,
                  selected: range,
                  labelOf: (r) => r.label,
                  onChanged: onRange,
                ),
              ),
            ],
          ),
          if (measure == BodyMeasure.weight && points.length >= 4) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const _Key(color: AppColors.analyticsSteel, label: 'Weigh-ins'),
                const SizedBox(width: AppSpacing.md),
                _Key(
                    color: AppColors.analyticsTeal.withValues(alpha: 0.6),
                    label: '7-day average'),
                if (goalKg != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  const _Key(
                      color: AppColors.analyticsTeal,
                      label: 'Goal',
                      dashed: true),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.color, required this.label, this.dashed = false});

  final Color color;
  final String label;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (dashed)
          Row(children: [
            for (var i = 0; i < 3; i++)
              Container(
                width: 4,
                height: 2,
                margin: const EdgeInsets.only(right: 2),
                color: color,
              ),
          ])
        else
          Container(width: 14, height: 2, color: color),
        const SizedBox(width: AppSpacing.xxs + 2),
        Text(label,
            style:
                AppTypography.labelSmall.copyWith(color: AppColors.silverDim)),
      ],
    );
  }
}

class _MeasureChip extends StatelessWidget {
  const _MeasureChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadius.pill);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected
            ? AppColors.analyticsSteel
            : AppColors.analyticsPanelBottom,
        shape: RoundedRectangleBorder(
          borderRadius: r,
          side: BorderSide(
              color: selected
                  ? AppColors.analyticsSteel
                  : AppColors.analyticsPanelBorder),
        ),
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Center(
              child: Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color:
                      selected ? AppColors.analyticsBgBottom : AppColors.silver,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Goal ───────────────────────────────────────────────────────────────

class _GoalPanel extends StatelessWidget {
  const _GoalPanel(
      {required this.data, required this.unit, required this.onEdit});

  final BodyProgressData data;
  final WeightUnit unit;
  final VoidCallback onEdit;

  static final _date = DateFormat('d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final goal = data.goal;
    final progress = BodyTrend.goalProgress(goal, data.entries);
    if (goal == null) {
      return AnalyticsPanel(
        onTap: onEdit,
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
        child: Row(
          children: [
            const Icon(LucideIcons.target,
                size: AppSizing.iconSm + 2, color: AppColors.analyticsTeal),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('Set a bodyweight goal (optional)',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.silverBright)),
            ),
            const Icon(LucideIcons.chevronRight,
                size: AppSizing.iconSm, color: AppColors.silverDeep),
          ],
        ),
      );
    }
    final target = _formatValue(BodyMeasure.weight, goal.targetWeightKg, unit);
    return AnalyticsPanel(
      onTap: onEdit,
      tint: AppColors.analyticsTeal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.target,
                  size: AppSizing.iconSm, color: AppColors.analyticsTeal),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'GOAL · $target ${unit.dbValue}'
                  '${goal.targetDate == null ? '' : ' BY ${_date.format(goal.targetDate!).toUpperCase()}'}',
                  style: AppTypography.overline
                      .copyWith(color: AppColors.analyticsTeal),
                ),
              ),
              Text('Edit',
                  style: AppTypography.labelMedium
                      .copyWith(color: AppColors.silverDim)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (progress == null)
            Text('Log a weigh-in to start tracking this goal.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.silverDim))
          else ...[
            Text(
              progress.reached
                  ? 'Goal reached'
                  : '${_formatValue(BodyMeasure.weight, progress.remaining, unit)} '
                      '${unit.dbValue} to go',
              style: AppTypography.titleLarge.copyWith(
                  color: AppColors.silverBright,
                  fontWeight: AppTypography.bold),
            ),
            const SizedBox(height: AppSpacing.sm),
            _GoalTrack(fraction: progress.fraction),
            const SizedBox(height: AppSpacing.xxs + 2),
            Row(
              children: [
                Text(
                  'Start ${_formatValue(BodyMeasure.weight, progress.start, unit)}',
                  style: AppTypography.numeric(AppTypography.labelSmall)
                      .copyWith(color: AppColors.silverDim),
                ),
                const Spacer(),
                Text(
                  '${(progress.fraction * 100).round()}%',
                  style: AppTypography.numeric(AppTypography.labelSmall)
                      .copyWith(color: AppColors.analyticsTeal),
                ),
                const Spacer(),
                Text(
                  'Target $target',
                  style: AppTypography.numeric(AppTypography.labelSmall)
                      .copyWith(color: AppColors.silverDim),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GoalTrack extends StatelessWidget {
  const _GoalTrack({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 10,
      child: LayoutBuilder(
        builder: (context, c) => Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.analyticsTrack,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: fraction),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Container(
                width: c.maxWidth * v,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  gradient: const LinearGradient(colors: [
                    AppColors.analyticsTealDeep,
                    AppColors.analyticsTeal,
                  ]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Measurement grid ───────────────────────────────────────────────────

class _MeasurementGrid extends StatelessWidget {
  const _MeasurementGrid({required this.data, required this.unit});

  final BodyProgressData data;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final recorded = BodyTrend.recorded(data.entries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AnalyticsLabel('Latest measurements'),
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - AppSpacing.sm) / 2;
            return Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final m in recorded)
                  SizedBox(
                      width: w,
                      child: _MeasureTile(m: m, data: data, unit: unit)),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MeasureTile extends StatelessWidget {
  const _MeasureTile({required this.m, required this.data, required this.unit});

  final BodyMeasure m;
  final BodyProgressData data;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final series = BodyTrend.series(data.entries, m);
    final latest = series.last;
    final change = BodyTrend.change(series);
    final shown = change == null
        ? null
        : (m == BodyMeasure.weight
            ? WeightUnits.fromKg(change.abs(), unit) * change.sign
            : (change * 10).round() / 10);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.analyticsPanelBottom,
        borderRadius: BorderRadius.circular(AppRadius.medium + 4),
        border: Border.all(color: AppColors.analyticsPanelBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(m.label.toUpperCase(),
              style:
                  AppTypography.overline.copyWith(color: AppColors.silverDim)),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _formatValue(m, latest.value, unit),
                style: AppTypography.numeric(AppTypography.headlineSmall)
                    .copyWith(color: AppColors.silverBright),
              ),
              const SizedBox(width: 3),
              Text(_unitOf(m, unit),
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.silverDim)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            shown == null
                ? relativeDay(latest.date)
                : '${_signed(shown)} since ${DateFormat('d MMM').format(series.first.date)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: AppColors.silverDim),
          ),
        ],
      ),
    );
  }
}

// ── Photos ─────────────────────────────────────────────────────────────

class _PhotosSection extends StatelessWidget {
  const _PhotosSection({required this.photos, required this.onAdd});

  final List<ProgressPhoto> photos;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnalyticsLabel(
          'Progress photos',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(LucideIcons.lock,
                  size: 12, color: AppColors.silverDim),
              const SizedBox(width: 4),
              Text('Private',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.silverDim)),
            ],
          ),
        ),
        SizedBox(
          height: 168,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _AddPhotoTile(onTap: onAdd),
              for (var i = 0; i < photos.length; i++) ...[
                const SizedBox(width: AppSpacing.sm),
                _PhotoThumb(
                  photo: photos[i],
                  onTap: () => Navigator.of(context).push(
                    PageRouteBuilder<void>(
                      opaque: false,
                      barrierColor: AppColors.analyticsScrim,
                      pageBuilder: (_, __, ___) =>
                          PhotoViewer(photos: photos, initial: i),
                      transitionsBuilder: (_, a, __, child) =>
                          FadeTransition(opacity: a, child: child),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (photos.length >= 2) ...[
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: AnalyticsButton(
              label: 'Compare first & latest',
              outlined: true,
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder<void>(
                  opaque: false,
                  barrierColor: AppColors.analyticsScrim,
                  pageBuilder: (_, __, ___) =>
                      PhotoCompare(before: photos.last, after: photos.first),
                  transitionsBuilder: (_, a, __, child) =>
                      FadeTransition(opacity: a, child: child),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AddPhotoTile extends StatelessWidget {
  const _AddPhotoTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadius.large);
    return Semantics(
      button: true,
      label: 'Add progress photo',
      child: Material(
        color: AppColors.analyticsPanelBottom,
        shape: RoundedRectangleBorder(
          borderRadius: r,
          side: const BorderSide(color: AppColors.silverDeep),
        ),
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: SizedBox(
            width: 112,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(LucideIcons.camera,
                    size: AppSizing.iconMd, color: AppColors.analyticsSteel),
                const SizedBox(height: AppSpacing.xs),
                Text('Add photo',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.silver)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  const _PhotoThumb({required this.photo, required this.onTap});

  final ProgressPhoto photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadius.large);
    return Semantics(
      button: true,
      label:
          '${photo.pose.label} photo, ${DateFormat('d MMM yyyy').format(photo.takenOn)}',
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: r,
          child: SizedBox(
            width: 120,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _PrivateImage(url: photo.url, cacheWidth: 360),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(AppSpacing.xs,
                        AppSpacing.lg, AppSpacing.xs, AppSpacing.xs),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.analyticsBgBottom.withValues(alpha: 0),
                          AppColors.analyticsBgBottom.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Text(
                      '${DateFormat('d MMM').format(photo.takenOn)} · ${photo.pose.label}',
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.silverBright),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Private photos load from short-lived signed URLs with [Image.network]
/// (in-memory cache only) — never written to the on-disk image cache.
class _PrivateImage extends StatelessWidget {
  const _PrivateImage(
      {required this.url, this.cacheWidth, this.fit = BoxFit.cover});

  final String? url;
  final int? cacheWidth;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: AppColors.analyticsTrack,
      child: Center(
        child: Icon(LucideIcons.lock,
            size: AppSizing.iconSm, color: AppColors.silverDeep),
      ),
    );
    if (url == null) return placeholder;
    return Image.network(
      url!,
      fit: fit,
      cacheWidth: cacheWidth,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => placeholder,
      // Fade in only when the photo actually had to load; one already in
      // memory paints instantly.
      frameBuilder: (context, child, frame, sync) => sync
          ? child
          : AnimatedOpacity(
              opacity: frame == null ? 0 : 1,
              duration: AppConstants.animMedium,
              curve: Curves.easeOut,
              child: child,
            ),
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : placeholder,
    );
  }
}

/// Full-screen, swipeable photo viewer with delete.
class PhotoViewer extends ConsumerStatefulWidget {
  const PhotoViewer({required this.photos, required this.initial, super.key});

  final List<ProgressPhoto> photos;
  final int initial;

  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer> {
  late final PageController _pages =
      PageController(initialPage: widget.initial);
  late int _index = widget.initial;
  bool _deleting = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final photo = widget.photos[_index];
    final ok = await _confirm(context,
        title: 'Delete this photo?',
        message: 'It will be removed from your private storage.');
    if (ok != true || !mounted) return;
    setState(() => _deleting = true);
    final r = await ref.read(bodyProgressRepositoryProvider).deletePhoto(photo);
    if (!mounted) return;
    r.when(
      success: (_) {
        ref.invalidate(bodyProgressProvider);
        Navigator.of(context).pop();
      },
      failure: (f) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(f.message)));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.photos[_index];
    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  AnalyticsIconButton(
                    icon: LucideIcons.x,
                    semanticLabel: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      '${DateFormat('EEE d MMM yyyy').format(p.takenOn)} · ${p.pose.label}',
                      style: AppTypography.titleSmall
                          .copyWith(color: AppColors.silverBright),
                    ),
                  ),
                  AnalyticsIconButton(
                    icon: LucideIcons.trash2,
                    semanticLabel: 'Delete photo',
                    color: AppColors.analyticsCaution,
                    onPressed: _deleting ? null : _delete,
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pages,
                itemCount: widget.photos.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  maxScale: 4,
                  child: _PrivateImage(
                      url: widget.photos[i].url, fit: BoxFit.contain),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '${_index + 1} / ${widget.photos.length}',
                style: AppTypography.numeric(AppTypography.labelMedium)
                    .copyWith(color: AppColors.silverDim),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Side-by-side first vs latest photo.
class PhotoCompare extends StatelessWidget {
  const PhotoCompare({required this.before, required this.after, super.key});

  final ProgressPhoto before;
  final ProgressPhoto after;

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('d MMM yyyy');
    final days = after.takenOn.difference(before.takenOn).inDays.abs();
    Widget side(ProgressPhoto p, String label) => Expanded(
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  child: _PrivateImage(url: p.url, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(label.toUpperCase(),
                  style: AppTypography.overline
                      .copyWith(color: AppColors.silverDim)),
              Text(f.format(p.takenOn),
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.silverBright)),
            ],
          ),
        );
    return Scaffold(
      backgroundColor: AppColors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            children: [
              Row(
                children: [
                  AnalyticsIconButton(
                    icon: LucideIcons.x,
                    semanticLabel: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: MetalText('$days days apart',
                        style: AppTypography.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: Row(
                  children: [
                    side(before, 'First'),
                    const SizedBox(width: AppSpacing.sm),
                    side(after, 'Latest'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── History ────────────────────────────────────────────────────────────

class _History extends StatefulWidget {
  const _History(
      {required this.data, required this.unit, required this.onDelete});

  final BodyProgressData data;
  final WeightUnit unit;
  final ValueChanged<BodyEntry> onDelete;

  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  int _shown = 8;
  static final _date = DateFormat('EEE d MMM yyyy');

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AnalyticsLabel('History'),
        AnalyticsPanel(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Column(
            children: [
              for (final e in entries.take(_shown))
                Container(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                      AppSpacing.sm, AppSpacing.xs, AppSpacing.sm),
                  decoration: const BoxDecoration(
                    border: Border(
                        bottom: BorderSide(color: AppColors.analyticsHairline)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_date.format(e.loggedOn),
                                style: AppTypography.labelLarge
                                    .copyWith(color: AppColors.silverBright)),
                            const SizedBox(height: 2),
                            Text(
                              [
                                for (final m in BodyMeasure.values)
                                  if (e[m] != null)
                                    '${m.label} ${_formatValue(m, e[m]!, widget.unit)} ${_unitOf(m, widget.unit)}',
                              ].join(' · '),
                              style: AppTypography.caption
                                  .copyWith(color: AppColors.silverDim),
                            ),
                            if (e.note != null && e.note!.isNotEmpty)
                              Text('“${e.note}”',
                                  style: AppTypography.caption.copyWith(
                                      color: AppColors.silverDim,
                                      fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete entry',
                        icon: const Icon(LucideIcons.trash2,
                            size: AppSizing.iconSm,
                            color: AppColors.silverDeep),
                        onPressed: () => widget.onDelete(e),
                      ),
                    ],
                  ),
                ),
              if (entries.length > _shown)
                TextButton(
                  onPressed: () => setState(() => _shown += 20),
                  child: Text('Show more',
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.silver)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
