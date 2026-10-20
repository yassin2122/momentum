import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../muscle_map/domain/entities/muscle.dart';
import '../../../muscle_map/domain/services/muscle_mapping.dart';
import '../../../muscle_map/presentation/providers/muscle_map_providers.dart';
import '../../../muscle_map/presentation/widgets/muscle_map_view.dart';
import '../../domain/entities/active_workout.dart';
import '../../domain/entities/logged_set.dart';
import '../../domain/entities/workout_enums.dart';
import '../../domain/services/workout_finalizer.dart';
import '../providers/active_workout_notifier.dart';
import '../widgets/exercise_picker_sheet.dart';
import '../widgets/focus_set_row.dart';

/// The workout logger, one exercise in focus at a time:
///
/// * a strip of round exercise tiles on top (tap to switch, "+" to add),
/// * the focused exercise's muscle map, name, tools and set table,
/// * a rest timer that starts when a set is checked off, and a "Next"
///   button once every set of the exercise is done.
///
/// Leaving the screen doesn't end the workout — it stays on the device and
/// START / Train offer "Resume". All changes go through
/// [ActiveWorkoutNotifier], which saves after every edit.
class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen> {
  bool _finishing = false;

  /// Focused exercise, by entry id so reorders keep the focus.
  String? _focusId;

  /// Front/back chosen by the user for the focused exercise (null = auto).
  BodyView? _viewOverride;

  // Rest timer (screen-only; it isn't part of the saved workout).
  static const Duration _defaultRest = Duration(seconds: 90);
  DateTime? _restEnd;
  Duration _restTotal = _defaultRest;
  Timer? _restTicker;

  ActiveWorkoutNotifier get _notifier =>
      ref.read(activeWorkoutProvider.notifier);

  @override
  void dispose() {
    _restTicker?.cancel();
    super.dispose();
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  void _leave() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.train);

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  int _focusIndex(ActiveWorkout w) {
    if (w.exercises.isEmpty) return -1;
    final i = w.exercises.indexWhere((e) => e.id == _focusId);
    if (i >= 0) return i;
    // Default: the first exercise that still has open sets.
    final open = w.exercises.indexWhere(
        (e) => e.sets.isEmpty || e.sets.any((s) => !s.completed));
    return open >= 0 ? open : 0;
  }

  void _focus(String entryId) => setState(() {
        _focusId = entryId;
        _viewOverride = null;
      });

  static bool _isDone(LoggedExercise e) =>
      e.sets.isNotEmpty && e.sets.every((s) => s.completed);

  // ── Rest timer ───────────────────────────────────────────────────────────

