import '../../../../core/error/result.dart';
import '../entities/exercise_entity.dart';
import '../repositories/exercise_repository.dart';

/// Encapsulates fetching the distinct facet values (muscle groups,
/// equipment, types) actually present in the library.
class GetExerciseFilters {
  const GetExerciseFilters(this._repository);

  final ExerciseRepository _repository;

  Future<Result<ExerciseFilterOptions>> call() {
    return _repository.getExerciseFilters();
  }
}
