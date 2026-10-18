import 'package:supabase_flutter/supabase_flutter.dart';

/// Raw Supabase access for the dashboard. Both calls are RPCs: the streak
/// and activity days are client-read-only, so nothing here writes a table.
class DashboardRemoteDataSource {
  const DashboardRemoteDataSource(this._client);

  final SupabaseClient _client;

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> recordAppOpen(DateTime localDate) async {
    final row = await _client.rpc('record_app_open',
        params: {'p_local_date': _date(localDate)});
    return Map<String, dynamic>.from(row as Map);
  }

  Future<Map<String, dynamic>> disciplineScore(DateTime localDate) async {
    final row = await _client.rpc('get_discipline_score',
        params: {'p_local_date': _date(localDate)});
    return Map<String, dynamic>.from(row as Map);
  }
}
