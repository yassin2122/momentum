import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/result.dart';
import '../../domain/entities/active_workout.dart';
import '../../domain/entities/logged_set.dart';
import '../../domain/entities/pending_workout.dart';
import '../../domain/entities/trackable_exercise.dart';
import '../../domain/entities/workout_enums.dart';
import '../../domain/entities/workout_template.dart';
import '../../domain/services/workout_session_editor.dart';
import '../../domain/usecases/finish_workout.dart';
import 'workout_providers.dart';

/// The in-progress workout (null when none). Every change goes through
/// [WorkoutSessionEditor] and is written to the device immediately, so
/// killing the app mid-workout loses nothing.
class ActiveWorkoutNotifier extends AsyncNotifier<ActiveWorkout?> {
  Future<void> _writes = Future.value();

  WorkoutSessionEditor get _editor => ref.read(workoutSessionEditorProvider);

  @override
  Future<ActiveWorkout?> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return null;
    return ref.read(workoutRepositoryProvider).loadActiveWorkout(userId);
  }

  ActiveWorkout? get _current => state.valueOrNull;

  /// The newest state not yet written to the device.
  ActiveWorkout? _unsaved;
  bool _writing = false;

  /// Applies [next] and saves it. Saves never overlap: while one is
  /// running, edits made meanwhile (every keystroke in a set field) are
  /// coalesced and only the newest is written next — the device always
  /// ends up with the latest workout without serialising each keystroke.
  void _commit(ActiveWorkout next) {
    state = AsyncData(next);
    _unsaved = next;
    if (!_writing) _writes = _flush();
  }

  Future<void> _flush() async {
    _writing = true;
    try {
      while (_unsaved != null) {
        final next = _unsaved!;
        _unsaved = null;
        try {
          await ref.read(workoutRepositoryProvider).saveActiveWorkout(next);
        } catch (_) {
          // Best effort, as before: the next edit saves again.
        }
      }
    } finally {
      _writing = false;
    }
  }

  void _edit(ActiveWorkout Function(ActiveWorkout w) change) {
    final current = _current;
    if (current != null) _commit(change(current));
  }

  // ── Start / end ─────────────────────────────────────────────────────────

  Future<void> startEmpty() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _current != null) return;
    final defaults = await ref.read(workoutDefaultsProvider.future);
    _commit(_editor.startEmpty(
      userId: userId,
      now: DateTime.now(),
      bodyweightKg: defaults.bodyweightKg,
    ));
  }

  Future<void> startFromTemplate(WorkoutTemplate template) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null || _current != null) return;
    final defaults = await ref.read(workoutDefaultsProvider.future);
    final workout = _editor.startFromTemplate(
      template,
      userId: userId,
      now: DateTime.now(),
      unit: defaults.preferredUnit,
      bodyweightKg: defaults.bodyweightKg,
    );
    _commit(workout);
    for (final entry in workout.exercises) {
      unawaited(_loadHistory(entry.id, entry.exercise.id));
    }
  }

  /// Ends the workout without saving. Nothing is sent, so a source
  /// template is left exactly as it was.
  Future<void> discard() async {
    final current = _current;
    if (current == null) return;
    state = const AsyncData(null);
    await _writes;
    await ref.read(workoutRepositoryProvider).clearActiveWorkout(current.userId);
  }

  Future<FinishOutcome?> finish() async {
    final current = _current;
    if (current == null) return null;
    await _writes;
    final outcome = await ref
        .read(finishWorkoutProvider)
        .call(current, completedAt: DateTime.now());
    state = const AsyncData(null);
    ref.invalidate(pendingWorkoutsProvider);
    ref.invalidate(workoutTemplatesProvider);
    return outcome;
  }

  // ── Exercises ───────────────────────────────────────────────────────────

  Future<void> addExercise(TrackableExercise exercise) async {
    if (_current == null) return;
    final defaults = await ref.read(workoutDefaultsProvider.future);
    final current = _current;
    if (current == null) return;
    final next =
        _editor.addExercise(current, exercise, unit: defaults.preferredUnit);
    _commit(next);
    unawaited(_loadHistory(next.exercises.last.id, exercise.id));
  }

  void removeExercise(String entryId) =>
      _edit((w) => _editor.removeExercise(w, entryId));

  void replaceExercise(String entryId, TrackableExercise replacement) {
    _edit((w) => _editor.replaceExercise(w, entryId, replacement));
    unawaited(_loadHistory(entryId, replacement.id));
  }

  void reorderExercise(int oldIndex, int newIndex) =>
      _edit((w) => _editor.reorderExercise(w, oldIndex, newIndex));

  void setUnit(String entryId, WeightUnit unit) =>
      _edit((w) => _editor.setUnit(w, entryId, unit));

  /// Free-text note for one exercise in this workout (null clears it).
  void setNotes(String entryId, String? notes) => _edit((w) => _editor
      .setNotes(w, entryId, (notes?.trim().isEmpty ?? true) ? null : notes!.trim()));

  Future<void> _loadHistory(String entryId, String exerciseId) async {
    final result =
        await ref.read(workoutRepositoryProvider).getExerciseHistory(exerciseId);
    final history = result.valueOrNull;
    if (history == null) return; // offline: no hint, no PR baseline
    _edit((w) {
      final stillThere = w.exercises
          .any((e) => e.id == entryId && e.exercise.id == exerciseId);
      if (!stillThere) return w;
      return _editor.applyHistory(
        w,
        entryId,
        previousSets: history.previousSets,
        personalBests: history.personalBests,
      );
    });
  }

  // ── Sets ────────────────────────────────────────────────────────────────

  void addSet(String entryId) => _edit((w) => _editor.addSet(w, entryId));

  void removeSet(String entryId, String setId) =>
      _edit((w) => _editor.removeSet(w, entryId, setId));

  void updateSet(
    String entryId,
    String setId,
    LoggedSet Function(LoggedSet set) update,
  ) =>
      _edit((w) => _editor.updateSet(w, entryId, setId, update));

  /// Toggles completion. Returns false (and changes nothing) when the set
  /// is missing a value its tracking type needs.
  bool toggleCompleted(String entryId, String setId) {
    final current = _current;
    if (current == null) return false;
    final entry = current.exercises.firstWhere((e) => e.id == entryId);
    final set = entry.sets.firstWhere((s) => s.id == setId);
    if (!set.completed &&
        !WorkoutSessionEditor.canComplete(entry.exercise.trackingType, set)) {
      return false;
    }
    updateSet(entryId, setId, (s) => s.copyWith(completed: !s.completed));
    return true;
  }
}

