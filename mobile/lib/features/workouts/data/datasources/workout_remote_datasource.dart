import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw Supabase access for the TRAIN logger. Returns plain maps; the
/// repository turns them into entities and errors into [Failure]s.
///
/// Every read filters by the signed-in user explicitly: RLS would also let
/// a coach see their athletes' rows (Connect), which must never leak into
/// the coach's own workout screens.
class WorkoutRemoteDataSource {
  const WorkoutRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const exerciseColumns =
      'id, name, tracking_type, bw_factor, equipment, is_custom, slug, images';

  /// Adds each exercise's muscle links so the picker can show the primary
  /// muscle. RLS: both tables are public-read.
  static const _withMuscles =
      '$exerciseColumns, exercise_muscle_groups(is_primary, muscle_groups(name))';

  /// Same, but as an inner join so it can filter by primary muscle group.
  static const _withMusclesInner = '$exerciseColumns, '
      'exercise_muscle_groups!inner(is_primary, muscle_groups!inner(name))';

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Not signed in');
    }
    return user.id;
  }

  /// Library + own custom exercises (RLS), A–Z. [muscleGroups] keeps only
  /// exercises whose PRIMARY muscle group is one of them.
  Future<List<Map<String, dynamic>>> searchExercises(
    String query, {
    List<String> muscleGroups = const [],
    int offset = 0,
    int limit = 50,
  }) async {
    // Strip PostgREST pattern/syntax characters from user input.
    final term = query.replaceAll(RegExp(r'[%_,()*\\]'), ' ').trim();
    var request = _client
        .from('exercises')
        .select(muscleGroups.isEmpty ? _withMuscles : _withMusclesInner);
    if (term.isNotEmpty) request = request.ilike('name', '%$term%');
    if (muscleGroups.isNotEmpty) {
      request = request
          .eq('exercise_muscle_groups.is_primary', true)
          .inFilter('exercise_muscle_groups.muscle_groups.name', muscleGroups);
    }
    final rows = await request
        .order('is_custom', ascending: false)
        .order('name')
        .range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Exercises by library slug (order not guaranteed).
  Future<List<Map<String, dynamic>>> exercisesBySlugs(List<String> slugs) async {
    if (slugs.isEmpty) return const [];
    final rows = await _client
        .from('exercises')
        .select(_withMuscles)
        .inFilter('slug', slugs);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Exercises by id (order not guaranteed).
  Future<List<Map<String, dynamic>>> exercisesByIds(List<String> ids) async {
    if (ids.isEmpty) return const [];
    final rows = await _client
        .from('exercises')
        .select(_withMuscles)
        .inFilter('id', ids);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Exercise ids from the user's most recent workouts, newest first,
  /// without duplicates.
  Future<List<String>> recentExerciseIds({int workouts = 8}) async {
    final rows = await _client
        .from('workout_logs')
        .select('started_at, workout_log_exercises(exercise_id, order_index)')
        .eq('user_id', _userId)
        .order('started_at', ascending: false)
        .limit(workouts);
    final ids = <String>[];
    for (final w in rows) {
      final items = [
        for (final e in (w['workout_log_exercises'] as List? ?? const []))
          Map<String, dynamic>.from(e as Map),
      ]..sort((a, b) => ((a['order_index'] as num?) ?? 0)
          .compareTo((b['order_index'] as num?) ?? 0));
      for (final e in items) {
        final id = e['exercise_id'] as String?;
        if (id != null && !ids.contains(id)) ids.add(id);
      }
    }
    return ids;
  }

  Future<Map<String, dynamic>> createCustomExercise({
    required String name,
    required String trackingType,
    String? equipment,
    double? bwFactor,
  }) async {
    final row = await _client.rpc('create_custom_exercise', params: {
      'p_name': name,
      'p_tracking_type': trackingType,
      'p_equipment': equipment,
      'p_bw_factor': bwFactor,
    });
    return Map<String, dynamic>.from(row as Map);
  }

  Future<List<Map<String, dynamic>>> fetchTemplates() async {
    final rows = await _client
        .from('workout_templates')
        .select('id, name, workout_template_exercises'
            '(order_index, target_sets, exercises($exerciseColumns))')
        .eq('user_id', _userId)
        .isFilter('deleted_at', null)
        .order('updated_at', ascending: false);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// Soft-deletes a template (sets `deleted_at`). Past workouts keep their
  /// link, and `finish_workout` already ignores a template deleted
  /// mid-workout. RLS: owner-only.
  Future<void> deleteTemplate(String templateId) async {
    await _client
        .from('workout_templates')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', templateId)
        .eq('user_id', _userId);
  }

  Future<List<Map<String, dynamic>>> lastPerformance(String exerciseId) async {
    final rows = await _client.rpc('get_last_exercise_performance',
        params: {'p_exercise_id': exerciseId});
    return [
      for (final r in (rows as List? ?? const []))
        Map<String, dynamic>.from(r as Map),
    ];
  }

  Future<List<Map<String, dynamic>>> personalBests(String exerciseId) async {
    final rows = await _client
        .from('personal_records')
        .select('metric_type, value')
        .eq('user_id', _userId)
        .eq('exercise_id', exerciseId);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<String?> preferredUnit() async {
    final row = await _client
        .from('user_settings')
        .select('preferred_unit')
        .eq('user_id', _userId)
        .maybeSingle();
    return row?['preferred_unit'] as String?;
  }

  Future<double?> latestBodyweightKg() async {
    final row = await _client
        .from('body_metrics_log')
        .select('weight_kg')
        .eq('user_id', _userId)
        .not('weight_kg', 'is', null)
        .order('logged_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return (row?['weight_kg'] as num?)?.toDouble();
  }

  Future<Map<String, dynamic>> finishWorkout(
      Map<String, dynamic> payload) async {
    final result =
        await _client.rpc('finish_workout', params: {'p_workout': payload});
    return Map<String, dynamic>.from(result as Map);
  }

  /// Creates a template from scratch: the `workout_templates` row, then
  /// its exercises in order. If the exercises fail to save, the empty
  /// template is removed again so no half-made template is left behind.
  Future<String> createTemplate({
    required String name,
    required List<({String exerciseId, int sets})> exercises,
  }) async {
    final row = await _client
        .from('workout_templates')
        .insert({'user_id': _userId, 'name': name})
        .select('id')
        .single();
    final templateId = row['id'] as String;
    try {
      await _client.from('workout_template_exercises').insert([
        for (var i = 0; i < exercises.length; i++)
          {
            'template_id': templateId,
            'exercise_id': exercises[i].exerciseId,
            'order_index': i,
            'target_sets': exercises[i].sets,
          },
      ]);
    } catch (_) {
      await _client.from('workout_templates').delete().eq('id', templateId);
      rethrow;
    }
    return templateId;
  }

  Future<String> createTemplateFromWorkout({
    required String workoutId,
    required String name,
  }) async {
    final id = await _client.rpc('create_template_from_workout', params: {
      'p_workout_log_id': workoutId,
      'p_name': name,
    });
    return id as String;
  }
}
