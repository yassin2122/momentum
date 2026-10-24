import 'dart:math' as math;

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
import '../../domain/entities/recovery.dart';
import '../../domain/services/recovery_insights.dart';
import '../providers/analytics_providers.dart';
import '../widgets/analytics_charts.dart';
import '../widgets/analytics_chrome.dart';
import '../widgets/recovery_checkin_sheet.dart';

/// Daily check-in, recent history next to training load, and cautious,
/// rule-based observations that show their working.
class RecoveryScreen extends ConsumerWidget {
  const RecoveryScreen({super.key});

  void _checkIn(BuildContext context, RecoveryCheckin? existing) {
    showAnalyticsSheet<void>(
        context, (_) => RecoveryCheckinSheet(existing: existing));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(recoveryOverviewProvider);
    final o = async.valueOrNull;
    return AnalyticsScaffold(
      eyebrow: 'Daily check-in',
      title: 'Recovery',
      accent: AppColors.analyticsDusk,
      glowCenter: const Alignment(0.9, -0.9),
      onRefresh: () async => ref.invalidate(recoveryOverviewProvider),
      children: [
        if (async.hasError && o == null)
          AnalyticsErrorPanel(
            message: 'Check your connection and try again.',
            onRetry: () => ref.invalidate(recoveryOverviewProvider),
          )
        else if (o == null)
          const Column(children: [
            AnalyticsSkeleton(height: 200),
            SizedBox(height: AppSpacing.sm),
            AnalyticsSkeleton(height: 120),
            SizedBox(height: AppSpacing.sm),
            AnalyticsSkeleton(height: 220),
          ])
        else ...[
          _TodayPanel(today: o.today, onCheckIn: () => _checkIn(context, o.today)),
          const SizedBox(height: AppSpacing.lg),
          const AnalyticsLabel('What your logs show'),
          for (final i in o.insights) ...[
            _InsightCard(insight: i),
            const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.lg),
          const AnalyticsLabel('Last 14 days'),
          _TimelinePanel(overview: o),
          const SizedBox(height: AppSpacing.lg),
          if (o.checkins.isNotEmpty) ...[
            const AnalyticsLabel('Check-in history'),
            _HistoryPanel(
              checkins: o.checkins,
              onEditToday: (c) => _checkIn(context, c),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            RecoveryInsights.disclaimer,
            style: AppTypography.caption.copyWith(color: AppColors.silverDim),
          ),
        ],
      ],
    );
  }
}

// ── Today ──────────────────────────────────────────────────────────────

class _TodayPanel extends StatelessWidget {
  const _TodayPanel({required this.today, required this.onCheckIn});

  final RecoveryCheckin? today;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final t = today;
    if (t == null) {
      return AnalyticsPanel(
        tint: AppColors.analyticsDusk,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Orbit(),
            const SizedBox(height: AppSpacing.md),
            MetalText('How are you today?', style: AppTypography.headlineLarge),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Sleep, soreness, energy and fatigue — four quick taps.',
              style: AppTypography.bodyMedium.copyWith(color: AppColors.silverDim),
            ),
            const SizedBox(height: AppSpacing.md),
            AnalyticsButton(
              label: 'Check in',
              accent: AppColors.analyticsDusk,
              onPressed: onCheckIn,
            ),
          ],
        ),
      );
    }
    final h = t.sleepHours == t.sleepHours.roundToDouble()
        ? t.sleepHours.toStringAsFixed(0)
        : t.sleepHours.toStringAsFixed(1);
    return AnalyticsPanel(
      tint: AppColors.analyticsDusk,
      onTap: onCheckIn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.circleCheck,
                  size: AppSizing.iconSm, color: AppColors.analyticsDusk),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text('CHECKED IN TODAY',
                    style: AppTypography.overline
                        .copyWith(color: AppColors.analyticsDusk)),
              ),
              Text('Edit',
                  style: AppTypography.labelMedium
                      .copyWith(color: AppColors.silverDim)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        MetalText(h,
                            style: AppTypography.numeric(AppTypography.displayLarge)
                                .copyWith(fontSize: 52)),
                        const SizedBox(width: AppSpacing.xxs),
                        Text('h',
                            style: AppTypography.titleMedium
                                .copyWith(color: AppColors.silverDim)),
                      ],
                    ),
                    Text(
                      t.sleepQuality == null
                          ? 'sleep'
                          : 'sleep · quality ${t.sleepQuality}/5',
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.silver),
                    ),
                  ],
                ),
              ),
              Container(
                width: 1,
                height: 72,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                color: AppColors.analyticsHairline,
              ),
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    _Gauge(label: 'Soreness', value: t.soreness),
                    const SizedBox(height: AppSpacing.sm),
                    _Gauge(label: 'Energy', value: t.energy),
                    const SizedBox(height: AppSpacing.sm),
                    _Gauge(label: 'Fatigue', value: t.fatigue),
                  ],
                ),
              ),
            ],
          ),
          if (t.note != null && t.note!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('“${t.note}”',
                style: AppTypography.bodySmall.copyWith(
                    color: AppColors.silverDim, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}

class _Gauge extends StatelessWidget {
  const _Gauge({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.labelMedium.copyWith(color: AppColors.silver)),
        ),
        PipMeter(value: value, color: AppColors.analyticsDusk, pipWidth: 12),
        const SizedBox(width: AppSpacing.xs),
        SizedBox(
          width: 14,
          child: Text('$value',
              textAlign: TextAlign.right,
              style: AppTypography.numeric(AppTypography.labelMedium)
                  .copyWith(color: AppColors.silverBright)),
        ),
      ],
    );
  }
}

