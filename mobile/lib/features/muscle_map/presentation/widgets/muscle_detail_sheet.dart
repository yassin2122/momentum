import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/muscle.dart';
import '../../domain/entities/muscle_activity.dart';

/// What we know about one muscle in the current window. Activity only —
/// it never says whether the muscle has recovered.
class MuscleDetailSheet extends StatelessWidget {
  const MuscleDetailSheet({
    required this.muscle,
    required this.activity,
    required this.windowDays,
    super.key,
  });

  final Muscle muscle;
  final MuscleActivity? activity;
  final int windowDays;

  static final _day = DateFormat('EEE d MMM');

  String _ago(DateTime date) {
    final today = DateUtils.dateOnly(DateTime.now());
    final days = today.difference(DateUtils.dateOnly(date)).inDays;
    if (days <= 0) return 'Today';
    if (days == 1) return 'Yesterday';
    return '$days days ago';
  }

  @override
  Widget build(BuildContext context) {
    final a = activity;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: AppSpacing.xl + AppSpacing.xxs,
                height: AppSpacing.xxs,
                decoration: BoxDecoration(
                  color: AppColors.achHandle,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              muscle.label,
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.hubTextBright,
                fontWeight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              a == null || !a.isTrained
                  ? 'Not trained in the last $windowDays days'
                  : 'Last trained ${_ago(a.lastTrained!).toLowerCase()} · '
                      '${_day.format(a.lastTrained!)}',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.hubTextMuted),
            ),
            if (a == null || !a.isTrained) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'No completed workout worked this muscle in the last '
                '$windowDays days. Try a longer window, or log a workout '
                'that targets it.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.hubTextBody),
              ),
            ] else
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  children: [
                    Row(
                      children: [
                        _Stat(value: '${a.primarySets}', label: 'primary sets'),
                        const SizedBox(width: AppSpacing.sm),
                        _Stat(
                            value: '${a.secondarySets}',
                            label: 'secondary sets'),
                        const SizedBox(width: AppSpacing.sm),
                        _Stat(
                            value: '${a.sessions.length}', label: 'workouts'),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    const _Heading('Exercises'),
                    for (final e in a.exerciseSets.entries)
                      _Row(
                        title: e.key,
                        trailing: '${e.value} ${e.value == 1 ? 'set' : 'sets'}',
                      ),
                    const SizedBox(height: AppSpacing.lg),
                    const _Heading('Recent workouts'),
                    for (final s in a.sessions.take(8))
                      _Row(
                        title: _day.format(s.date),
                        subtitle: s.exerciseNames.join(', '),
                        trailing: '${s.sets} ${s.sets == 1 ? 'set' : 'sets'}',
                      ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Secondary sets count half toward the glow. This shows '
                      'training volume, not recovery.',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.hubTextFaint),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.achSheetInset,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(color: AppColors.hubCardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: AppTypography.numeric(AppTypography.headlineSmall)
                  .copyWith(color: AppColors.hubTextBright),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelSmall
                  .copyWith(color: AppColors.hubTextMuted),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
        child: Text(
          text.toUpperCase(),
          style: AppTypography.overline.copyWith(color: AppColors.hubEyebrow),
        ),
      );
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.trailing, this.subtitle});

  final String title;
  final String? subtitle;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.hubTextBright),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption
                        .copyWith(color: AppColors.hubTextMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            trailing,
            style: AppTypography.labelMedium
                .copyWith(color: AppColors.hubTextMuted),
          ),
        ],
      ),
    );
  }
}
