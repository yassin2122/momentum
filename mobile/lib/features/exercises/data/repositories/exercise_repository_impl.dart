import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/exercise_entity.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../datasources/exercise_remote_datasource.dart';
import '../models/exercise_model.dart';

/// Concrete [ExerciseRepository]. See [ExerciseRemoteDataSource]'s doc
/// comment for the exercise_library_view design decision — this class is
/// the boundary that would need to change (not the interface) if a FastAPI
/// backend is added later.
class ExerciseRepositoryImpl implements ExerciseRepository {
  const ExerciseRepositoryImpl(this._remoteDataSource, this._client);

  final ExerciseRemoteDataSource _remoteDataSource;
  final supabase.SupabaseClient _client;

  @override
  Future<Result<ExercisePage>> getExercises({
    String? search,
    List<String> primaryMuscles = const [],
    List<String> equipment = const [],
    String? exerciseType,
    String? difficulty,
    int offset = 0,
    int limit = 30,
  }) async {
    try {
      // Fetch one extra row to determine hasMore without a separate count query.
      final rows = await _remoteDataSource.fetchExercises(
        search: search,
        primaryMuscles: primaryMuscles,
        equipment: equipment,
        exerciseType: exerciseType,
        difficulty: difficulty,
        offset: offset,
        limit: limit + 1,
      );

      final hasMore = rows.length > limit;
      final pageRows = hasMore ? rows.sublist(0, limit) : rows;
      final items = pageRows.map(ExerciseModel.fromRow).toList();

      return Result.success(ExercisePage(
        items: items,
        hasMore: hasMore,
        nextOffset: offset + items.length,
      ));
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  @override
  Future<Result<ExerciseEntity>> getExerciseById(String id) async {
    try {
      final row = await _remoteDataSource.fetchExerciseById(id);
      return Result.success(ExerciseModel.fromRow(row));
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  @override
  Future<Result<ExerciseFilterOptions>> getExerciseFilters() async {
    try {
      final rows = await _remoteDataSource.fetchFacetRows();

      final muscles = <String>{};
      final equipmentSet = <String>{};
      final types = <String>{};
      final difficulties = <String>{};

      for (final row in rows) {
        final muscle = row['primary_muscle'] as String?;
        final equip = row['equipment'] as String?;
        final type = row['exercise_type'] as String?;
        final diff = row['difficulty'] as String?;
        if (muscle != null && muscle.isNotEmpty) muscles.add(muscle);
        if (equip != null && equip.isNotEmpty) equipmentSet.add(equip);
        if (type != null && type.isNotEmpty) types.add(type);
        if (diff != null && diff.isNotEmpty) difficulties.add(diff);
      }

      return Result.success(ExerciseFilterOptions(
        primaryMuscles: muscles.toList()..sort(),
        equipment: equipmentSet.toList()..sort(),
        exerciseTypes: types.toList()..sort(),
        difficulties: difficulties.toList()..sort(),
      ));
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  @override
  Future<Result<Set<String>>> getFavoriteIds() async {
    try {
      final ids = await _remoteDataSource.fetchFavoriteIds();
      return Result.success(ids);
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  @override
  Future<Result<bool>> toggleFavorite(String exerciseId) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return const Result.failure(UnknownFailure('Not authenticated'));

      // Determine current favorite state to decide insert vs delete.
      final currentIds = await _remoteDataSource.fetchFavoriteIds();
      final isFav = currentIds.contains(exerciseId);

      final newState = await _remoteDataSource.upsertFavorite(
        userId: userId,
        exerciseId: exerciseId,
        currentlyFavorited: isFav,
      );
      return Result.success(newState);
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(e.message));
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }
}