  Duration get _restLeft {
    final end = _restEnd;
    if (end == null) return Duration.zero;
    final left = end.difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  void _startRest([Duration length = _defaultRest]) {
    _restTicker?.cancel();
    setState(() {
      _restTotal = length;
      _restEnd = DateTime.now().add(length);
    });
    _restTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_restLeft == Duration.zero) {
        HapticFeedback.heavyImpact();
        _stopRest();
      } else {
        setState(() {});
      }
    });
  }

  void _addRest(Duration extra) {
    final end = _restEnd;
    if (end == null) return;
    setState(() {
      _restEnd = end.add(extra);
      _restTotal += extra;
    });
  }

  void _stopRest() {
    _restTicker?.cancel();
    _restTicker = null;
    if (mounted) setState(() => _restEnd = null);
  }

  // ── Exercise actions ─────────────────────────────────────────────────────

  Future<void> _addExercise() async {
    final exercise = await showExercisePicker(context, title: 'Add exercise');
    if (exercise == null) return;
    await _notifier.addExercise(exercise);
    final w = ref.read(activeWorkoutProvider).valueOrNull;
    if (mounted && w != null && w.exercises.isNotEmpty) {
      _focus(w.exercises.last.id);
    }
  }

  Future<void> _replace(LoggedExercise entry) async {
    final replacement = await showExercisePicker(
      context,
      title: 'Replace ${entry.exercise.name}',
    );
    if (replacement != null) _notifier.replaceExercise(entry.id, replacement);
  }

  Future<void> _editNotes(LoggedExercise entry) async {
    final controller = TextEditingController(text: entry.notes ?? '');
    final saved = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.achSheet,
      barrierColor: AppColors.achScrim,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (sheet) => Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md + MediaQuery.viewInsetsOf(sheet).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Notes · ${entry.exercise.name}',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.hubTextBright,
                fontWeight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: controller,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              maxLength: 300,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.hubTextBright),
              decoration: InputDecoration(
                hintText: 'Seat height, grip, how it felt…',
                hintStyle: AppTypography.bodyMedium
                    .copyWith(color: AppColors.hubTextFaint),
                filled: true,
                fillColor: AppColors.hubIconButton,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _PillButton(
              label: 'Save note',
              onTap: () => Navigator.of(sheet).pop(controller.text),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (saved != null) _notifier.setNotes(entry.id, saved);
  }

  void _showLastTime(LoggedExercise entry) {
    final type = entry.exercise.trackingType;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.achSheet,
      barrierColor: AppColors.achScrim,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Last time · ${entry.exercise.name}',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.hubTextBright,
                fontWeight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (entry.previousSets.isEmpty)
              Text(
                entry.historyLoaded
                    ? 'No earlier sessions of this exercise yet.'
                    : 'Last session couldn\'t load. Check your connection.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.hubTextMuted),
              ),
            for (var i = 0; i < entry.previousSets.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    SizedBox(
                      width: AppSpacing.xl,
                      child: Text(
                        '${i + 1}',
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.accentProgress),
                      ),
                    ),
                    Text(
                      FocusSetRow.previousText(
                          entry.previousSets[i], type, entry.unit),
                      style: AppTypography.numeric(AppTypography.bodyLarge)
                          .copyWith(color: AppColors.hubTextBright),
                    ),
                  ],
                ),
              ),
            if (entry.personalBests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text(
                'Personal bests',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.hubTextMuted),
              ),
              for (final pb in entry.personalBests.entries)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Text(
                    '${pb.key.label}: ${_formatPb(pb.key, pb.value)}',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.hubTextBright),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatPb(PrMetric m, double v) => switch (m) {
        PrMetric.maxReps => '${v.round()} reps',
        PrMetric.maxHoldSeconds => '${v.round()} s',
        _ => '${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)} kg',
      };

  /// Copies last session's numbers into every open set that has a match.
  void _fillFromLastTime(LoggedExercise entry) {
    if (entry.previousSets.isEmpty) {
      _snack(entry.historyLoaded
          ? 'No earlier session to copy from yet.'
          : 'Last session hasn\'t loaded yet.');
      return;
    }
    final type = entry.exercise.trackingType;
    var filled = 0;
    for (var i = 0; i < entry.sets.length; i++) {
      final set = entry.sets[i];
      if (set.completed || i >= entry.previousSets.length) continue;
      final p = entry.previousSets[i];
      final load = type.hasLoadInput ? p.loadIn(entry.unit) : null;
      _notifier.updateSet(
        entry.id,
        set.id,
        (s) => s.copyWith(
          reps: () => type.hasReps ? p.reps : null,
          enteredWeight: () => load,
          enteredUnit: () => load == null ? null : entry.unit,
          durationS: () => type == TrackingType.duration ? p.durationS : null,
        ),
      );
      filled++;
    }
    _snack(filled == 0
        ? 'Every set already has numbers.'
        : 'Filled $filled ${filled == 1 ? 'set' : 'sets'} from last time.');
  }

  void _toggleSet(LoggedExercise entry, LoggedSet set) {
    final wasDone = set.completed;
    if (!_notifier.toggleCompleted(entry.id, set.id)) {
      _snack('Fill in this set before checking it off.');
      return;
    }
    if (wasDone) return;
    // Rest after a checked set, unless it closed the whole workout.
    final w = ref.read(activeWorkoutProvider).valueOrNull;
    final allDone = w != null && w.exercises.every(_isDone);
    if (!allDone) _startRest();
  }

  Future<void> _onMenu(ActiveWorkout w, int index, _ExerciseMenu action) async {
    final entry = w.exercises[index];
    switch (action) {
      case _ExerciseMenu.unit:
        _notifier.setUnit(entry.id, entry.unit.other);
      case _ExerciseMenu.earlier:
        _notifier.reorderExercise(index, index - 1);
      case _ExerciseMenu.later:
        _notifier.reorderExercise(index, index + 1);
      case _ExerciseMenu.remove:
        final next = index + 1 < w.exercises.length
            ? w.exercises[index + 1].id
            : index > 0
                ? w.exercises[index - 1].id
                : null;
        _notifier.removeExercise(entry.id);
        setState(() => _focusId = next);
        _snack('${entry.exercise.name} removed from this workout.');
      case _ExerciseMenu.discard:
        await _discard();
    }
  }

  // ── Finish / discard ─────────────────────────────────────────────────────

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
        backgroundColor: AppColors.achSheet,
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
                  destructive ? AppColors.error : AppColors.accentProgress,
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
    _stopRest();
    await _notifier.discard();
    if (mounted) context.go(AppRoutes.train);
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

    _stopRest();
    setState(() => _finishing = true);
    final outcome = await _notifier.finish();
    if (!mounted) return;
    setState(() => _finishing = false);
    if (outcome != null) {
      context.go(AppRoutes.workoutSummary, extra: outcome.summary);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(activeWorkoutProvider);
    final workout = async.valueOrNull;

    if (async.isLoading && workout == null) {
      return const Scaffold(
        backgroundColor: AppColors.hubBackgroundBottom,
        body: LoadingOverlay(isLoading: true, child: SizedBox.expand()),
      );
    }
    if (workout == null) {
      return Scaffold(
        backgroundColor: AppColors.hubBackgroundBottom,
        extendBodyBehindAppBar: true,
        appBar: AppBar(leading: BackButton(onPressed: _leave)),
        body: HubBackground(
          child: SafeArea(
            child: EmptyState(
              icon: Icons.fitness_center,
              title: 'No workout in progress',
              message: 'Start one from the START button.',
              actionLabel: 'Go to Train',
              onAction: () => context.go(AppRoutes.train),
            ),
          ),
        ),
      );
    }

    final index = _focusIndex(workout);
    final links = ref
            .watch(exerciseMuscleLinksProvider(exerciseIdsKey(
                workout.exercises.map((e) => e.exercise.id))))
            .valueOrNull ??
        const <String, List<MuscleLink>>{};
    Map<Muscle, double> musclesOf(LoggedExercise e) => involvementIntensities(
        MuscleMapping.involvement(links[e.exercise.id] ?? const []));

    final totalSets =
        workout.exercises.fold<int>(0, (n, e) => n + e.sets.length);
    final doneSets = workout.exercises
        .fold<int>(0, (n, e) => n + e.sets.where((s) => s.completed).length);
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final focused = index >= 0 ? workout.exercises[index] : null;
    final resting = _restEnd != null;

    // Bottom action: rest bar, else "Next exercise", else "Finish".
    Widget? bottom;
    if (!keyboardOpen) {
      if (resting) {
        bottom = _RestBar(
          left: _restLeft,
          total: _restTotal,
          onAdd: () => _addRest(const Duration(seconds: 30)),
          onSkip: _stopRest,
        );
      } else if (focused != null && _isDone(focused)) {
        final nextIndex = _nextOpenIndex(workout, index);
        bottom = nextIndex == null
            ? _PillButton(
                label: 'Finish workout',
                gradient: true,
                onTap: () => _finish(workout),
              )
            : _PillButton(
                label: 'Next: ${workout.exercises[nextIndex].exercise.name}',
                gradient: true,
                onTap: () => _focus(workout.exercises[nextIndex].id),
              );
      }
    }

    return Scaffold(
      backgroundColor: AppColors.hubBackgroundBottom,
      body: LoadingOverlay(
        isLoading: _finishing,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Header(
                    since: workout.startedAt,
                    restLeft: resting ? _restLeft : null,
                    onMinimise: _leave,
                    onRest: resting ? _stopRest : _startRest,
                    onFinish: _finishing ? null : () => _finish(workout),
                  ),
                  _ProgressLine(
                    value: totalSets == 0 ? 0 : doneSets / totalSets,
                  ),
                  _ExerciseStrip(
                    exercises: workout.exercises,
                    focusIndex: index,
                    musclesOf: musclesOf,
                    isDone: _isDone,
                    onSelect: (i) => _focus(workout.exercises[i].id),
                    onAdd: _addExercise,
                  ),
                  Expanded(
                    child: focused == null
                        ? _NoExercises(onAdd: _addExercise)
                        : _FocusedExercise(
                            key: ValueKey(focused.id),
                            entry: focused,
                            index: index,
                            count: workout.exercises.length,
                            muscles: musclesOf(focused),
                            viewOverride: _viewOverride,
                            onFlipView: (v) =>
                                setState(() => _viewOverride = v),
                            bottomPadding: bottom == null
                                ? AppSpacing.xl
                                : AppSizing.buttonHeight + AppSpacing.xl3,
                            onMenu: (a) => _onMenu(workout, index, a),
                            onReplace: () => _replace(focused),
                            onNotes: () => _editNotes(focused),
                            onLastTime: () => _showLastTime(focused),
                            onFill: () => _fillFromLastTime(focused),
                            onAddSet: () => _notifier.addSet(focused.id),
                            onSetChanged: (setId, update) =>
                                _notifier.updateSet(focused.id, setId, update),
                            onSetTypeChanged: (setId, type) =>
                                _notifier.updateSet(focused.id, setId,
                                    (s) => s.copyWith(setType: type)),
                            onToggle: (set) => _toggleSet(focused, set),
                            onRemoveSet: (setId) =>
                                _notifier.removeSet(focused.id, setId),
                          ),
                  ),
                ],
              ),
            ),
            if (bottom != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.hubBackgroundBottom.withValues(alpha: 0),
                        AppColors.hubBackgroundBottom,
                      ],
                      stops: const [0, 0.35],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md, AppSpacing.xl, AppSpacing.md, 0),
                      child: bottom,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The next exercise after [from] (wrapping) that still has open sets.
  int? _nextOpenIndex(ActiveWorkout w, int from) {
    final n = w.exercises.length;
    for (var step = 1; step < n; step++) {
      final i = (from + step) % n;
      if (!_isDone(w.exercises[i])) return i;
    }
    return null;
  }
}

