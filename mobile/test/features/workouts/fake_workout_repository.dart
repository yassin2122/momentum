import 'package:grit/core/error/failure.dart';
import 'package:grit/core/error/result.dart';
import 'package:grit/features/workouts/domain/entities/active_workout.dart';
import 'package:grit/features/workouts/domain/entities/pending_workout.dart';
import 'package:grit/features/workouts/domain/entities/trackable_exercise.dart';
import 'package:grit/features/workouts/domain/entities/workout_enums.dart';
import 'package:grit/features/workouts/domain/entities/workout_template.dart';
import 'package:grit/features/workouts/domain/repositories/workout_repository.dart';

/// In-memory repository; [online] decides whether finishWorkout succeeds.
class FakeWorkoutRepository implements WorkoutRepository {
  bool online = true;
  ActiveWorkout? active;
  List<PendingWorkout> pending = [];
  final sent = <Map<String, dynamic>>[];

  @override
  Future<Result<double?>> finishWorkout(Map<String, dynamic> payload) async {
    if (!online) return const Result.failure(NetworkFailure());
    sent.add(payload);
    return const Result.success(82.5);
  }

  @override
  Future<ActiveWorkout?> loadActiveWorkout(String userId) async => active;
  @override
  Future<void> saveActiveWorkout(ActiveWorkout workout) async =>
      active = workout;
  @override
  Future<void> clearActiveWorkout(String userId) async => active = null;
  @override
  Future<List<PendingWorkout>> loadPendingWorkouts(String userId) async =>
      [...pending];
  @override
  Future<void> savePendingWorkouts(
          String userId, List<PendingWorkout> items) async =>
      pending = [...items];

  @override
  Future<Result<TrackableExercise>> createCustomExercise(
          {required String name,
          required TrackingType trackingType,
          String? equipment,
          double? bwFactor}) =>
      throw UnimplementedError();
  @override
  Future<Result<ExerciseHistory>> getExerciseHistory(String exerciseId) async =>
      const Result.success(
          ExerciseHistory(previousSets: [], personalBests: {}));
  @override
  Future<Result<List<WorkoutTemplate>>> getTemplates() async =>
      const Result.success([]);
  @override
  Future<Result<WorkoutDefaults>> getWorkoutDefaults() async =>
      const Result.success(WorkoutDefaults(preferredUnit: WeightUnit.kg));
  @override
  Future<Result<String>> createTemplate(
          {required String name,
          required List<({String exerciseId, int sets})> exercises}) =>
      throw UnimplementedError();
  @override
  Future<Result<String>> saveAsTemplate(
          {required String workoutId, required String name}) =>
      throw UnimplementedError();
  @override
  Future<Result<List<TrackableExercise>>> searchExercises(String query) =>
      throw UnimplementedError();
}
