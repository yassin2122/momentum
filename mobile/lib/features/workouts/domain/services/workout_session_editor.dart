import '../entities/active_workout.dart';
import '../entities/logged_set.dart';
import '../entities/trackable_exercise.dart';
import '../entities/workout_enums.dart';
import '../entities/workout_template.dart';

/// An exercise to append to the source template when the workout finishes.
final class TemplateAddition {
  const TemplateAddition({required this.exerciseId, required this.defaultSets});

  final String exerciseId;
  final int defaultSets;

  Map<String, dynamic> toJson() =>
      {'exercise_id': exerciseId, 'default_sets': defaultSets};
}

/// Every change to an in-progress workout, as pure functions over
/// [ActiveWorkout]. No I/O and no Flutter — the notifier persists the
/// result after each call.
///
/// Template rules:
/// * Add (picked or newly created): joins this workout now, and the
///   template on finish ([templateAdditions]).
/// * Remove: this workout only.
/// * Replace: this workout only — the replacement is never a template
///   addition, even if it replaced one.
/// * Discard: nothing is sent, so the template is untouched.
class WorkoutSessionEditor {
  const WorkoutSessionEditor({required this.newId});

  /// UUID generator (injected so tests are deterministic).
  final String Function() newId;

  // ── Starting ────────────────────────────────────────────────────────────

  ActiveWorkout startEmpty({
    required String userId,
    required DateTime now,
    double? bodyweightKg,
  }) =>
      ActiveWorkout(
        id: newId(),
        userId: userId,
        startedAt: now,
        exercises: const [],
        bodyweightKg: bodyweightKg,
      );

  ActiveWorkout startFromTemplate(
    WorkoutTemplate template, {
    required String userId,
    required DateTime now,
    required WeightUnit unit,
    double? bodyweightKg,
  }) =>
      ActiveWorkout(
        id: newId(),
        userId: userId,
        startedAt: now,
        templateId: template.id,
        templateName: template.name,
        bodyweightKg: bodyweightKg,
        exercises: [
          for (final t in template.exercises)
            LoggedExercise(
              id: newId(),
              exercise: t.exercise,
              unit: unit,
              sets: [
                for (var i = 0; i < _atLeastOne(t.defaultSets); i++)
                  LoggedSet(id: newId()),
              ],
            ),
        ],
      );

  // ── Exercises ───────────────────────────────────────────────────────────

  ActiveWorkout addExercise(
    ActiveWorkout workout,
    TrackableExercise exercise, {
    required WeightUnit unit,
  }) =>
      workout.copyWith(exercises: [
        ...workout.exercises,
        LoggedExercise(
          id: newId(),
          exercise: exercise,
          unit: unit,
          sets: [LoggedSet(id: newId())],
          addedDuringWorkout: true,
        ),
      ]);

  ActiveWorkout removeExercise(ActiveWorkout workout, String entryId) =>
      workout.copyWith(exercises: [
        for (final e in workout.exercises)
          if (e.id != entryId) e,
      ]);

  /// Swaps the exercise in place. Keeps the number of sets and their
  /// categories; clears values that don't fit the new tracking type and
  /// un-completes every set (it's a different exercise now).
  ActiveWorkout replaceExercise(
    ActiveWorkout workout,
    String entryId,
    TrackableExercise replacement,
  ) =>
      _mapEntry(workout, entryId, (entry) {
        final from = entry.exercise.trackingType;
        final to = replacement.trackingType;
        final keepLoad = from == to && to.hasLoadInput;
        final keepReps = from.hasReps && to.hasReps;
        final keepDuration =
            from == TrackingType.duration && to == TrackingType.duration;
        return LoggedExercise(
          id: entry.id,
          exercise: replacement,
          unit: entry.unit,
          notes: entry.notes,
          replacedFromExerciseId:
              entry.replacedFromExerciseId ?? entry.exercise.id,
          addedDuringWorkout: false,
          sets: [
            for (final s in entry.sets)
              LoggedSet(
                id: s.id,
                setType: s.setType,
                reps: keepReps ? s.reps : null,
                enteredWeight: keepLoad ? s.enteredWeight : null,
                enteredUnit: keepLoad ? s.enteredUnit : null,
                durationS: keepDuration ? s.durationS : null,
              ),
          ],
        );
      });

  ActiveWorkout reorderExercise(
    ActiveWorkout workout,
    int oldIndex,
    int newIndex,
  ) {
    final list = [...workout.exercises];
    if (oldIndex < 0 || oldIndex >= list.length) return workout;
    final moved = list.removeAt(oldIndex);
    list.insert(newIndex.clamp(0, list.length), moved);
    return workout.copyWith(exercises: list);
  }

  ActiveWorkout setUnit(ActiveWorkout workout, String entryId, WeightUnit unit) =>
      _mapEntry(workout, entryId, (e) => e.copyWith(unit: unit));

