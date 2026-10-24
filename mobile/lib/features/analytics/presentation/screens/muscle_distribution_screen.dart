import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/muscle_group_distribution.dart';
import '../providers/analytics_providers.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/analytics_chrome.dart';

/// Working sets per library muscle group, from completed workouts.
class MuscleDistributionScreen extends ConsumerStatefulWidget {
  const MuscleDistributionScreen({super.key});

  @override
  ConsumerState<MuscleDistributionScreen> createState() =>
      _MuscleDistributionScreenState();
}

class _MuscleDistributionScreenState
    extends ConsumerState<MuscleDistributionScreen> {
  /// Group lifted on the ring (ring segment index).
  int? _focus;

  Future<void> _openGroup(MuscleGroupStat g, MuscleGroupDistribution d) {
    return showAnalyticsSheet<void>(
      context,
      (_) => MuscleGroupDetailSheet(stat: g, distribution: d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final range = ref.watch(distributionRangeProvider);
    final async = ref.watch(muscleGroupDistributionProvider(range));
    final d = async.valueOrNull;

    return AnalyticsScaffold(
      eyebrow: 'Working sets by muscle group',
      title: 'Distribution',
      accent: AppColors.analyticsTeal,
      glowCenter: const Alignment(0, -0.6),
      onRefresh: () async =>
          ref.invalidate(muscleGroupDistributionProvider(range)),
      children: [
        AnalyticsSegmented<DistributionRange>(
          options: DistributionRange.values,
          selected: range,
          labelOf: (r) => r.short,
          onChanged: (r) {
            setState(() => _focus = null);
            ref.read(distributionRangeProvider.notifier).state = r;
          },
        ),
        const SizedBox(height: AppSpacing.lg),
        if (async.hasError && d == null)
          AnalyticsErrorPanel(
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(muscleGroupDistributionProvider(range)),
          )
        else if (d == null)
          const _LoadingBody()
        else if (d.isEmpty)
          AnalyticsEmptyPanel(
            icon: LucideIcons.dumbbell,
            title: d.workoutCount == 0
                ? 'No completed workouts yet'
                : 'No muscle data for these workouts',
            message: d.workoutCount == 0
                ? 'Nothing finished in the ${range.phrase}. Complete a workout '
                    'and its working sets will show up here.'
                : 'The exercises you logged in the ${range.phrase} have no '
                    'muscle groups in the library yet.',
            accent: AppColors.analyticsTeal,
            actionLabel: 'Go to Train',
            onAction: () => context.go(AppRoutes.train),
          )
        else ...[
          AnimatedOpacity(
            opacity: async.isLoading ? 0.5 : 1,
            duration: AppConstants.animFast,
            child: _RingPanel(
              d: d,
              focus: _focus,
              onFocus: (i) => setState(() => _focus = _focus == i ? null : i),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _RegionSplit(d: d),
          const SizedBox(height: AppSpacing.lg),
          AnalyticsLabel('Ranked · tap for details',
              trailing: Text('sets',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.silverDim))),
          AnalyticsPanel(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              children: [
                for (var i = 0; i < d.groups.length; i++)
                  _GroupRow(
                    stat: d.groups[i],
                    rank: i + 1,
                    max: d.groups.first.totalSets,
                    color: i < AppColors.analyticsSeries.length
                        ? AppColors.analyticsSeries[i]
                        : AppColors.silver,
                    onTap: () => _openGroup(d.groups[i], d),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _Notes(d: d),
        ],
      ],
    );
  }
}

class _LoadingBody extends StatelessWidget {
  const _LoadingBody();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        AnalyticsSkeleton(height: 300),
        SizedBox(height: AppSpacing.sm),
        AnalyticsSkeleton(height: 72),
        SizedBox(height: AppSpacing.lg),
        AnalyticsSkeleton(height: 240),
      ],
    );
  }
}

class _RingPanel extends StatelessWidget {
  const _RingPanel({required this.d, required this.focus, required this.onFocus});

  final MuscleGroupDistribution d;
  final int? focus;
  final ValueChanged<int> onFocus;

  @override
  Widget build(BuildContext context) {
    const series = AppColors.analyticsSeries;
    final shown = d.groups.where((g) => g.primarySets > 0).take(series.length).toList();
    final other = d.totalPrimarySets - shown.fold<int>(0, (s, g) => s + g.primarySets);
    final segments = [
      for (var i = 0; i < shown.length; i++)
        RingSegment(shown[i].primarySets.toDouble(), series[i]),
      if (other > 0) RingSegment(other.toDouble(), AppColors.silverDeep),
    ];
    final f = focus != null && focus! < shown.length ? shown[focus!] : null;

    return AnalyticsPanel(
      tint: AppColors.analyticsTeal,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
      child: Column(
        children: [
          CompositionRing(
            segments: segments,
            selected: f == null ? null : focus,
            size: 232,
            center: AnimatedSwitcher(
              duration: AppConstants.animFast,
              child: Column(
                key: ValueKey(f?.group),
                mainAxisSize: MainAxisSize.min,
                children: [
                  MetalText(
                    f == null ? '${d.workingSets}' : '${f.primarySets}',
                    style: AppTypography.numeric(AppTypography.displayLarge)
                        .copyWith(fontSize: 48),
                  ),
                  Text(
                    f == null
                        ? 'working sets'
                        : '${f.label} · ${(d.shareOf(f) * 100).round()}%',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.silver),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    '${d.workoutCount} ${d.workoutCount == 1 ? 'workout' : 'workouts'}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.silverDim),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < shown.length; i++)
                _ChipKey(
                  color: series[i],
                  label: shown[i].label,
                  selected: focus == i,
                  onTap: () => onFocus(i),
                ),
              if (other > 0)
                const _ChipKey(color: AppColors.silverDeep, label: 'Other'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChipKey extends StatelessWidget {
  const _ChipKey({
    required this.color,
    required this.label,
    this.selected = false,
    this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadius.pill);
    return Semantics(
      button: onTap != null,
      selected: selected,
      child: Material(
        color: selected ? color.withValues(alpha: 0.16) : AppColors.analyticsPanelBottom,
        shape: RoundedRectangleBorder(
          borderRadius: r,
          side: BorderSide(
              color: selected ? color : AppColors.analyticsPanelBorder),
        ),
        child: InkWell(
          borderRadius: r,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xxs + 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: AppSpacing.xxs + 2),
                Text(label,
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

/// Upper / lower / core share as three columns with hairline gauges.
class _RegionSplit extends StatelessWidget {
  const _RegionSplit({required this.d});

  final MuscleGroupDistribution d;

  @override
  Widget build(BuildContext context) {
    final regions = d.regionSets;
    final total = d.totalPrimarySets;
    return AnalyticsPanel(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          for (final r in BodyRegion.values) ...[
            if (r != BodyRegion.values.first)
              Container(
                width: 1,
                height: 40,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                color: AppColors.analyticsHairline,
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.label,
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.silverDim)),
                  const SizedBox(height: 2),
                  Text(
                    total == 0
                        ? '—'
                        : '${(regions[r]! / total * 100).round()}%',
                    style: AppTypography.numeric(AppTypography.titleLarge)
                        .copyWith(color: AppColors.silverBright),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: total == 0 ? 0 : regions[r]! / total,
                      minHeight: 3,
                      backgroundColor: AppColors.analyticsTrack,
                      color: AppColors.analyticsTeal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GroupRow extends StatelessWidget {
  const _GroupRow({
    required this.stat,
    required this.rank,
    required this.max,
    required this.color,
    required this.onTap,
  });

  final MuscleGroupStat stat;
  final int rank;
  final int max;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryFrac = max == 0 ? 0.0 : stat.primarySets / max;
    final totalFrac = max == 0 ? 0.0 : stat.totalSets / max;
    return Semantics(
      button: true,
      label: '${stat.label}: ${stat.primarySets} working sets, '
          '${stat.secondarySets} assisting',
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  rank.toString().padLeft(2, '0'),
                  style: AppTypography.numeric(AppTypography.labelSmall)
                      .copyWith(color: AppColors.silverDeep),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            stat.label,
                            style: AppTypography.titleSmall
                                .copyWith(color: AppColors.silverBright),
                          ),
                        ),
                        Text(
                          '${stat.primarySets}',
                          style: AppTypography.numeric(AppTypography.titleMedium)
                              .copyWith(color: AppColors.silverBright),
                        ),
                        if (stat.secondarySets > 0)
                          Text(
                            '  +${stat.secondarySets}',
                            style: AppTypography.numeric(AppTypography.labelMedium)
                                .copyWith(color: AppColors.silverDim),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs + 2),
                    SizedBox(
                      height: 6,
                      child: LayoutBuilder(
                        builder: (context, c) => Stack(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.analyticsTrack,
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                            Container(
                              width: c.maxWidth * totalFrac,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.28),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                            Container(
                              width: c.maxWidth * primaryFrac,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: [
                                  color.withValues(alpha: 0.6),
                                  color,
                                ]),
                                borderRadius:
                                    BorderRadius.circular(AppRadius.pill),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Icon(LucideIcons.chevronRight,
                  size: 16, color: AppColors.silverDeep),
            ],
          ),
        ),
      ),
    );
  }
}

class _Notes extends StatelessWidget {
  const _Notes({required this.d});

  final MuscleGroupDistribution d;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.caption.copyWith(color: AppColors.silverDim);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Each completed working set counts once for every muscle group the '
          'exercise lists as primary; "+N" are sets where the group only '
          'assists. Warm-ups and unfinished workouts are left out.',
          style: style,
        ),
        if (d.unmappedExercises.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No muscle data yet for: ${d.unmappedExercises.join(', ')}',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ],
      ],
    );
  }
}

/// A muscle group's training details within the chosen range.
class MuscleGroupDetailSheet extends StatelessWidget {
  const MuscleGroupDetailSheet({
    required this.stat,
    required this.distribution,
    super.key,
  });

  final MuscleGroupStat stat;
  final MuscleGroupDistribution distribution;

  static final _day = DateFormat('EEE d MMM');
  static final _short = DateFormat('d/M');
  static final _weekday = DateFormat('E');

  @override
  Widget build(BuildContext context) {
    final d = distribution;
    final last = stat.lastTrained;
    final labels = [
      for (final s in d.bucketStarts)
        d.bucketDays == 1 ? _weekday.format(s).substring(0, 1) : _short.format(s),
    ];
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.xl),
        children: [
          AnalyticsSheetHeader(
            title: stat.label,
            subtitle: last == null
                ? '${stat.region.label} · not trained as a primary target'
                : '${stat.region.label} · last trained ${relativeDay(last).toLowerCase()}',
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              _Stat(value: '${stat.primarySets}', label: 'working sets'),
              const SizedBox(width: AppSpacing.sm),
              _Stat(value: '${stat.secondarySets}', label: 'assisting'),
              const SizedBox(width: AppSpacing.sm),
              _Stat(
                value: '${(d.shareOf(stat) * 100).round()}%',
                label: 'of all sets',
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AnalyticsLabel(d.bucketDays == 1 ? 'Sets per day' : 'Sets per week'),
          ColumnBars(
            values: [for (final v in stat.bucketSets) v.toDouble()],
            labels: labels,
            color: AppColors.analyticsTeal,
            showValues: true,
            height: 110,
          ),
          const SizedBox(height: AppSpacing.lg),
          const AnalyticsLabel('Exercises'),
          for (final e in stat.exerciseSets.entries)
            _Line(
              title: e.key,
              trailing: '${e.value} ${e.value == 1 ? 'set' : 'sets'}',
            ),
          const SizedBox(height: AppSpacing.lg),
          const AnalyticsLabel('Recent workouts'),
          for (final s in stat.sessions.take(8))
            _Line(
              title: _day.format(s.date),
              subtitle: s.exerciseNames.join(', '),
              trailing: '${s.sets} ${s.sets == 1 ? 'set' : 'sets'}',
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.analyticsPanelBottom,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.analyticsPanelBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value,
                style: AppTypography.numeric(AppTypography.headlineSmall)
                    .copyWith(color: AppColors.silverBright)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall
                    .copyWith(color: AppColors.silverDim)),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.title, required this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.analyticsHairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.silverBright)),
                if (subtitle != null)
                  Text(subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.silverDim)),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(trailing,
              style: AppTypography.numeric(AppTypography.labelMedium)
                  .copyWith(color: AppColors.silver)),
        ],
      ),
    );
  }
}