/// Slowly turning concentric arcs — the recovery screen's quiet motif.
class _Orbit extends StatefulWidget {
  const _Orbit();

  @override
  State<_Orbit> createState() => _OrbitState();
}

class _OrbitState extends State<_Orbit> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduce) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 56,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) =>
            CustomPaint(painter: _OrbitPainter(_c.value)),
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final r = size.shortestSide / 2 - i * 8 - 2;
      final start = (t + i * 0.27) * 2 * math.pi * (i.isEven ? 1 : -1);
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: r),
        start,
        math.pi * (1.1 - i * 0.25),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = AppColors.analyticsDusk.withValues(alpha: 0.85 - i * 0.25),
      );
    }
    canvas.drawCircle(c, 3, Paint()..color = AppColors.silverBright);
  }

  @override
  bool shouldRepaint(_OrbitPainter old) => old.t != t;
}

// ── Insights ───────────────────────────────────────────────────────────

class _InsightCard extends StatelessWidget {
  const _InsightCard({required this.insight});

  final RecoveryInsight insight;

  @override
  Widget build(BuildContext context) {
    final (Color color, Color fill, IconData icon) = switch (insight.tone) {
      InsightTone.caution => (
          AppColors.analyticsCaution,
          AppColors.analyticsCautionSoft,
          LucideIcons.info,
        ),
      InsightTone.positive => (
          AppColors.analyticsPositive,
          AppColors.analyticsPositiveSoft,
          LucideIcons.circleCheck,
        ),
      InsightTone.info => (
          AppColors.analyticsDusk,
          AppColors.analyticsDuskSoft,
          LucideIcons.info,
        ),
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.large),
        color: AppColors.analyticsPanelBottom,
        // Uniform border: Flutter can't round a border with mixed colours.
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.xl,
            height: AppSpacing.xl,
            decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
            child: Icon(icon, size: AppSizing.iconSm, color: color),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(insight.title,
                    style: AppTypography.titleSmall.copyWith(
                        color: AppColors.silverBright,
                        fontWeight: AppTypography.semiBold)),
                const SizedBox(height: 2),
                Text(insight.detail,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.silver)),
                const SizedBox(height: AppSpacing.xs),
                Text('Based on: ${insight.basis}',
                    style: AppTypography.caption
                        .copyWith(color: AppColors.silverDim)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Timeline: training load + check-ins, aligned by day ────────────────

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.overview});

  final RecoveryOverview overview;

  @override
  Widget build(BuildContext context) {
    final loads = overview.loads;
    final byDay = {
      for (final c in overview.checkins)
        DateTime(c.date.year, c.date.month, c.date.day): c,
    };
    final days = [for (final l in loads) l.date];
    final checks = [for (final d in days) byDay[d]];
    final totalSets = loads.fold<int>(0, (s, l) => s + l.workingSets);
    final workouts = loads.fold<int>(0, (s, l) => s + l.workouts);
    final initials = [for (final d in days) DateFormat('E').format(d).substring(0, 1)];

    return AnalyticsPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$workouts ${workouts == 1 ? 'workout' : 'workouts'} · '
                  '$totalSets working sets',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.silverBright),
                ),
              ),
              const Icon(LucideIcons.dumbbell,
                  size: AppSizing.iconSm, color: AppColors.silverDim),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: _DotRow.labelWidth,
                child: Text('Sets',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.silverDim)),
              ),
              Expanded(
                child: ColumnBars(
                  values: [for (final l in loads) l.workingSets.toDouble()],
                  color: AppColors.silver,
                  height: 72,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _DotRow(label: 'Energy', checks: checks, pick: (c) => c.energy),
          const SizedBox(height: AppSpacing.xxs + 2),
          _DotRow(label: 'Soreness', checks: checks, pick: (c) => c.soreness),
          const SizedBox(height: AppSpacing.xxs + 2),
          _DotRow(label: 'Fatigue', checks: checks, pick: (c) => c.fatigue),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const SizedBox(width: _DotRow.labelWidth),
              for (final i in initials)
                Expanded(
                  child: Text(i,
                      textAlign: TextAlign.center,
                      style: AppTypography.labelSmall
                          .copyWith(color: AppColors.silverDim, fontSize: 10)),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Bars: completed working sets per day. Dots: your 1–5 ratings '
            '(brighter = higher); a gap means no check-in that day.',
            style: AppTypography.caption.copyWith(color: AppColors.silverDim),
          ),
        ],
      ),
    );
  }
}

