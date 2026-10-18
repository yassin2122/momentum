import 'muscle.dart';

/// One exercise inside a completed workout, reduced to what activity needs.
final class LoggedExerciseRecord {
  const LoggedExerciseRecord({
    required this.exerciseId,
    required this.exerciseName,
    required this.workingSets,
  });

  final String exerciseId;
  final String exerciseName;

  /// Completed, non-warm-up sets.
  final int workingSets;
}

/// A `workout_logs` row. Only rows with [completedAt] set count.
final class CompletedWorkoutRecord {
  const CompletedWorkoutRecord({
    required this.id,
    required this.completedAt,
    required this.exercises,
  });

  final String id;
  final DateTime? completedAt;
  final List<LoggedExerciseRecord> exercises;
}

/// One workout's contribution to a muscle.
final class MuscleSession {
  const MuscleSession({
    required this.workoutId,
    required this.date,
    required this.sets,
    required this.exerciseNames,
  });

  final String workoutId;
  final DateTime date;

  /// Working sets that hit the muscle (primary + secondary).
  final int sets;
  final List<String> exerciseNames;
}

/// Training activity for one muscle inside the report's window.
///
/// This is volume, not recovery: nothing here says a muscle is recovered.
final class MuscleActivity {
  const MuscleActivity({
    required this.muscle,
    required this.primarySets,
    required this.secondarySets,
    required this.lastTrained,
    required this.exerciseSets,
    required this.sessions,
  });

  final Muscle muscle;
  final int primarySets;
  final int secondarySets;
  final DateTime? lastTrained;

  /// Exercise name → working sets that hit this muscle, most first.
  final Map<String, int> exerciseSets;

  /// Newest first.
  final List<MuscleSession> sessions;

  /// Secondary sets count half.
  double get load => primarySets + secondarySets * 0.5;
  int get totalSets => primarySets + secondarySets;
  bool get isTrained => totalSets > 0;
}

final class MuscleActivityReport {
  const MuscleActivityReport({
    required this.windowDays,
    required this.byMuscle,
    required this.unmappedExercises,
    required this.workoutCount,
  });

  final int windowDays;
  final Map<Muscle, MuscleActivity> byMuscle;

  /// Exercises in the window with no muscle data (shown, not guessed).
  final Set<String> unmappedExercises;

  /// Completed workouts counted.
  final int workoutCount;

  double get maxLoad => byMuscle.values
      .fold<double>(0, (m, a) => a.load > m ? a.load : m);

  /// 0–1 relative to the most-trained muscle in the window.
  double intensity(Muscle muscle) {
    final max = maxLoad;
    if (max <= 0) return 0;
    return ((byMuscle[muscle]?.load ?? 0) / max).clamp(0.0, 1.0);
  }

  Map<Muscle, double> get intensities => {
        for (final m in Muscle.values)
          if (intensity(m) > 0) m: intensity(m),
      };
}
