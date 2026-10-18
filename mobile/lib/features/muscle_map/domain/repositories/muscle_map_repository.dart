import '../../../../core/error/result.dart';
import '../entities/muscle_activity.dart';
import '../services/muscle_mapping.dart';

abstract interface class MuscleMapRepository {
  /// The signed-in user's completed workouts finished after [since].
  Future<Result<List<CompletedWorkoutRecord>>> getCompletedWorkouts(
      DateTime since);

  /// Library muscle links per exercise id. Ids with no links are absent.
  Future<Result<Map<String, List<MuscleLink>>>> getMuscleLinks(
      Set<String> exerciseIds);
}
