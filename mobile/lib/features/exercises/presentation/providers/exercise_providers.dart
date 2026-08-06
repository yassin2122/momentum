import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../data/datasources/exercise_remote_datasource.dart';
import '../../data/repositories/exercise_repository_impl.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/usecases/get_exercise_by_id.dart';
import '../../domain/usecases/get_exercise_filters.dart';
import '../../domain/usecases/get_exercises.dart';
import '../../domain/usecases/get_favorite_ids.dart';
import '../../domain/usecases/toggle_favorite.dart';

final exerciseRemoteDataSourceProvider =
    Provider<ExerciseRemoteDataSource>((ref) {
  return ExerciseRemoteDataSource(ref.watch(supabaseClientProvider));
});

final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepositoryImpl(
    ref.watch(exerciseRemoteDataSourceProvider),
    ref.watch(supabaseClientProvider),
  );
});

final getExercisesProvider = Provider<GetExercises>((ref) {
  return GetExercises(ref.watch(exerciseRepositoryProvider));
});

final getExerciseByIdProvider = Provider<GetExerciseById>((ref) {
  return GetExerciseById(ref.watch(exerciseRepositoryProvider));
});

final getExerciseFiltersProvider = Provider<GetExerciseFilters>((ref) {
  return GetExerciseFilters(ref.watch(exerciseRepositoryProvider));
});

final getFavoriteIdsProvider = Provider<GetFavoriteIds>((ref) {
  return GetFavoriteIds(ref.watch(exerciseRepositoryProvider));
});

final toggleFavoriteProvider = Provider<ToggleFavorite>((ref) {
  return ToggleFavorite(ref.watch(exerciseRepositoryProvider));
});
