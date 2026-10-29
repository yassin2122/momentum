import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/health_entities.dart';
import '../../domain/repositories/health_repository.dart';
import '../datasources/health_remote_datasource.dart';
import '../models/health_models.dart';

class HealthRepositoryImpl implements HealthRepository {
  const HealthRepositoryImpl(this._remote);

  final HealthRemoteDataSource _remote;

  static const _uuid = Uuid();

  Future<Result<T>> _run<T>(Future<T> Function() body) async {
    try {
      return Result.success(await body());
    } on ServerException catch (e) {
      return Result.failure(ServerFailure(_friendly(e.message)));
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  static String _friendly(String message) {
    if (message.contains('listing_has_contact')) {
      return 'Keep at least one contact on your profile: phone, WhatsApp, email or website.';
    }
    if (message.contains('check constraint') &&
        (message.contains('booking_url') || message.contains('website'))) {
      return 'Links need to start with https://';
    }
    if (message.contains('phone') && message.contains('check constraint')) {
      return 'Enter the phone number with digits only, e.g. +20 2 2358 4400.';
    }
    if (message.contains('violates check constraint')) {
      return 'Some details aren\'t in the right format. Check the fields and try again.';
    }
    if (message.contains('row-level security')) {
      return 'You can only change your own profile.';
    }
    return message;
  }

  static String _ext(String contentType) => switch (contentType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        'application/pdf' => 'pdf',
        _ => 'jpg',
      };

  // ---- athletes ----

  @override
  Future<Result<List<HealthDirectoryEntry>>> getDirectory({
    String? search,
    HealthKind? kind,
    String? specialty,
    HealthServiceMode? mode,
    bool verifiedOnly = false,
  }) =>
      _run(() async => [
            for (final r in await _remote.directory({
              if (search != null && search.trim().isNotEmpty) 'p_search': search.trim(),
              if (kind != null) 'p_kind': kind.dbValue,
              if (specialty != null) 'p_specialty': specialty,
              if (mode != null) 'p_mode': mode.dbValue,
              if (verifiedOnly) 'p_verified_only': true,
            }))
              HealthModels.entry(r),
          ]);

  @override
  Future<Result<HealthProviderDetail>> getProvider(String listingId) =>
      _run(() async => HealthModels.detail(await _remote.provider(listingId)));

  @override
  Future<Result<List<HealthDirectoryEntry>>> getSaved() =>
      _run(() async => [for (final r in await _remote.saved()) HealthModels.entry(r)]);

  @override
  Future<Result<void>> setSaved(String listingId, bool saved) =>
      _run(() => saved ? _remote.save(listingId) : _remote.unsave(listingId));

  // ---- providers ----

  @override
  Future<Result<List<MyHealthProfile>>> getMine() => _run(() async {
        final listings = await _remote.myListings();
        return [
          for (final l in listings)
            HealthModels.mine(l, await _remote.credentials('${l['id']}')),
        ];
      });

  @override
  Future<Result<String>> create({
    required HealthKind kind,
    required String name,
    required String specialty,
    required String city,
    required String phone,
  }) =>
      _run(() async => '${await _remote.rpc('create_health_profile', {
            'p_kind': kind.dbValue,
            'p_name': name.trim(),
            'p_specialty': specialty.trim(),
            'p_city': city.trim(),
            'p_phone': phone.trim(),
          })}');

  @override
  Future<Result<void>> update(MyHealthProfile current, HealthProfilePatch patch) =>
      _run(() async {
        final (listing, health) = HealthModels.patchRows(patch);
        // health first: turning a contact switch off must not be undone by a
        // listing-side failure afterwards.
        await _remote.updateHealth(current.listingId, health);
        await _remote.updateListing(current.listingId, listing);
      });

  @override
  Future<Result<void>> setPhoto(MyHealthProfile current, Uint8List bytes, String contentType) =>
      _run(() async {
        final path = '${current.listingId}/photo-${_uuid.v4()}.${_ext(contentType)}';
        await _remote.upload(HealthRemoteDataSource.mediaBucket, path, bytes, contentType);
        try {
          await _remote.updateHealth(current.listingId, {'photo_path': path});
          await _remote.updateListing(current.listingId, {'logo_url': _remote.publicUrl(path)});
        } catch (_) {
          await _remote.remove(HealthRemoteDataSource.mediaBucket, path);
          rethrow;
        }
        final old = current.photoPath;
        if (old != null && old != path) {
          try {
            await _remote.remove(HealthRemoteDataSource.mediaBucket, old);
          } catch (_) {/* an orphaned old photo is harmless */}
        }
      });

  @override
  Future<Result<void>> submit(String listingId) =>
      _run(() => _remote.rpc('submit_health_profile', {'p_listing': listingId}));

  @override
  Future<Result<void>> setVisible(String listingId, bool visible) => _run(() =>
      _remote.rpc('set_health_profile_visible', {'p_listing': listingId, 'p_visible': visible}));

  @override
  Future<Result<void>> addCredential(
    String listingId,
    HealthCredentialDraft draft, {
    Uint8List? document,
    String? documentType,
  }) =>
      _run(() async {
        String? path;
        if (document != null) {
          final type = documentType ?? 'application/pdf';
          path = '$listingId/credential-${_uuid.v4()}.${_ext(type)}';
          await _remote.upload(HealthRemoteDataSource.documentBucket, path, document, type);
        }
        try {
          await _remote.insertCredential({
            'listing_id': listingId,
            ...HealthModels.credentialRow(draft),
            'document_path': path,
          });
        } catch (_) {
          if (path != null) await _remote.remove(HealthRemoteDataSource.documentBucket, path);
          rethrow;
        }
      });

  @override
  Future<Result<void>> deleteCredential(HealthCredential credential) => _run(() async {
        await _remote.deleteCredential(credential.id);
        final path = credential.documentPath;
        if (path != null) {
          try {
            await _remote.remove(HealthRemoteDataSource.documentBucket, path);
          } catch (_) {/* row is gone; the private file is unreachable */}
        }
      });
}