class _DotRow extends StatelessWidget {
  const _DotRow({required this.label, required this.checks, required this.pick});

  static const double labelWidth = 64;

  final String label;
  final List<RecoveryCheckin?> checks;
  final int Function(RecoveryCheckin) pick;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: labelWidth,
          child: Text(label,
              style: AppTypography.labelSmall.copyWith(color: AppColors.silverDim)),
        ),
        for (final c in checks)
          Expanded(
            child: Center(
              child: c == null
                  ? Container(
                      width: 4,
                      height: 4,
                      decoration: const BoxDecoration(
                          color: AppColors.analyticsTrack, shape: BoxShape.circle),
                    )
                  : Container(
                      width: 4.0 + pick(c) * 1.6,
                      height: 4.0 + pick(c) * 1.6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.analyticsDusk
                            .withValues(alpha: 0.2 + pick(c) * 0.16),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

// ── History ────────────────────────────────────────────────────────────

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.checkins, required this.onEditToday});

  final List<RecoveryCheckin> checkins;
  final ValueChanged<RecoveryCheckin> onEditToday;

  static final _date = DateFormat('EEE d MMM');

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return AnalyticsPanel(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Column(
        children: [
          for (final c in checkins.take(10))
            InkWell(
              onTap: RecoveryInsights.daysBetween(c.date, now) == 0
                  ? () => onEditToday(c)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                decoration: const BoxDecoration(
                  border: Border(
                      bottom: BorderSide(color: AppColors.analyticsHairline)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        RecoveryInsights.daysBetween(c.date, now) == 0
                            ? 'Today'
                            : _date.format(c.date),
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.silverBright),
                      ),
                    ),
                    _Pill(text: '${_fmtHours(c.sleepHours)} h', icon: LucideIcons.timer),
                    const Spacer(),
                    _Pill(text: 'S ${c.soreness}'),
                    const SizedBox(width: AppSpacing.xxs),
                    _Pill(text: 'E ${c.energy}'),
                    const SizedBox(width: AppSpacing.xxs),
                    _Pill(text: 'F ${c.fatigue}'),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Text(
              'S soreness · E energy · F fatigue (1–5)',
              style: AppTypography.labelSmall.copyWith(color: AppColors.silverDim),
            ),
          ),
        ],
      ),
    );
  }

  static String _fmtHours(double h) =>
      h == h.roundToDouble() ? h.toStringAsFixed(0) : h.toStringAsFixed(1);
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppConstants.animFast,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.analyticsPanelBottom,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.analyticsPanelBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: AppColors.silverDim),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: AppTypography.numeric(AppTypography.labelSmall)
                  .copyWith(color: AppColors.silver)),
        ],
      ),
    );
  }
}