enum _ExerciseMenu { unit, earlier, later, remove, discard }

// ── Header ─────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.since,
    required this.restLeft,
    required this.onMinimise,
    required this.onRest,
    required this.onFinish,
  });

  final DateTime since;
  final Duration? restLeft;
  final VoidCallback onMinimise;
  final VoidCallback onRest;
  final VoidCallback? onFinish;

  @override
  Widget build(BuildContext context) {
    final resting = restLeft != null;
    return SizedBox(
      height: AppSizing.minTouchTarget + AppSpacing.md,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Center(child: _ElapsedTime(since: since)),
          Row(
            children: [
              IconButton(
                tooltip: 'Minimise',
                onPressed: onMinimise,
                icon: const Icon(
                  LucideIcons.chevronDown,
                  color: AppColors.hubTextMuted,
                ),
              ),
              const Spacer(),
              Semantics(
                button: true,
                label: resting
                    ? 'Rest timer, ${_fmt(restLeft!)} left. Tap to stop.'
                    : 'Start a rest timer',
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: onRest,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOut,
                    height: 42,
                    constraints: const BoxConstraints(minWidth: 42),
                    padding: EdgeInsets.symmetric(
                      horizontal: resting ? AppSpacing.sm : 0,
                    ),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(
                          color: AppColors.accentProgress, width: 1.5),
                      gradient: const RadialGradient(
                        center: Alignment(0, -0.3),
                        colors: [
                          AppColors.hubHeroGlow,
                          AppColors.hubBackgroundBottom,
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.accentProgress.withValues(alpha: 0.35),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: resting
                        ? Text(
                            _fmt(restLeft!),
                            style:
                                AppTypography.numeric(AppTypography.labelLarge)
                                    .copyWith(
                              color: AppColors.hubTextBright,
                              fontWeight: AppTypography.bold,
                            ),
                          )
                        : const Icon(
                            LucideIcons.timer,
                            size: AppSizing.iconSm + 2,
                            color: AppColors.hubTextBright,
                          ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: OutlinedButton(
                  key: const ValueKey('finish-workout'),
                  onPressed: onFinish,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.hubTextBright,
                    side: const BorderSide(color: AppColors.hubCardBorderStrong),
                    minimumSize: const Size(0, 38),
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                    textStyle: AppTypography.labelLarge
                        .copyWith(fontWeight: AppTypography.semiBold),
                  ),
                  child: const Text('Finish'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _fmt(Duration d) =>
    '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${(value * 100).round()} percent of sets done',
      child: SizedBox(
        height: 2,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ColoredBox(color: AppColors.hubTrackStrong),
            ),
            FractionallySizedBox(
              widthFactor: value.clamp(0.0, 1.0),
              child: const ColoredBox(color: AppColors.accentProgress),
            ),
          ],
        ),
      ),
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
        : '${d.inMinutes}:${two(d.inSeconds % 60)}';
    return Text(
      text,
      semanticsLabel: 'Workout time $text',
      style: AppTypography.numeric(AppTypography.headlineSmall).copyWith(
        color: AppColors.hubTextBright,
        fontWeight: AppTypography.semiBold,
      ),
    );
  }
}

// ── Exercise strip ─────────────────────────────────────────────────────────

/// Which side of the body shows the most of these muscles.
BodyView _bestView(Map<Muscle, double> muscles) {
  var front = 0.0;
  var back = 0.0;
  for (final e in muscles.entries) {
    if (e.key.views.contains(BodyView.front)) front += e.value;
    if (e.key.views.contains(BodyView.back)) back += e.value;
  }
  return back > front ? BodyView.back : BodyView.front;
}

class _ExerciseStrip extends StatelessWidget {
  const _ExerciseStrip({
    required this.exercises,
    required this.focusIndex,
    required this.musclesOf,
    required this.isDone,
    required this.onSelect,
    required this.onAdd,
  });

  final List<LoggedExercise> exercises;
  final int focusIndex;
  final Map<Muscle, double> Function(LoggedExercise) musclesOf;
  final bool Function(LoggedExercise) isDone;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  static const double _size = 84;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _size + AppSpacing.lg,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: exercises.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          if (i == exercises.length) {
            return Semantics(
              button: true,
              label: 'Add exercise',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: _size,
                  height: _size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.hubCardBorderStrong),
                    color: AppColors.hubIconButton,
                  ),
                  child: const Icon(
                    LucideIcons.plus,
                    color: AppColors.accentProgress,
                  ),
                ),
              ),
            );
          }
          final e = exercises[i];
          final selected = i == focusIndex;
          final done = isDone(e);
          final muscles = musclesOf(e);
          return Semantics(
            button: true,
            selected: selected,
            label: '${e.exercise.name}${done ? ', done' : ''}',
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => onSelect(i),
              child: SizedBox(
                width: _size,
                height: _size,
                child: Stack(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: _size,
                      height: _size,
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.hubCardBottom,
                        border: Border.all(
                          color: selected
                              ? AppColors.hubTextBright
                              : AppColors.hubCardBorderStrong,
                          width: selected ? 3 : 1.5,
                        ),
                      ),
                      child: ClipOval(
                        child: IgnorePointer(
                          child: MuscleMapView(
                            view: _bestView(muscles),
                            intensities: muscles,
                          ),
                        ),
                      ),
                    ),
                    if (done)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.accentProgress,
                            border: Border.all(
                              color: AppColors.hubBackgroundBottom,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            LucideIcons.check,
                            size: 13,
                            color: AppColors.hubBackgroundBottom,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Focused exercise ───────────────────────────────────────────────────────

class _FocusedExercise extends StatelessWidget {
  const _FocusedExercise({
    super.key,
    required this.entry,
    required this.index,
    required this.count,
    required this.muscles,
    required this.viewOverride,
    required this.onFlipView,
    required this.bottomPadding,
    required this.onMenu,
    required this.onReplace,
    required this.onNotes,
    required this.onLastTime,
    required this.onFill,
    required this.onAddSet,
    required this.onSetChanged,
    required this.onSetTypeChanged,
    required this.onToggle,
    required this.onRemoveSet,
  });

  final LoggedExercise entry;
  final int index;
  final int count;
  final Map<Muscle, double> muscles;
  final BodyView? viewOverride;
  final ValueChanged<BodyView> onFlipView;
  final double bottomPadding;
  final ValueChanged<_ExerciseMenu> onMenu;
  final VoidCallback onReplace;
  final VoidCallback onNotes;
  final VoidCallback onLastTime;
  final VoidCallback onFill;
  final VoidCallback onAddSet;
  final void Function(String setId, LoggedSet Function(LoggedSet) update)
      onSetChanged;
  final void Function(String setId, SetType type) onSetTypeChanged;
  final ValueChanged<LoggedSet> onToggle;
  final ValueChanged<String> onRemoveSet;

  String get _loadHeader {
    final unit = entry.unit.dbValue.toUpperCase();
    return switch (entry.exercise.trackingType) {
      TrackingType.weightedBodyweight => '+$unit',
      TrackingType.assistedBodyweight => '−$unit',
      _ => unit,
    };
  }

  @override
  Widget build(BuildContext context) {
    final type = entry.exercise.trackingType;
    final view = viewOverride ?? _bestView(muscles);
    final firstOpen = entry.sets.indexWhere((s) => !s.completed);
    var working = 0;
    final headerStyle = AppTypography.labelMedium.copyWith(
      color: AppColors.hubTextMuted,
      fontWeight: AppTypography.semiBold,
      letterSpacing: 0.6,
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, bottomPadding),
      children: [
        // Muscle map hero; tap the pill to see the other side.
        SizedBox(
          height: 250,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 230,
                height: 230,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentProgress.withValues(alpha: 0.16),
                      AppColors.accentProgress.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: MuscleMapView(
                  view: view,
                  intensities: muscles,
                  semanticLabel: muscles.isEmpty
                      ? null
                      : 'Works ${muscles.keys.map((m) => m.label).join(', ')}',
                ),
              ),
              Positioned(
                right: 0,
                bottom: AppSpacing.xs,
                child: _SmallChip(
                  icon: LucideIcons.refreshCw,
                  label: view == BodyView.front ? 'Back' : 'Front',
                  semanticLabel: view == BodyView.front
                      ? 'Show back of body'
                      : 'Show front of body',
                  onTap: () => onFlipView(
                      view == BodyView.front ? BodyView.back : BodyView.front),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Exercise ${index + 1} of $count',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.accentProgress),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    entry.exercise.name,
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.hubTextBright,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_ExerciseMenu>(
              tooltip: 'Exercise options',
              color: AppColors.achSheet,
              icon: const Icon(
                LucideIcons.ellipsisVertical,
                color: AppColors.hubTextBody,
              ),
              onSelected: onMenu,
              itemBuilder: (context) => [
                if (type.hasLoadInput)
                  PopupMenuItem(
                    value: _ExerciseMenu.unit,
                    child: Text('Use ${entry.unit.other.dbValue}',
                        style: AppTypography.bodyLarge),
                  ),
                if (index > 0)
                  PopupMenuItem(
                    value: _ExerciseMenu.earlier,
                    child:
                        Text('Move earlier', style: AppTypography.bodyLarge),
                  ),
                if (index < count - 1)
                  PopupMenuItem(
                    value: _ExerciseMenu.later,
                    child: Text('Move later', style: AppTypography.bodyLarge),
                  ),
                PopupMenuItem(
                  value: _ExerciseMenu.remove,
                  child: Text('Remove exercise',
                      style: AppTypography.bodyLarge
                          .copyWith(color: AppColors.error)),
                ),
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: _ExerciseMenu.discard,
                  child: Text('Discard workout',
                      style: AppTypography.bodyLarge
                          .copyWith(color: AppColors.error)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _ToolChip(
                icon: LucideIcons.repeat,
                label: 'Replace',
                onTap: onReplace,
              ),
              const SizedBox(width: AppSpacing.xs),
              _ToolChip(
                icon: LucideIcons.pencil,
                label: entry.notes == null ? 'Notes' : 'Edit note',
                onTap: onNotes,
              ),
              const SizedBox(width: AppSpacing.xs),
              _ToolChip(
                icon: LucideIcons.history,
                label: 'Last time',
                onTap: onLastTime,
              ),
            ],
          ),
        ),
        if (entry.notes != null) ...[
          const SizedBox(height: AppSpacing.sm),
          GestureDetector(
            onTap: onNotes,
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.hubIconButton,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.hubCardBorder),
              ),
              child: Text(
                entry.notes!,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.hubTextBody),
              ),
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        // Table header.
        Row(
          children: [
            SizedBox(
              width: FocusSetColumns.set,
              child: Text('SET',
                  textAlign: TextAlign.center, style: headerStyle),
            ),
            const SizedBox(width: FocusSetColumns.gap),
            Expanded(
              child: Text('PREVIOUS',
                  textAlign: TextAlign.center, style: headerStyle),
            ),
            if (type.hasLoadInput) ...[
              const SizedBox(width: FocusSetColumns.gap),
              SizedBox(
                width: FocusSetColumns.field,
                child: Text(_loadHeader,
                    textAlign: TextAlign.center, style: headerStyle),
              ),
            ],
            const SizedBox(width: FocusSetColumns.gap),
            SizedBox(
              width: FocusSetColumns.field,
              child: Text(type == TrackingType.duration ? 'SEC' : 'REPS',
                  textAlign: TextAlign.center, style: headerStyle),
            ),
            const SizedBox(width: FocusSetColumns.gap),
            SizedBox(
              width: FocusSetColumns.check,
              child: Center(
                child: Tooltip(
                  message: 'Fill from last time',
                  child: Semantics(
                    button: true,
                    label: 'Fill sets from last time',
                    excludeSemantics: true,
                    child: GestureDetector(
                      onTap: onFill,
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.hubHeroGlow
                              .withValues(alpha: 0.5),
                          border: Border.all(
                            color: AppColors.accentProgress,
                            width: 1.5,
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.sparkles,
                          size: AppSizing.iconSm + 2,
                          color: AppColors.accentProgress,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < entry.sets.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: FocusSetRow(
              key: ValueKey(entry.sets[i].id),
              set: entry.sets[i],
              workingNumber: entry.sets[i].setType == SetType.working
                  ? ++working
                  : working,
              trackingType: type,
              unit: entry.unit,
              previous: i < entry.previousSets.length
                  ? entry.previousSets[i]
                  : null,
              isNext: i == firstOpen,
              onChanged: (update) => onSetChanged(entry.sets[i].id, update),
              onSetTypeChanged: (t) => onSetTypeChanged(entry.sets[i].id, t),
              onToggleCompleted: () => onToggle(entry.sets[i]),
              onRemove: () => onRemoveSet(entry.sets[i].id),
            ),
          ),
        const SizedBox(height: AppSpacing.xxs),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: (FocusSetColumns.set - 36) / 2),
            child: Semantics(
              button: true,
              label: 'Add set',
              excludeSemantics: true,
              child: GestureDetector(
                key: const ValueKey('add-set'),
                onTap: onAddSet,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.hubTrackStrong,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: const Icon(
                    LucideIcons.plus,
                    size: AppSizing.iconSm + 2,
                    color: AppColors.hubTextBright,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoExercises extends StatelessWidget {
  const _NoExercises({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Add your first exercise to start logging sets.',
            textAlign: TextAlign.center,
            style:
                AppTypography.bodyLarge.copyWith(color: AppColors.hubTextBody),
          ),
          const SizedBox(height: AppSpacing.md),
          _PillButton(label: 'Add exercise', gradient: true, onTap: onAdd),
        ],
      ),
    );
  }
}

// ── Small parts ────────────────────────────────────────────────────────────

class _ToolChip extends StatelessWidget {
  const _ToolChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Material(
      color: AppColors.hubIconButton,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.hubCardBorder),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm - 2,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: AppSizing.iconSm, color: AppColors.hubTextBright),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.hubTextBright,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  const _SmallChip({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.hubIconButton,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(color: AppColors.hubCardBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: AppColors.hubTextMuted),
              const SizedBox(width: AppSpacing.xxs),
              Text(
                label,
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.hubTextMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width pill: gradient (main action) or dark.
class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.label,
    required this.onTap,
    this.gradient = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool gradient;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Container(
      height: AppSizing.buttonHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: gradient ? null : AppColors.hubIconButton,
        border:
            gradient ? null : Border.all(color: AppColors.hubCardBorderStrong),
        gradient: gradient
            ? const LinearGradient(
                colors: [
                  AppColors.ctaGradientStart,
                  AppColors.ctaGradientMid,
                  AppColors.ctaGradientEnd,
                ],
              )
            : null,
        boxShadow: gradient ? AppShadows.ctaGlow : null,
      ),
      child: Material(
        color: AppColors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.button.copyWith(
                color: AppColors.textPrimary,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rest countdown pinned to the bottom: time left, a fill that empties,
/// "+30 s" and "Skip".
class _RestBar extends StatelessWidget {
  const _RestBar({
    required this.left,
    required this.total,
    required this.onAdd,
    required this.onSkip,
  });

  final Duration left;
  final Duration total;
  final VoidCallback onAdd;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    final fraction = total.inMilliseconds == 0
        ? 0.0
        : math.min(1.0, left.inMilliseconds / total.inMilliseconds);
    return Semantics(
      liveRegion: true,
      label: 'Resting, ${_fmt(left)} left',
      child: Container(
        height: 64,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: AppColors.hubCardTop,
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(color: AppColors.hubAvatarRing),
        ),
        child: Stack(
          children: [
            FractionallySizedBox(
              widthFactor: fraction,
              child: ColoredBox(
                color: AppColors.accentProgress.withValues(alpha: 0.14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, 0, AppSpacing.xs, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rest',
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.hubChipText),
                        ),
                        Text(
                          _fmt(left),
                          style: AppTypography.numeric(
                                  AppTypography.headlineSmall)
                              .copyWith(
                            color: AppColors.hubTextBright,
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: onAdd,
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.hubTextBright,
                    ),
                    child: const Text('+30 s'),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  FilledButton(
                    onPressed: onSkip,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.hubTextBright,
                      foregroundColor: AppColors.hubBackgroundBottom,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                    ),
                    child: const Text('Skip'),
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
