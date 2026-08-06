import '../../../../core/error/result.dart';
import '../repositories/exercise_repository.dart';

/// Toggles a favorite on/off. Returns the new favorite state
/// (`true` = exercise is now favorited).
class ToggleFavorite {
  const ToggleFavorite(this._repository);

  final ExerciseRepository _repository;

  Future<Result<bool>> call(String exerciseId) {
    return _repository.toggleFavorite(exerciseId);
  }
}
