import '../entities/muscle.dart';
import '../entities/muscle_activity.dart';
import 'muscle_mapping.dart';

/// Turns completed workout logs into per-muscle activity.
///
/// Counts only workouts with a `completedAt` inside the window ending at
/// [now]; planned (templates) and unfinished workouts never count.
abstract final class MuscleActivityCalculator {
  static MuscleActivityReport compute({
    required List<CompletedWorkoutRecord> workouts,
    required Map<String, List<MuscleLink>> linksByExercise,
    required DateTime now,
    required int windowDays,
  }) {
    final since = now.subtract(Duration(days: windowDays));
    final primary = <Muscle, int>{};
    final secondary = <Muscle, int>{};
    final last = <Muscle, DateTime>{};
    final exerciseSets = <Muscle, Map<String, int>>{};
    final sessions = <Muscle, List<MuscleSession>>{};
    final unmapped = <String>{};
    var counted = 0;

    for (final w in workouts) {
      final done = w.completedAt;
      if (done == null || done.isBefore(since) || done.isAfter(now)) continue;
      counted++;

      final setsThisWorkout = <Muscle, int>{};
      final namesThisWorkout = <Muscle, List<String>>{};
      for (final ex in w.exercises) {
        if (ex.workingSets <= 0) continue;
        final involvement =
            MuscleMapping.involvement(linksByExercise[ex.exerciseId] ?? const []);
        if (involvement.isEmpty) {
          unmapped.add(ex.exerciseName);
          continue;
        }
        involvement.forEach((muscle, kind) {
          final bucket = kind == Involvement.primary ? primary : secondary;
          bucket[muscle] = (bucket[muscle] ?? 0) + ex.workingSets;
          final perEx = exerciseSets.putIfAbsent(muscle, () => {});
          perEx[ex.exerciseName] = (perEx[ex.exerciseName] ?? 0) + ex.workingSets;
          setsThisWorkout[muscle] =
              (setsThisWorkout[muscle] ?? 0) + ex.workingSets;
          final names = namesThisWorkout.putIfAbsent(muscle, () => []);
          if (!names.contains(ex.exerciseName)) names.add(ex.exerciseName);
        });
      }

      setsThisWorkout.forEach((muscle, sets) {
        final prev = last[muscle];
        if (prev == null || done.isAfter(prev)) last[muscle] = done;
        sessions.putIfAbsent(muscle, () => []).add(MuscleSession(
              workoutId: w.id,
              date: done,
              sets: sets,
              exerciseNames: namesThisWorkout[muscle]!,
            ));
      });
    }

    final byMuscle = <Muscle, MuscleActivity>{};
    for (final muscle in {...primary.keys, ...secondary.keys}) {
      final perEx = exerciseSets[muscle] ?? const {};
      final sortedEx = perEx.entries.toList()
        ..sort((a, b) => b.value != a.value
            ? b.value.compareTo(a.value)
            : a.key.compareTo(b.key));
      final s = [...?sessions[muscle]]
        ..sort((a, b) => b.date.compareTo(a.date));
      byMuscle[muscle] = MuscleActivity(
        muscle: muscle,
        primarySets: primary[muscle] ?? 0,
        secondarySets: secondary[muscle] ?? 0,
        lastTrained: last[muscle],
        exerciseSets: {for (final e in sortedEx) e.key: e.value},
        sessions: s,
      );
    }

    return MuscleActivityReport(
      windowDays: windowDays,
      byMuscle: byMuscle,
      unmappedExercises: unmapped,
      workoutCount: counted,
    );
  }
}
