import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../domain/entities/workout_enums.dart';
import '../../domain/services/pr_detector.dart';
import '../../domain/services/weight_units.dart';
import '../../domain/services/workout_finalizer.dart';
import '../providers/active_workout_notifier.dart';
import '../providers/workout_providers.dart';

/// Shown after "Finish": duration, working sets, volume, new PRs, sync
/// status, and "Save as template".
class WorkoutSummaryScreen extends ConsumerStatefulWidget {
  const WorkoutSummaryScreen({super.key, required this.summary});

  final WorkoutSummary summary;

  @override
  ConsumerState<WorkoutSummaryScreen> createState() =>
      _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends ConsumerState<WorkoutSummaryScreen> {
  late WorkoutSummary _summary = widget.summary;
  bool _savingTemplate = false;
  bool _savedTemplate = false;

  Future<void> _retrySync() async {
    await ref.read(pendingWorkoutsProvider.notifier).retry();
    final pending = ref.read(pendingWorkoutsProvider).valueOrNull ?? const [];
    final stillPending = pending.any((p) => p.workoutId == _summary.workoutId);
    if (!mounted) return;
    setState(() => _summary = _summary.copyWith(synced: !stillPending));
    if (stillPending) _snack('Still offline — we\'ll keep trying.');
  }

  Future<void> _saveAsTemplate() async {
    final name = await _askTemplateName();
    if (name == null || !mounted) return;
    setState(() => _savingTemplate = true);
    final result = await saveWorkoutAsTemplate(ref,
        workoutId: _summary.workoutId, name: name);
    if (!mounted) return;
    setState(() {
      _savingTemplate = false;
      _savedTemplate = result.isSuccess;
    });
    _snack(result.isSuccess
        ? 'Saved "$name" as a template.'
        : result.failureOrNull!.message);
  }

  Future<String?> _askTemplateName() {
    final controller = TextEditingController(
        text: _summary.title == 'Workout' ? '' : _summary.title);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Save as template', style: AppTypography.headlineSmall),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          style: AppTypography.bodyLarge,
          decoration: const InputDecoration(hintText: 'e.g. Push Day'),
          onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    ).then((name) => (name == null || name.isEmpty) ? null : name);
  }

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(workoutDefaultsProvider).valueOrNull?.preferredUnit ??
        WeightUnit.kg;
    final s = _summary;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            const SizedBox(height: AppSpacing.lg),
            Text('Workout complete', style: AppTypography.overline),
            const SizedBox(height: AppSpacing.xxs),
            Text(s.title, style: AppTypography.displaySmall),
            const SizedBox(height: AppSpacing.lg),
            Row(
              children: [
                _Stat(label: 'Duration', value: _formatDuration(s.duration)),
                const SizedBox(width: AppSpacing.sm),
                _Stat(
                    label: 'Working sets',
                    value: '${s.completedWorkingSets}'),
                const SizedBox(width: AppSpacing.sm),
                _Stat(
                  label: 'Volume',
                  value:
                      '${WeightUnits.format(WeightUnits.fromKg(s.volumeKg, unit).roundToDouble())} ${unit.dbValue}',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            _SyncStatus(synced: s.synced, onRetry: _retrySync),
            const SizedBox(height: AppSpacing.lg),
            Text('Personal records', style: AppTypography.titleLarge),
            const SizedBox(height: AppSpacing.xs),
            if (s.newRecords.isEmpty)
              Text('No new records this time — keep going.',
                  style: AppTypography.bodyMedium)
            else
              for (final pr in s.newRecords)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: _PrTile(record: pr, unit: unit),
                ),
            const SizedBox(height: AppSpacing.xl),
            if (s.synced && !_savedTemplate) ...[
              SecondaryButton(
                label: 'Save as template',
                isLoading: _savingTemplate,
                onPressed: _savingTemplate ? null : _saveAsTemplate,
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            PrimaryButton(
              label: 'Done',
              onPressed: () => context.go(AppRoutes.workouts),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatDuration(Duration d) => d.inHours > 0
      ? '${d.inHours}h ${d.inMinutes % 60}m'
      : '${d.inMinutes}m';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: AppTypography.overline),
            const SizedBox(height: AppSpacing.xxs),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value, style: AppTypography.headlineSmall),
            ),
          ],
        ),
      ),
    );
  }
}

class _SyncStatus extends StatelessWidget {
  const _SyncStatus({required this.synced, required this.onRetry});

  final bool synced;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: synced ? AppColors.successContainer : AppColors.warningContainer,
      child: Row(
        children: [
          Icon(synced ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
              color: synced ? AppColors.success : AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              synced
                  ? 'Saved to your training history.'
                  : 'Saved on this device. It will sync when you\'re back online.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.textPrimary),
            ),
          ),
          if (!synced)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _PrTile extends StatelessWidget {
  const _PrTile({required this.record, required this.unit});

  final NewPersonalRecord record;
  final WeightUnit unit;

  String _format(double value) => switch (record.metric) {
        PrMetric.maxWeight || PrMetric.estimated1rm =>
          '${WeightUnits.format(WeightUnits.fromKg(value, unit))} ${unit.dbValue}',
        PrMetric.maxReps => '${value.round()} reps',
        PrMetric.maxHoldSeconds => '${value.round()} s',
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          const Icon(Icons.emoji_events_outlined, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(record.exercise.name, style: AppTypography.titleMedium),
                Text(record.metric.label, style: AppTypography.caption),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(_format(record.value), style: AppTypography.titleMedium),
              if (record.previous != null)
                Text('was ${_format(record.previous!)}',
                    style: AppTypography.caption),
            ],
          ),
        ],
      ),
    );
  }
}
