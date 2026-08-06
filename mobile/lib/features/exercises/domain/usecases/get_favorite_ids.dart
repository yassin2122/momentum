import '../../../../core/error/result.dart';
import '../repositories/exercise_repository.dart';

/// Returns the set of exercise IDs the current user has favorited.
class GetFavoriteIds {
  const GetFavoriteIds(this._repository);

  final ExerciseRepository _repository;

  Future<Result<Set<String>>> call() {
    return _repository.getFavoriteIds();
  }
}