final activeWorkoutProvider =
    AsyncNotifierProvider<ActiveWorkoutNotifier, ActiveWorkout?>(
  ActiveWorkoutNotifier.new,
);

/// Finished workouts still waiting for Supabase. Building it retries the
/// queue; it retries again whenever the app returns to the foreground.
class PendingWorkoutsNotifier extends AsyncNotifier<List<PendingWorkout>> {
  @override
  Future<List<PendingWorkout>> build() async {
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return const [];

    final listener = AppLifecycleListener(onResume: () => unawaited(retry()));
    ref.onDispose(listener.dispose);

    return ref.read(syncPendingWorkoutsProvider).call(userId);
  }

  Future<void> retry() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    state = AsyncData(
        await ref.read(syncPendingWorkoutsProvider).call(userId));
  }
}

final pendingWorkoutsProvider =
    AsyncNotifierProvider<PendingWorkoutsNotifier, List<PendingWorkout>>(
  PendingWorkoutsNotifier.new,
);

/// Saves a finished, synced workout as a new template.
Future<Result<String>> saveWorkoutAsTemplate(
  WidgetRef ref, {
  required String workoutId,
  required String name,
}) async {
  final result = await ref
      .read(workoutRepositoryProvider)
      .saveAsTemplate(workoutId: workoutId, name: name);
  if (result.isSuccess) ref.invalidate(workoutTemplatesProvider);
  return result;
}
