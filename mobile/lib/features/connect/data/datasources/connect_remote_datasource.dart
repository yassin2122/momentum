import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/error/exceptions.dart';

/// The only place in the connect feature that talks to Supabase. Returns raw
/// rows; RLS (migrations 28–29) decides what is visible, and lifecycle
/// changes go through the RPCs from migrations 30–32.
///
/// Every table query selects explicit columns — never `select('*')`.
class ConnectRemoteDataSource {
  const ConnectRemoteDataSource(this._client);

  final supabase.SupabaseClient _client;

  static const _relationshipColumns =
      'id, athlete_id, coach_id, plan_id, status, requested_at, started_at, '
      'ended_at, ended_by';
  static const _permissionColumns =
      'relationship_id, share_workouts, share_prs, share_skill_progress, '
      'share_body_metrics, updated_at';
  static const _feedbackColumns =
      'id, relationship_id, author_id, workout_log_id, skill_id, body, '
      'created_at';
  static const _goalColumns =
      'id, relationship_id, title, description, target_date, status, '
      'created_by, created_at, updated_at';
  static const _assignmentColumns =
      'id, relationship_id, program_id, assigned_by, start_date, status, '
      'instructions, enrollment_id, completed_at, created_at';

  // ---- Reads ----

  Future<List<Map<String, dynamic>>> fetchCoachDirectory({
    String? specialty,
    int? limit,
  }) =>
      _guard(() async {
        final rows = await _client.rpc('get_coach_directory', params: {
          if (specialty != null) 'p_specialty': specialty,
          if (limit != null) 'p_limit': limit,
        });
        return _rows(rows);
      });

  Future<List<Map<String, dynamic>>> fetchRelationships() =>
      _guard(() async => _rows(await _client
          .from('coaching_relationships')
          .select(_relationshipColumns)
          .order('requested_at', ascending: false)));

  Future<Map<String, dynamic>?> fetchPermissions(String relationshipId) =>
      _guard(() => _client
          .from('coaching_permissions')
          .select(_permissionColumns)
          .eq('relationship_id', relationshipId)
          .maybeSingle());

  Future<List<Map<String, dynamic>>> fetchFeedback(String relationshipId) =>
      _guard(() async => _rows(await _client
          .from('coaching_feedback')
          .select(_feedbackColumns)
          .eq('relationship_id', relationshipId)
          .order('created_at', ascending: false)));

  Future<List<Map<String, dynamic>>> fetchGoals(String relationshipId) =>
      _guard(() async => _rows(await _client
          .from('coaching_goals')
          .select(_goalColumns)
          .eq('relationship_id', relationshipId)
          .order('created_at', ascending: false)));

  Future<List<Map<String, dynamic>>> fetchAssignments(String relationshipId) =>
      _guard(() async => _rows(await _client
          .from('program_assignments')
          .select(_assignmentColumns)
          .eq('relationship_id', relationshipId)
          .order('created_at', ascending: false)));

  Future<Map<String, dynamic>?> fetchAthleteBodyProfile(String athleteId) =>
      _guard(() async {
        final rows = _rows(await _client
            .rpc('get_athlete_body_profile', params: {'p_athlete': athleteId}));
        return rows.isEmpty ? null : rows.first;
      });

  // ---- Writes allowed by RLS ----

  /// Returns the number of rows updated — 0 means RLS filtered the row out.
  Future<int> updatePermissions(
          String relationshipId, Map<String, bool> changes) =>
      _guard(() async {
        final rows = await _client
            .from('coaching_permissions')
            .update(changes)
            .eq('relationship_id', relationshipId)
            .select('relationship_id');
        return (rows as List).length;
      });

  Future<Map<String, dynamic>> insertFeedback(Map<String, dynamic> values) =>
      _guard(() => _client
          .from('coaching_feedback')
          .insert(values)
          .select(_feedbackColumns)
          .single());

  // ---- RPCs ----

  /// Calls an RPC and returns its raw result (uuid string, or null for void).
  Future<dynamic> callRpc(String name, Map<String, dynamic> params) =>
      _guard(() => _client.rpc(name, params: params));

  // ---- Helpers ----

  static List<Map<String, dynamic>> _rows(dynamic rows) =>
      List<Map<String, dynamic>>.from(rows as List);

  /// Same exception translation as the other remote datasources.
  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on supabase.PostgrestException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }
}
