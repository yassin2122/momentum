import '../../../../core/error/result.dart';
import '../entities/active_workout.dart';
import '../entities/logged_set.dart';
import '../entities/pending_workout.dart';
import '../entities/trackable_exercise.dart';
import '../entities/workout_enums.dart';
import '../entities/workout_template.dart';

/// Last session + current bests for one exercise.
final class ExerciseHistory {
  const ExerciseHistory({
    required this.previousSets,
    required this.personalBests,
  });

  final List<PreviousSet> previousSets;
  final Map<PrMetric, double> personalBests;
}

/// Per-user defaults needed to start a workout.
final class WorkoutDefaults {
  const WorkoutDefaults({required this.preferredUnit, this.bodyweightKg});

  final WeightUnit preferredUnit;
  final double? bodyweightKg;
}

abstract interface class WorkoutRepository {
  // ── Remote ──────────────────────────────────────────────────────────────
  /// A–Z search over the library and the user's custom exercises.
  /// [muscleGroups] (library names) keeps exercises whose primary muscle is
  /// one of them.
  Future<Result<List<TrackableExercise>>> searchExercises(
    String query, {
    List<String> muscleGroups = const [],
    int offset = 0,
    int limit = 50,
  });

  /// Exercises for the given library slugs (missing slugs are skipped).
  Future<Result<List<TrackableExercise>>> exercisesBySlugs(List<String> slugs);

  /// Exercises from the user's recent workouts, most recent first.
  Future<Result<List<TrackableExercise>>> recentExercises({int limit = 8});

  Future<Result<TrackableExercise>> createCustomExercise({
    required String name,
    required TrackingType trackingType,
    String? equipment,
    double? bwFactor,
  });

  Future<Result<List<WorkoutTemplate>>> getTemplates();

  Future<Result<ExerciseHistory>> getExerciseHistory(String exerciseId);

  Future<Result<WorkoutDefaults>> getWorkoutDefaults();

  /// Sends a finished workout. Returns the server's bodyweight snapshot.
  Future<Result<double?>> finishWorkout(Map<String, dynamic> payload);

  /// Creates a new template from picked exercises. Returns its id.
  Future<Result<String>> createTemplate({
    required String name,
    required List<({String exerciseId, int sets})> exercises,
  });

  /// Removes a template from the user's list (soft delete; workout
  /// history is untouched).
  Future<Result<void>> deleteTemplate(String templateId);

  Future<Result<String>> saveAsTemplate({
    required String workoutId,
    required String name,
  });

  // ── Local ───────────────────────────────────────────────────────────────
  Future<ActiveWorkout?> loadActiveWorkout(String userId);
  Future<void> saveActiveWorkout(ActiveWorkout workout);
  Future<void> clearActiveWorkout(String userId);
  Future<List<PendingWorkout>> loadPendingWorkouts(String userId);
  Future<void> savePendingWorkouts(String userId, List<PendingWorkout> items);
}
