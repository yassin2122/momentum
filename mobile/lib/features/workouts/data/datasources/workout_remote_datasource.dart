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
      'id, name, tracking_type, bw_factor, equipment, is_custom';

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Not signed in');
    }
    return user.id;
  }

  Future<List<Map<String, dynamic>>> searchExercises(String query) async {
    // Strip PostgREST pattern/syntax characters from user input.
    final term = query.replaceAll(RegExp(r'[%_,()*\\]'), ' ').trim();
    var request = _client.from('exercises').select(exerciseColumns);
    if (term.isNotEmpty) request = request.ilike('name', '%$term%');
    final rows = await request
        .order('is_custom', ascending: false)
        .order('name')
        .limit(50);
    return List<Map<String, dynamic>>.from(rows);
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
