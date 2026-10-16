import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/widgets/secondary_button.dart';
import '../../domain/entities/active_workout.dart';
import '../../domain/services/workout_finalizer.dart';
import '../providers/active_workout_notifier.dart';
import '../widgets/exercise_card.dart';
import '../widgets/exercise_picker_sheet.dart';

/// The workout logger. Leaving the screen doesn't end the workout — it stays
/// on the device and the Workouts tab offers "Resume workout".
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  bool _finishing = false;

  ActiveWorkoutNotifier get _notifier =>
      ref.read(activeWorkoutProvider.notifier);

  void _leave() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.workouts);

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _addExercise() async {
    final exercise =
        await showExercisePicker(context, title: 'Add exercise');
    if (exercise != null) await _notifier.addExercise(exercise);
  }

  Future<void> _onExerciseAction(
    ActiveWorkout workout,
    int index,
    ExerciseAction action,
  ) async {
    final entry = workout.exercises[index];
    switch (action) {
      case ExerciseAction.replace:
        final replacement =
            await showExercisePicker(context, title: 'Replace ${entry.exercise.name}');
        if (replacement != null) {
          _notifier.replaceExercise(entry.id, replacement);
        }
      case ExerciseAction.moveUp:
        _notifier.reorderExercise(index, index - 1);
      case ExerciseAction.moveDown:
        _notifier.reorderExercise(index, index + 1);
      case ExerciseAction.remove:
        _notifier.removeExercise(entry.id);
        _snack('${entry.exercise.name} removed from this workout.');
    }
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text(title, style: AppTypography.headlineSmall),
        content: Text(message, style: AppTypography.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor:
                  destructive ? AppColors.error : AppColors.primaryBright,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _discard() async {
    final ok = await _confirm(
      title: 'Discard workout?',
      message: 'Nothing from this workout will be saved, and its template '
          'stays unchanged.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _notifier.discard();
    if (mounted) context.go(AppRoutes.workouts);
  }

  Future<void> _finish(ActiveWorkout workout) async {
    final prep = WorkoutFinalizer.prepare(workout, completedAt: DateTime.now());
    final ok = prep.hasCompletedSets
        ? await _confirm(
            title: 'Finish workout?',
            message: 'Unchecked sets won\'t be saved as performed.',
            confirmLabel: 'Finish',
          )
        : await _confirm(
            title: 'No completed sets',
            message: 'You haven\'t checked off any sets, so no sets will be '
                'saved. Finish anyway?',
            confirmLabel: 'Finish anyway',
            cancelLabel: 'Keep training',
          );
    if (!ok || !mounted) return;

    setState(() => _finishing = true);
    final outcome = await _notifier.finish();
    if (!mounted) return;
    setState(() => _finishing = false);
    if (outcome != null) {
      context.go(AppRoutes.workoutSummary, extra: outcome.summary);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeWorkoutProvider);
    final workout = async.valueOrNull;

    if (async.isLoading && workout == null) {
      return const Scaffold(
        body: LoadingOverlay(isLoading: true, child: SizedBox.expand()),
      );
    }
    if (workout == null) {
      return Scaffold(
        appBar: AppBar(leading: BackButton(onPressed: _leave)),
        body: EmptyState(
          icon: Icons.fitness_center,
          title: 'No workout in progress',
          message: 'Start one from the Workouts tab.',
          actionLabel: 'Go to Workouts',
          onAction: () => context.go(AppRoutes.workouts),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          tooltip: 'Minimise',
          icon: const Icon(Icons.keyboard_arrow_down),
          onPressed: _leave,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(workout.title, style: AppTypography.titleLarge),
            _ElapsedTime(since: workout.startedAt),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            color: AppColors.surfaceElevated,
            onSelected: (_) => _discard(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'discard',
                child: Text('Discard workout',
                    style: AppTypography.bodyLarge
                        .copyWith(color: AppColors.error)),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: FilledButton(
              onPressed: _finishing ? null : () => _finish(workout),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: AppColors.background,
                textStyle: AppTypography.labelLarge
                    .copyWith(fontWeight: AppTypography.bold),
              ),
              child: const Text('Finish'),
            ),
          ),
        ],
      ),
      body: LoadingOverlay(
        isLoading: _finishing,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            AppSpacing.sm,
            AppSpacing.screenPadding,
            AppSpacing.xl3,
          ),
          children: [
            if (workout.exercises.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
                child: Text(
                  'Add your first exercise to start logging sets.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium,
                ),
              ),
            for (var i = 0; i < workout.exercises.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _buildExercise(workout, i),
              ),
            SecondaryButton(label: 'Add exercise', onPressed: _addExercise),
          ],
        ),
      ),
    );
  }

  Widget _buildExercise(ActiveWorkout workout, int index) {
    final entry = workout.exercises[index];
    return ExerciseCard(
      key: ValueKey(entry.id),
      entry: entry,
      isFirst: index == 0,
      isLast: index == workout.exercises.length - 1,
      onAction: (action) => _onExerciseAction(workout, index, action),
      onUnitChanged: (unit) => _notifier.setUnit(entry.id, unit),
      onAddSet: () => _notifier.addSet(entry.id),
      onSetChanged: (setId, update) =>
          _notifier.updateSet(entry.id, setId, update),
      onSetTypeChanged: (setId, type) => _notifier.updateSet(
          entry.id, setId, (s) => s.copyWith(setType: type)),
      onToggleCompleted: (setId) {
        if (!_notifier.toggleCompleted(entry.id, setId)) {
          _snack('Fill in this set before checking it off.');
        }
      },
      onRemoveSet: (setId) => _notifier.removeSet(entry.id, setId),
    );
  }
}

/// "12:34" since [since], ticking every second.
class _ElapsedTime extends StatefulWidget {
  const _ElapsedTime({required this.since});

  final DateTime since;

  @override
  State<_ElapsedTime> createState() => _ElapsedTimeState();
}

class _ElapsedTimeState extends State<_ElapsedTime> {
  late final Timer _timer =
      Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = DateTime.now().difference(widget.since);
    String two(int n) => n.toString().padLeft(2, '0');
    final text = d.inHours > 0
        ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
    return Text(text, style: AppTypography.caption);
  }
}
