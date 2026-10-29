import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../../core/error/exceptions.dart';

/// The only place in the gyms feature that talks to Supabase. RLS and the
/// RPCs from migration 20261029120000_gym_partner_platform decide what is
/// visible and allowed; this class just moves rows.
///
/// Every table query selects explicit columns — never `select('*')` — and
/// never the gym's coach-code hash (it isn't granted to the app anyway).
class GymRemoteDataSource {
  const GymRemoteDataSource(this._client);

  final supabase.SupabaseClient _client;

  /// Public bucket for logos, covers and gallery photos (`<gym_id>/<file>`).
  static const bucket = 'gym-media';

  static const _gymColumns =
      'id, listing_id, is_multi_branch, cover_path, facilities, equipment, '
      'services, marketplace_listings(name, headline, description, logo_url, '
      'phone, whatsapp, email, website, address, area, city)';
  static const _branchColumns =
      'id, gym_id, name, address, area, city, phone, opening_hours, open_24h, '
      'hours_note, facilities, is_published, sort_order';
  static const _offerColumns =
      'id, gym_id, name, price_amount, currency, duration_days, duration_label, '
      'benefits, branch_ids, is_visible, sort_order';
  static const _photoColumns = 'id, gym_id, storage_path, sort_order';
  static const _inquiryColumns =
      'id, gym_id, branch_id, offer_id, name, phone, contact_method, message, '
      'status, created_at';

  String publicUrl(String path) =>
      _client.storage.from(bucket).getPublicUrl(path);

  // ---- Public reads ----

  Future<List<Map<String, dynamic>>> directory({
    String? search,
    String? facility,
    int? limit,
  }) =>
      _guard(() async => _rows(await _client.rpc('get_gym_directory', params: {
            if (search != null && search.isNotEmpty) 'p_search': search,
            if (facility != null) 'p_facility': facility,
            if (limit != null) 'p_limit': limit,
          })));

  Future<Map<String, dynamic>?> gym(String gymId) => _guard(() => _client
      .from('gyms')
      .select(_gymColumns)
      .eq('id', gymId)
      .maybeSingle());

  Future<List<Map<String, dynamic>>> branches(String gymId) =>
      _guard(() async => _rows(await _client
          .from('gym_branches')
          .select(_branchColumns)
          .eq('gym_id', gymId)
          .isFilter('deleted_at', null)
          .order('sort_order', ascending: true)
          .order('name', ascending: true)));

  Future<List<Map<String, dynamic>>> offers(String gymId) =>
      _guard(() async => _rows(await _client
          .from('gym_offers')
          .select(_offerColumns)
          .eq('gym_id', gymId)
          .isFilter('deleted_at', null)
          .order('sort_order', ascending: true)
          .order('price_amount', ascending: true)));

  Future<List<Map<String, dynamic>>> photos(String gymId) =>
      _guard(() async => _rows(await _client
          .from('gym_photos')
          .select(_photoColumns)
          .eq('gym_id', gymId)
          .order('sort_order', ascending: true)
          .order('created_at', ascending: true)));

  Future<List<Map<String, dynamic>>> publicCoaches(String gymId) =>
      _guard(() async => _rows(await _client
          .rpc('get_gym_public_coaches', params: {'p_gym': gymId})));

  Future<void> recordView(String gymId) =>
      _guard(() => _client.rpc('record_gym_view', params: {'p_gym': gymId}));

  Future<String> submitInquiry(Map<String, dynamic> params) =>
      _guard(() async =>
          (await _client.rpc('submit_gym_inquiry', params: params)) as String);

  // ---- Admin reads ----

  Future<List<Map<String, dynamic>>> myGyms() =>
      _guard(() async => _rows(await _client.rpc('get_my_gyms')));

  Future<Map<String, dynamic>> overview(String gymId) => _guard(() async =>
      _map(await _client.rpc('get_gym_admin_overview', params: {'p_gym': gymId})));

  Future<Map<String, dynamic>> coachesAdmin(String gymId) => _guard(() async =>
      _map(await _client.rpc('get_gym_coaches_admin', params: {'p_gym': gymId})));

  Future<List<Map<String, dynamic>>> inquiries(String gymId) =>
      _guard(() async => _rows(await _client
          .from('gym_inquiries')
          .select(_inquiryColumns)
          .eq('gym_id', gymId)
          .order('created_at', ascending: false)
          .limit(200)));

  Future<List<Map<String, dynamic>>> staff(String gymId) => _guard(() async =>
      _rows(await _client.rpc('get_gym_staff', params: {'p_gym': gymId})));

  // ---- Admin writes (RLS-checked) ----

  Future<void> updateListing(String listingId, Map<String, dynamic> values) =>
      _guard(() async {
        if (values.isEmpty) return;
        await _client
            .from('marketplace_listings')
            .update(values)
            .eq('id', listingId);
      });

  Future<void> updateGym(String gymId, Map<String, dynamic> values) =>
      _guard(() async {
        if (values.isEmpty) return;
        await _client.from('gyms').update(values).eq('id', gymId);
      });

  Future<void> insertBranch(Map<String, dynamic> values) =>
      _guard(() => _client.from('gym_branches').insert(values));

  Future<void> updateBranch(String id, Map<String, dynamic> values) =>
      _guard(() => _client.from('gym_branches').update(values).eq('id', id));

  Future<void> insertOffer(Map<String, dynamic> values) =>
      _guard(() => _client.from('gym_offers').insert(values));

  Future<void> updateOffer(String id, Map<String, dynamic> values) =>
      _guard(() => _client.from('gym_offers').update(values).eq('id', id));

  Future<void> uploadMedia(String path, Uint8List bytes, String contentType) =>
      _guard(() => _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions:
                supabase.FileOptions(contentType: contentType, upsert: false),
          ));

  Future<void> removeMedia(String path) =>
      _guard(() => _client.storage.from(bucket).remove([path]));

  Future<void> insertPhoto(Map<String, dynamic> values) =>
      _guard(() => _client.from('gym_photos').insert(values));

  Future<void> deletePhoto(String id) =>
      _guard(() => _client.from('gym_photos').delete().eq('id', id));

  // ---- RPCs ----

  Future<dynamic> rpc(String name, [Map<String, dynamic>? params]) =>
      _guard(() => _client.rpc(name, params: params));

  Future<List<Map<String, dynamic>>> rowsRpc(
          String name, Map<String, dynamic> params) =>
      _guard(() async => _rows(await _client.rpc(name, params: params)));

  // ---- Helpers ----

  static List<Map<String, dynamic>> _rows(dynamic rows) =>
      List<Map<String, dynamic>>.from(rows as List);

  static Map<String, dynamic> _map(dynamic json) =>
      Map<String, dynamic>.from(json as Map);

  /// Same exception translation as the other remote datasources.
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
