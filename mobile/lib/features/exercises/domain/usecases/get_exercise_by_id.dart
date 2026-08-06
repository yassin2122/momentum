import '../../../../core/error/result.dart';
import '../entities/exercise_entity.dart';
import '../repositories/exercise_repository.dart';

/// Encapsulates fetching a single exercise by its UUID.
/// Used by the Detail screen; shares [ExerciseEntity] with the list.
class GetExerciseById {
  const GetExerciseById(this._repository);

  final ExerciseRepository _repository;

  Future<Result<ExerciseEntity>> call(String id) {
    return _repository.getExerciseById(id);
  }
}
