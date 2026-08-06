import '../../../../core/error/result.dart';
import '../entities/exercise_entity.dart';
import '../repositories/exercise_repository.dart';

/// Encapsulates fetching a page of the exercise library, with optional
/// search and facet filters.
class GetExercises {
  const GetExercises(this._repository);

  final ExerciseRepository _repository;

  Future<Result<ExercisePage>> call({
    String? search,
    List<String> primaryMuscles = const [],
    List<String> equipment = const [],
    String? exerciseType,
    String? difficulty,
    int offset = 0,
    int limit = 30,
  }) {
    return _repository.getExercises(
      search: search,
      primaryMuscles: primaryMuscles,
      equipment: equipment,
      exerciseType: exerciseType,
      difficulty: difficulty,
      offset: offset,
      limit: limit,
    );
  }
}
