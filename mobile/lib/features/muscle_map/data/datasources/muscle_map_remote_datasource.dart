import 'package:supabase_flutter/supabase_flutter.dart';

/// Read-only Supabase access for the muscle map. Filters by the signed-in
/// user explicitly so a coach never sees an athlete's logs here.
class MuscleMapRemoteDataSource {
  const MuscleMapRemoteDataSource(this._client);

  final SupabaseClient _client;

  /// Keeps each `in.(...)` filter well under URL length limits.
  static const _idChunk = 100;
  static const _maxWorkouts = 300;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Not signed in');
    return user.id;
  }

  Future<List<Map<String, dynamic>>> completedWorkouts(DateTime since) async {
    final rows = await _client
        .from('workout_logs')
        .select('id, completed_at, workout_log_exercises'
            '(exercise_id, is_warmup, exercises(name), '
            'workout_log_sets(completed, set_type))')
        .eq('user_id', _userId)
        .eq('status', 'completed')
        .not('completed_at', 'is', null)
        .gte('completed_at', since.toUtc().toIso8601String())
        .order('completed_at', ascending: false)
        .limit(_maxWorkouts);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> muscleLinks(Set<String> ids) async {
    final all = ids.toList();
    final out = <Map<String, dynamic>>[];
    for (var i = 0; i < all.length; i += _idChunk) {
      final chunk = all.sublist(
          i, i + _idChunk > all.length ? all.length : i + _idChunk);
      final rows = await _client
          .from('exercise_muscle_groups')
          .select('exercise_id, is_primary, muscle_groups(name)')
          .inFilter('exercise_id', chunk);
      out.addAll(List<Map<String, dynamic>>.from(rows));
    }
    return out;
  }
}
