import '../../../../core/error/result.dart';
import '../entities/exercise_entity.dart';

/// Contract for reading exercise library data and managing favorites.
/// The domain and presentation layers depend only on this interface —
/// today it's implemented against Supabase directly (see
/// [ExerciseRepositoryImpl]'s doc comment for why), but nothing above
/// this interface knows that.
abstract interface class ExerciseRepository {
  Future<Result<ExercisePage>> getExercises({
    String? search,
    List<String> primaryMuscles = const [],
    List<String> equipment = const [],
    String? exerciseType,
    String? difficulty,
    int offset = 0,
    int limit = 30,
  });

  Future<Result<ExerciseEntity>> getExerciseById(String id);

  Future<Result<ExerciseFilterOptions>> getExerciseFilters();

  /// Returns the set of exercise IDs the current user has favorited.
  Future<Result<Set<String>>> getFavoriteIds();

  /// Adds or removes the exercise from the user's favorites.
  /// Returns the new favorite state (`true` = now favorited).
  Future<Result<bool>> toggleFavorite(String exerciseId);
}
