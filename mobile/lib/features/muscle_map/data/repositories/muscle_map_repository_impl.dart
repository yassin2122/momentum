import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/muscle_activity.dart';
import '../../domain/repositories/muscle_map_repository.dart';
import '../../domain/services/muscle_mapping.dart';
import '../datasources/muscle_map_remote_datasource.dart';

class MuscleMapRepositoryImpl implements MuscleMapRepository {
  const MuscleMapRepositoryImpl(this._remote);

  final MuscleMapRemoteDataSource _remote;

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Result.success(await call());
    } on PostgrestException {
      return const Result.failure(
          ServerFailure('Something went wrong. Please try again.'));
    } on AuthException {
      return const Result.failure(ServerFailure('Please sign in again.'));
    } catch (_) {
      return const Result.failure(NetworkFailure());
    }
  }

  @override
  Future<Result<List<CompletedWorkoutRecord>>> getCompletedWorkouts(
          DateTime since) =>
      _guard(() async => [
            for (final row in await _remote.completedWorkouts(since))
              workoutFromRow(row),
          ]);

  @override
  Future<Result<Map<String, List<MuscleLink>>>> getMuscleLinks(
      Set<String> exerciseIds) async {
    if (exerciseIds.isEmpty) return const Result.success({});
    return _guard(() async => linksFromRows(await _remote.muscleLinks(exerciseIds)));
  }

  /// Maps a `workout_logs` row with nested exercises and sets. Warm-up
  /// exercises and warm-up or unfinished sets don't count.
  static CompletedWorkoutRecord workoutFromRow(Map<String, dynamic> row) {
    final exercises = <LoggedExerciseRecord>[];
    for (final e in (row['workout_log_exercises'] as List? ?? const [])) {
      final ex = Map<String, dynamic>.from(e as Map);
      if (ex['is_warmup'] == true) continue;
      final sets = (ex['workout_log_sets'] as List? ?? const [])
          .map((s) => Map<String, dynamic>.from(s as Map))
          .where((s) => s['completed'] != false && s['set_type'] != 'warmup')
          .length;
      final exerciseId = ex['exercise_id'] as String?;
      if (exerciseId == null) continue;
      exercises.add(LoggedExerciseRecord(
        exerciseId: exerciseId,
        exerciseName:
            (ex['exercises'] as Map?)?['name'] as String? ?? 'Exercise',
        workingSets: sets,
      ));
    }
    return CompletedWorkoutRecord(
      id: row['id'] as String,
      completedAt: DateTime.tryParse(row['completed_at'] as String? ?? '')
          ?.toLocal(),
      exercises: exercises,
    );
  }

  static Map<String, List<MuscleLink>> linksFromRows(
      List<Map<String, dynamic>> rows) {
    final out = <String, List<MuscleLink>>{};
    for (final r in rows) {
      final name = (r['muscle_groups'] as Map?)?['name'] as String?;
      final id = r['exercise_id'] as String?;
      if (name == null || id == null) continue;
      out.putIfAbsent(id, () => []).add(MuscleLink(
            groupName: name,
            isPrimary: r['is_primary'] as bool? ?? false,
          ));
    }
    return out;
  }
}
