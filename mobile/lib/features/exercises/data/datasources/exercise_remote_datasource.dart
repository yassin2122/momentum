import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/error/exceptions.dart';

/// Wraps raw Supabase/PostgREST calls against `exercise_library_view` and
/// `exercise_library_facets_view`. This is the ONLY place in the exercises
/// feature that talks to Supabase directly — everything above it
/// (repository, use cases, presentation) only knows [ExerciseRepository]'s
/// interface.
///
/// Why exercise_library_view instead of public.exercises?
/// The relational schema (exercises + exercise_muscles + muscle_groups +
/// exercise_equipment + equipment + exercise_images) would require complex
/// PostgREST embeds or N+1 round-trips. The view flattens these into one
/// row per exercise, mapping 1:1 to ExerciseEntity. RLS is preserved via
/// security_invoker=true on the view.
class ExerciseRemoteDataSource {
  const ExerciseRemoteDataSource(this._client);

  final supabase.SupabaseClient _client;

  /// Columns fetched for list rows — instructions excluded for performance
  /// (fetched individually in the detail query).
  static const _listColumns =
      'id, name, slug, exercise_type, difficulty, is_custom, '
      'primary_muscle, secondary_muscles, equipment, images';

  /// All columns needed by the detail screen.
  static const _detailColumns =
      'id, name, slug, description, exercise_type, difficulty, '
      'mechanics, force, is_custom, primary_muscle, primary_muscle_id, '
      'secondary_muscles, equipment, images, instructions';

  Future<List<Map<String, dynamic>>> fetchExercises({
    String? search,
    List<String> primaryMuscles = const [],
    List<String> equipment = const [],
    String? exerciseType,
    String? difficulty,
    required int offset,
    required int limit,
  }) async {
    try {
      var query =
          _client.from('exercise_library_view').select(_listColumns);

      if (search != null && search.trim().isNotEmpty) {
        // pg_trgm trigram index on exercises.name applies through the view.
        query = query.ilike('name', '%${search.trim()}%');
      }
      if (primaryMuscles.isNotEmpty) {
        query = query.inFilter('primary_muscle', primaryMuscles);
      }
      if (equipment.isNotEmpty) {
        // equipment is a text[] in the view; `cs` = contains (@>) in PostgREST.
        query = query.contains('equipment', equipment);
      }
      if (exerciseType != null) {
        query = query.eq('exercise_type', exerciseType);
      }
      if (difficulty != null) {
        query = query.eq('difficulty', difficulty);
      }

      final rows = await query
          .order('name', ascending: true)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(rows as List);
    } on supabase.PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }

  Future<Map<String, dynamic>> fetchExerciseById(String id) async {
    try {
      final row = await _client
          .from('exercise_library_view')
          .select(_detailColumns)
          .eq('id', id)
          .single();
      return Map<String, dynamic>.from(row as Map);
    } on supabase.PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }

  /// Fetches raw facet rows from `exercise_library_facets_view`.
  /// The view already unnests equipment[] so each row is one
  /// (primary_muscle, equipment, exercise_type, difficulty) tuple —
  /// no client-side unnesting needed.
  Future<List<Map<String, dynamic>>> fetchFacetRows() async {
    try {
      final rows = await _client
          .from('exercise_library_facets_view')
          .select('primary_muscle, equipment, exercise_type, difficulty');
      return List<Map<String, dynamic>>.from(rows as List);
    } on supabase.PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }

  /// Returns the set of exercise IDs favorited by the current user.
  Future<Set<String>> fetchFavoriteIds() async {
    try {
      final rows = await _client
          .from('favorites')
          .select('exercise_id')
          .not('exercise_id', 'is', null);
      return {
        for (final row in rows as List)
          (row as Map<String, dynamic>)['exercise_id'] as String,
      };
    } on supabase.PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }

  /// Inserts or deletes a row in the favorites table.
  /// Returns `true` when the exercise is now favorited.
  Future<bool> upsertFavorite({
    required String userId,
    required String exerciseId,
    required bool currentlyFavorited,
  }) async {
    try {
      if (currentlyFavorited) {
        await _client
            .from('favorites')
            .delete()
            .eq('user_id', userId)
            .eq('exercise_id', exerciseId);
        return false;
      } else {
        // ON CONFLICT DO NOTHING — favorites has no update policy.
        await _client.from('favorites').upsert({
          'user_id': userId,
          'exercise_id': exerciseId,
        }, ignoreDuplicates: true);
        return true;
      }
    } on supabase.PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }
}