  ActiveWorkout setNotes(ActiveWorkout workout, String entryId, String? notes) =>
      _mapEntry(workout, entryId, (e) => e.copyWith(notes: () => notes));

  /// Stores last-session sets and current bests once fetched, and pre-fills
  /// any still-untouched set from the matching previous set.
  ActiveWorkout applyHistory(
    ActiveWorkout workout,
    String entryId, {
    required List<PreviousSet> previousSets,
    required Map<PrMetric, double> personalBests,
  }) =>
      _mapEntry(workout, entryId, (entry) {
        final sets = [
          for (var i = 0; i < entry.sets.length; i++)
            entry.sets[i].isEmpty &&
                    !entry.sets[i].completed &&
                    i < previousSets.length
                ? _prefillFromPrevious(
                    entry.sets[i], previousSets[i], entry.unit, entry.exercise)
                : entry.sets[i],
        ];
        return entry.copyWith(
          sets: sets,
          previousSets: previousSets,
          personalBests: personalBests,
          historyLoaded: true,
        );
      });

  // ── Sets ────────────────────────────────────────────────────────────────

  /// Appends a working set pre-filled from the previous set of this
  /// exercise, or else from the matching set of its last session.
  ActiveWorkout addSet(ActiveWorkout workout, String entryId) =>
      _mapEntry(workout, entryId, (entry) {
        final fresh = LoggedSet(id: newId());
        final LoggedSet next;
        if (entry.sets.isNotEmpty) {
          final last = entry.sets.last;
          next = LoggedSet(
            id: fresh.id,
            reps: last.reps,
            enteredWeight: last.enteredWeight,
            enteredUnit: last.enteredUnit,
            durationS: last.durationS,
          );
        } else if (entry.previousSets.isNotEmpty) {
          next = _prefillFromPrevious(
              fresh, entry.previousSets.first, entry.unit, entry.exercise);
        } else {
          next = fresh;
        }
        return entry.copyWith(sets: [...entry.sets, next]);
      });

  /// Removes a set; positions are list indexes, so they re-index themselves.
  ActiveWorkout removeSet(ActiveWorkout workout, String entryId, String setId) =>
      _mapEntry(workout, entryId, (entry) => entry.copyWith(sets: [
            for (final s in entry.sets)
              if (s.id != setId) s,
          ]));

  ActiveWorkout updateSet(
    ActiveWorkout workout,
    String entryId,
    String setId,
    LoggedSet Function(LoggedSet set) update,
  ) =>
      _mapEntry(workout, entryId, (entry) => entry.copyWith(sets: [
            for (final s in entry.sets) s.id == setId ? update(s) : s,
          ]));

  /// Whether [set] has every value its tracking type needs to be marked done.
  static bool canComplete(TrackingType type, LoggedSet set) => switch (type) {
        TrackingType.weightReps =>
          set.enteredWeight != null && (set.reps ?? 0) > 0,
        TrackingType.bodyweightReps => (set.reps ?? 0) > 0,
        // Added/assist weight may be left blank (= 0).
        TrackingType.weightedBodyweight ||
        TrackingType.assistedBodyweight =>
          (set.reps ?? 0) > 0,
        TrackingType.duration => (set.durationS ?? 0) > 0,
      };

  // ── Template sync ───────────────────────────────────────────────────────

  /// Exercises that join the source template on finish. Empty for a
  /// workout that wasn't started from a template.
  static List<TemplateAddition> templateAdditions(ActiveWorkout workout) {
    if (workout.templateId == null) return const [];
    final seen = <String>{};
    return [
      for (final e in workout.exercises)
        if (e.addedDuringWorkout && seen.add(e.exercise.id))
          TemplateAddition(
            exerciseId: e.exercise.id,
            defaultSets: _atLeastOne(e.sets.length),
          ),
    ];
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  static int _atLeastOne(int? n) => (n == null || n < 1) ? 1 : n;

  ActiveWorkout _mapEntry(
    ActiveWorkout workout,
    String entryId,
    LoggedExercise Function(LoggedExercise) update,
  ) =>
      workout.copyWith(exercises: [
        for (final e in workout.exercises) e.id == entryId ? update(e) : e,
      ]);

  static LoggedSet _prefillFromPrevious(
    LoggedSet set,
    PreviousSet previous,
    WeightUnit unit,
    TrackableExercise exercise,
  ) {
    final type = exercise.trackingType;
    final load = type.hasLoadInput ? previous.loadIn(unit) : null;
    return LoggedSet(
      id: set.id,
      setType: set.setType,
      reps: type.hasReps ? previous.reps : null,
      enteredWeight: load,
      enteredUnit: load == null ? null : unit,
      durationS: type == TrackingType.duration ? previous.durationS : null,
    );
  }
}
