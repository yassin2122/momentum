import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/error/exceptions.dart';

/// The only place in the health feature that talks to Supabase. Public
/// reads go through RPCs (they apply the provider's contact consent); the
/// owner edits their own rows under RLS.
class HealthRemoteDataSource {
  const HealthRemoteDataSource(this._client);

  final supabase.SupabaseClient _client;

  /// Public profile photos (`<listing_id>/<file>`).
  static const mediaBucket = 'health-media';

  /// Private credential documents (`<listing_id>/<file>`): owner + Grit only.
  static const documentBucket = 'health-credentials';

  static const _mineColumns =
      'id, provider_type, status, is_published, name, headline, description, '
      'specialties, logo_url, phone, whatsapp, email, website, address, area, '
      'city, latitude, longitude, health_profiles(photo_path, experience_years, '
      'languages, services, service_modes, clinic_name, availability_note, '
      'consultation_fee, fee_currency, booking_url, show_phone, show_whatsapp, '
      'phone_verified_at, submitted_at)';
  static const _credentialColumns =
      'id, listing_id, kind, title, issuer, year, document_path, status, review_note';

  String? get userId => _client.auth.currentUser?.id;

  String publicUrl(String path) => _client.storage.from(mediaBucket).getPublicUrl(path);

  // ---- public ----

  Future<List<Map<String, dynamic>>> directory(Map<String, dynamic> params) =>
      _guard(() async => _rows(await _client.rpc('get_health_directory', params: params)));

  Future<Map<String, dynamic>> provider(String listingId) => _guard(() async =>
      _map(await _client.rpc('get_health_provider', params: {'p_listing': listingId})));

  Future<List<Map<String, dynamic>>> saved() =>
      _guard(() async => _rows(await _client.rpc('get_my_saved_providers')));

  Future<void> save(String listingId) => _guard(() => _client
      .from('saved_providers')
      .insert({'user_id': userId, 'listing_id': listingId}));

  Future<void> unsave(String listingId) => _guard(() => _client
      .from('saved_providers')
      .delete()
      .eq('user_id', userId ?? '')
      .eq('listing_id', listingId));

  // ---- owner ----

  /// The caller's own doctor / physiotherapist listings (owner RLS).
  Future<List<Map<String, dynamic>>> myListings() => _guard(() async => _rows(await _client
      .from('marketplace_listings')
      .select(_mineColumns)
      .eq('owner_id', userId ?? '')
      .inFilter('provider_type', ['doctor', 'physical_therapist'])
      .isFilter('deleted_at', null)
      .order('created_at', ascending: true)));

  Future<List<Map<String, dynamic>>> credentials(String listingId) =>
      _guard(() async => _rows(await _client
          .from('health_credentials')
          .select(_credentialColumns)
          .eq('listing_id', listingId)
          .order('created_at', ascending: true)));

  Future<void> updateListing(String listingId, Map<String, dynamic> values) =>
      _guard(() async {
        if (values.isEmpty) return;
        await _client.from('marketplace_listings').update(values).eq('id', listingId);
      });

  Future<void> updateHealth(String listingId, Map<String, dynamic> values) =>
      _guard(() async {
        if (values.isEmpty) return;
        await _client.from('health_profiles').update(values).eq('listing_id', listingId);
      });

  Future<void> insertCredential(Map<String, dynamic> values) =>
      _guard(() => _client.from('health_credentials').insert(values));

  Future<void> updateCredential(String id, Map<String, dynamic> values) =>
      _guard(() => _client.from('health_credentials').update(values).eq('id', id));

  Future<void> deleteCredential(String id) =>
      _guard(() => _client.from('health_credentials').delete().eq('id', id));

  Future<void> upload(String bucket, String path, Uint8List bytes, String contentType) =>
      _guard(() => _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: supabase.FileOptions(contentType: contentType, upsert: false),
          ));

  Future<void> remove(String bucket, String path) =>
      _guard(() => _client.storage.from(bucket).remove([path]));

  Future<dynamic> rpc(String name, [Map<String, dynamic>? params]) =>
      _guard(() => _client.rpc(name, params: params));

  // ---- helpers ----

  static List<Map<String, dynamic>> _rows(dynamic rows) =>
      List<Map<String, dynamic>>.from(rows as List);

  static Map<String, dynamic> _map(dynamic json) => Map<String, dynamic>.from(json as Map);

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on supabase.PostgrestException catch (e) {
      throw ServerException(e.message);
    } on supabase.StorageException catch (e) {
      throw ServerException(e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }
}
