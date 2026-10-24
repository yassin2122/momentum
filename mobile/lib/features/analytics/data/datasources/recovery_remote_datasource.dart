import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase access for recovery check-ins (owner-only table).
class RecoveryRemoteDataSource {
  const RecoveryRemoteDataSource(this._client);

  final SupabaseClient _client;

  String get _userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Not signed in');
    return user.id;
  }

  Future<List<Map<String, dynamic>>> checkins(String sinceDate) async {
    final rows = await _client
        .from('recovery_checkins')
        .select('id, checkin_date, sleep_hours, sleep_quality, soreness, '
            'energy, fatigue, note')
        .eq('user_id', _userId)
        .gte('checkin_date', sinceDate)
        .order('checkin_date', ascending: false)
        .limit(120);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> upsert(Map<String, dynamic> row) => _client
      .from('recovery_checkins')
      .upsert({...row, 'user_id': _userId}, onConflict: 'user_id,checkin_date');
}
