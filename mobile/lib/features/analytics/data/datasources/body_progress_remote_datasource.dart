import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase access for Body progress. Always filters by the signed-in user,
/// so a Captain's session never reads someone else's rows here (RLS would
/// also allow a consented Captain to read body metrics — this screen is
/// the athlete's own view only).
class BodyProgressRemoteDataSource {
  const BodyProgressRemoteDataSource(this._client);

  final SupabaseClient _client;

  static const bucket = 'progress-photos';

  /// Signed photo URLs stay valid this long (seconds).
  static const signedUrlSeconds = 60 * 60;

  static const _maxEntries = 730;
  static const _maxPhotos = 120;

  static const entryColumns = 'id, logged_at, weight_kg, body_fat_pct, '
      'neck_cm, chest_cm, waist_cm, hips_cm, arm_cm, thigh_cm, calf_cm, '
      'note, created_at';

  String get userId {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('Not signed in');
    return user.id;
  }

  Future<List<Map<String, dynamic>>> entries() async {
    final rows = await _client
        .from('body_metrics_log')
        .select(entryColumns)
        .eq('user_id', userId)
        .order('logged_at', ascending: false)
        .order('created_at', ascending: false)
        .limit(_maxEntries);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> insertEntry(Map<String, dynamic> row) =>
      _client.from('body_metrics_log').insert({...row, 'user_id': userId});

  Future<void> deleteEntry(String id) => _client
      .from('body_metrics_log')
      .delete()
      .eq('id', id)
      .eq('user_id', userId);

  Future<Map<String, dynamic>?> goal() => _client
      .from('body_goals')
      .select('target_weight_kg, start_weight_kg, target_date, created_at')
      .eq('user_id', userId)
      .maybeSingle();

  Future<void> upsertGoal(Map<String, dynamic> row) => _client
      .from('body_goals')
      .upsert({...row, 'user_id': userId}, onConflict: 'user_id');

  Future<void> deleteGoal() =>
      _client.from('body_goals').delete().eq('user_id', userId);

  Future<List<Map<String, dynamic>>> photos() async {
    final rows = await _client
        .from('progress_photos')
        .select('id, storage_path, pose, taken_on, note, created_at')
        .eq('user_id', userId)
        .order('taken_on', ascending: false)
        .order('created_at', ascending: false)
        .limit(_maxPhotos);
    return List<Map<String, dynamic>>.from(rows);
  }

  /// A short-lived URL for one private object, or null if it fails (e.g.
  /// the object is missing) — one bad photo shouldn't hide the rest.
  Future<String?> signedUrl(String path) async {
    try {
      return await _client.storage
          .from(bucket)
          .createSignedUrl(path, signedUrlSeconds);
    } catch (_) {
      return null;
    }
  }

  Future<void> uploadPhoto(String path, Uint8List bytes, String contentType) =>
      _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: false),
          );

  Future<void> removeObject(String path) =>
      _client.storage.from(bucket).remove([path]);

  Future<void> insertPhoto(Map<String, dynamic> row) =>
      _client.from('progress_photos').insert({...row, 'user_id': userId});

  Future<void> deletePhotoRow(String id) => _client
      .from('progress_photos')
      .delete()
      .eq('id', id)
      .eq('user_id', userId);
}
