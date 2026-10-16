import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/active_workout.dart';
import '../../domain/entities/logged_set.dart';
import '../../domain/entities/pending_workout.dart';
import '../../domain/entities/trackable_exercise.dart';
import '../../domain/entities/workout_enums.dart';
import '../../domain/entities/workout_template.dart';
import '../../domain/repositories/workout_repository.dart';
import '../datasources/workout_local_datasource.dart';
import '../datasources/workout_remote_datasource.dart';

class WorkoutRepositoryImpl implements WorkoutRepository {
  const WorkoutRepositoryImpl(this._remote, this._local);

  final WorkoutRemoteDataSource _remote;
  final WorkoutLocalDataSource _local;

  /// Runs a remote call, mapping errors to [Failure]s. Postgres errors
  /// raised on purpose by our RPCs/triggers carry a user-safe message.
  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Result.success(await call());
    } on PostgrestException catch (e) {
      const userFacing = {'23505', '22023', 'P0001', 'P0002', '23503'};
      return Result.failure(ServerFailure(
        userFacing.contains(e.code)
            ? e.message
            : 'Something went wrong. Please try again.',
      ));
    } on AuthException {
      return const Result.failure(ServerFailure('Please sign in again.'));
    } catch (_) {
      // Transport errors (offline, timeouts) — callers may retry.
      return const Result.failure(NetworkFailure());
    }
  }

  @override
  Future<Result<List<TrackableExercise>>> searchExercises(String query) =>
      _guard(() async => [
            for (final row in await _remote.searchExercises(query))
              TrackableExercise.fromJson(row),
          ]);

  @override
  Future<Result<TrackableExercise>> createCustomExercise({
    required String name,
    required TrackingType trackingType,
    String? equipment,
    double? bwFactor,
  }) =>
      _guard(() async => TrackableExercise.fromJson(
            await _remote.createCustomExercise(
              name: name,
              trackingType: trackingType.dbValue,
              equipment: equipment,
              bwFactor: bwFactor,
            ),
          ));

  @override
  Future<Result<List<WorkoutTemplate>>> getTemplates() =>
      _guard(() async => [
            for (final row in await _remote.fetchTemplates())
              _templateFromRow(row),
          ]);

  static WorkoutTemplate _templateFromRow(Map<String, dynamic> row) {
    final items = [
      for (final e in (row['workout_template_exercises'] as List? ?? const []))
        Map<String, dynamic>.from(e as Map),
    ]..sort((a, b) =>
        (a['order_index'] as int).compareTo(b['order_index'] as int));
    return WorkoutTemplate(
      id: row['id'] as String,
      name: row['name'] as String,
      exercises: [
        for (final item in items)
          // null when the exercise isn't visible any more (e.g. deleted)
          if (item['exercises'] != null)
            TemplateExercise(
              exercise: TrackableExercise.fromJson(
                  Map<String, dynamic>.from(item['exercises'] as Map)),
              defaultSets: item['target_sets'] as int?,
            ),
      ],
    );
  }

  @override
  Future<Result<ExerciseHistory>> getExerciseHistory(String exerciseId) =>
      _guard(() async {
        final results = await Future.wait([
          _remote.lastPerformance(exerciseId),
          _remote.personalBests(exerciseId),
        ]);
        return ExerciseHistory(
          previousSets: [
            for (final row in results[0]) PreviousSet.fromJson(row),
          ],
          personalBests: {
            for (final row in results[1])
              if (PrMetric.fromDb(row['metric_type'] as String?) != null)
                PrMetric.fromDb(row['metric_type'] as String?)!:
                    (row['value'] as num).toDouble(),
          },
        );
      });

  @override
  Future<Result<WorkoutDefaults>> getWorkoutDefaults() => _guard(() async {
        final results = await Future.wait<Object?>([
          _remote.preferredUnit(),
          _remote.latestBodyweightKg(),
        ]);
        return WorkoutDefaults(
          preferredUnit: WeightUnit.fromDb(results[0] as String?),
          bodyweightKg: results[1] as double?,
        );
      });

  @override
  Future<Result<double?>> finishWorkout(Map<String, dynamic> payload) =>
      _guard(() async {
        final result = await _remote.finishWorkout(payload);
        return (result['bodyweight_snapshot_kg'] as num?)?.toDouble();
      });

  @override
  Future<Result<String>> saveAsTemplate({
    required String workoutId,
    required String name,
  }) =>
      _guard(() =>
          _remote.createTemplateFromWorkout(workoutId: workoutId, name: name));

  @override
  Future<ActiveWorkout?> loadActiveWorkout(String userId) =>
      _local.loadActive(userId);

  @override
  Future<void> saveActiveWorkout(ActiveWorkout workout) =>
      _local.saveActive(workout);

  @override
  Future<void> clearActiveWorkout(String userId) => _local.clearActive(userId);

  @override
  Future<List<PendingWorkout>> loadPendingWorkouts(String userId) =>
      _local.loadPending(userId);

  @override
  Future<void> savePendingWorkouts(String userId, List<PendingWorkout> items) =>
      _local.savePending(userId, items);
}
