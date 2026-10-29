import 'dart:typed_data';

import 'package:uuid/uuid.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/gym_entities.dart';
import '../../domain/repositories/gym_repository.dart';
import '../datasources/gym_remote_datasource.dart';
import '../models/gym_models.dart';

/// [GymRepository] over [GymRemoteDataSource]. Catches datasource
/// exceptions and returns typed failures; database messages from the RPCs
/// are already written for people ("Add a cover photo before publishing"),
/// so they are passed through as-is.
class GymRepositoryImpl implements GymRepository {
  const GymRepositoryImpl(this._remote);

  final GymRemoteDataSource _remote;

  static const _uuid = Uuid();

  // ---- helpers ----

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

  /// Turns the few raw Postgres messages people can hit into plain words.
  static String _friendly(String message) {
    if (message.contains('violates check constraint "branch_published_has_hours"')) {
      return 'Add opening hours (or turn on Open 24 hours) before showing this branch.';
    }
    if (message.contains('listing_has_contact')) {
      return 'Keep at least one way to contact your gym: phone, WhatsApp, email or website.';
    }
    if (message.contains('violates check constraint')) {
      return 'Some details aren\'t in the right format. Check the fields and try again.';
    }
    if (message.contains('row-level security')) {
      return 'Your role at this gym can\'t make that change.';
    }
    return message;
  }

  static String _extension(String contentType) => switch (contentType) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        _ => 'jpg',
      };

  String _newPath(String gymId, String kind, String contentType) =>
      '$gymId/$kind-${_uuid.v4()}.${_extension(contentType)}';

  // ---- Public ----

  @override
  Future<Result<List<GymDirectoryEntry>>> getDirectory({
    String? search,
    String? facility,
  }) =>
      _run(() async => [
            for (final r in await _remote.directory(
                search: search?.trim(), facility: facility))
              GymModels.directoryEntry(r, _remote.publicUrl),
          ]);

  @override
  Future<Result<GymPublicDetail>> getPublicGym(String gymId) => _run(() async {
        final (gym, branches, offers, photos, coaches) = await (
          _remote.gym(gymId),
          _remote.branches(gymId),
          _remote.offers(gymId),
          _remote.photos(gymId),
          _remote.publicCoaches(gymId),
        ).wait;
        if (gym == null) {
          throw const ServerException('This gym isn\'t on Grit right now.');
        }
        // A view that fails to count must never block the page.
        _remote.recordView(gymId).ignore();
        return GymPublicDetail(
          profile: GymModels.profile(gym, _remote.publicUrl),
          branches: [for (final b in branches) GymModels.branch(b)],
          offers: [for (final o in offers) GymModels.offer(o)],
          photos: [for (final p in photos) GymModels.photo(p, _remote.publicUrl)],
          coaches: [for (final c in coaches) GymModels.publicCoach(c)],
        );
      });

  @override
  Future<Result<String>> submitInquiry({
    required String gymId,
    required String name,
    required GymContactMethod contactMethod,
    String? phone,
    String? message,
    String? branchId,
    String? offerId,
  }) =>
      _run(() => _remote.submitInquiry({
            'p_gym': gymId,
            'p_name': name.trim(),
            'p_phone': phone?.trim(),
            'p_contact_method': contactMethod.dbValue,
            'p_message': message?.trim(),
            'p_branch': branchId,
            'p_offer': offerId,
          }));

  // ---- Owner / staff ----

  @override
  Future<Result<List<MyGym>>> getMyGyms() => _run(
      () async => [for (final r in await _remote.myGyms()) GymModels.myGym(r)]);

  @override
  Future<Result<String>> createGym({
    required String name,
    required String city,
    required String phone,
    String? email,
    required bool multiBranch,
  }) =>
      _run(() async => (await _remote.rpc('create_gym', {
            'p_name': name.trim(),
            'p_city': city.trim(),
            'p_phone': phone.trim(),
            'p_email': email?.trim(),
            'p_multi_branch': multiBranch,
          })) as String);

  @override
  Future<Result<GymAdminOverview>> getOverview(String gymId) =>
      _run(() async => GymModels.overview(await _remote.overview(gymId)));

  @override
  Future<Result<GymAdminDetail>> getAdminDetail(String gymId) =>
      _run(() async {
        final (gym, branches, offers, photos) = await (
          _remote.gym(gymId),
          _remote.branches(gymId),
          _remote.offers(gymId),
          _remote.photos(gymId),
        ).wait;
        if (gym == null) throw const ServerException('Gym not found.');
        return GymAdminDetail(
          profile: GymModels.profile(gym, _remote.publicUrl),
          branches: [for (final b in branches) GymModels.branch(b)],
          offers: [for (final o in offers) GymModels.offer(o)],
          photos: [for (final p in photos) GymModels.photo(p, _remote.publicUrl)],
        );
      });

  @override
  Future<Result<void>> updateProfile(GymProfile current, GymProfilePatch patch) =>
      _run(() async {
        final (listing, gym) = GymModels.patchRows(patch);
        await _remote.updateListing(current.listingId, listing);
        await _remote.updateGym(current.id, gym);
      });

  @override
  Future<Result<GymListingState>> setPublished(String gymId, bool publish) =>
      _run(() async => GymListingState.fromDb((await _remote.rpc(
            'set_gym_published',
            {'p_gym': gymId, 'p_publish': publish},
          )) as String?));

  @override
  Future<Result<void>> saveBranch(String gymId, GymBranchDraft draft,
          {String? branchId}) =>
      _run(() async {
        final row = GymModels.branchRow(draft);
        if (branchId == null) {
          await _remote.insertBranch({...row, 'gym_id': gymId});
        } else {
          await _remote.updateBranch(branchId, row);
        }
      });

  @override
  Future<Result<void>> deleteBranch(String branchId) => _run(() =>
      _remote.updateBranch(branchId, {
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'is_published': false,
      }));

  @override
  Future<Result<void>> saveOffer(String gymId, GymOfferDraft draft,
          {String? offerId}) =>
      _run(() async {
        final row = GymModels.offerRow(draft);
        if (offerId == null) {
          await _remote.insertOffer({...row, 'gym_id': gymId});
        } else {
          await _remote.updateOffer(offerId, row);
        }
      });

  @override
  Future<Result<void>> setOfferVisible(String offerId, bool visible) =>
      _run(() => _remote.updateOffer(offerId, {'is_visible': visible}));

  @override
  Future<Result<void>> deleteOffer(String offerId) => _run(() =>
      _remote.updateOffer(offerId, {
        'deleted_at': DateTime.now().toUtc().toIso8601String(),
        'is_visible': false,
      }));

  @override
  Future<Result<void>> addPhoto(
          String gymId, Uint8List bytes, String contentType) =>
      _run(() async {
        final path = _newPath(gymId, 'photo', contentType);
        await _remote.uploadMedia(path, bytes, contentType);
        try {
          await _remote.insertPhoto({'gym_id': gymId, 'storage_path': path});
        } catch (_) {
          // Don't leave an orphaned file behind (e.g. the 12-photo cap).
          await _remote.removeMedia(path).catchError((_) {});
          rethrow;
        }
      });

  @override
  Future<Result<void>> deletePhoto(GymPhoto photo) => _run(() async {
        await _remote.deletePhoto(photo.id);
        await _remote.removeMedia(photo.storagePath).catchError((_) {});
      });

  @override
  Future<Result<void>> setCover(
          GymProfile profile, Uint8List bytes, String contentType) =>
      _run(() async {
        final path = _newPath(profile.id, 'cover', contentType);
        await _remote.uploadMedia(path, bytes, contentType);
        await _remote.updateGym(profile.id, {'cover_path': path});
        final old = profile.coverPath;
        if (old != null) await _remote.removeMedia(old).catchError((_) {});
      });

  @override
  Future<Result<void>> setLogo(
          GymProfile profile, Uint8List bytes, String contentType) =>
      _run(() async {
        final path = _newPath(profile.id, 'logo', contentType);
        await _remote.uploadMedia(path, bytes, contentType);
        await _remote.updateListing(
            profile.listingId, {'logo_url': _remote.publicUrl(path)});
      });

  // ---- Coaches ----

  @override
  Future<Result<GymCoachesAdmin>> getCoachesAdmin(String gymId) => _run(
      () async => GymModels.coachesAdmin(await _remote.coachesAdmin(gymId)));

  @override
  Future<Result<void>> inviteCoach({
    required String gymId,
    required String email,
    required GymCoachRole role,
    required List<String> branchIds,
    String? message,
  }) =>
      _run(() => _remote.rpc('invite_gym_coach', {
            'p_gym': gymId,
            'p_email': email.trim(),
            'p_role': role.dbValue,
            'p_branch_ids': branchIds,
            'p_message': message?.trim(),
          }));

  @override
  Future<Result<GymCode>> rotateCoachCode(String gymId) => _run(() async {
        final rows =
            await _remote.rowsRpc('rotate_gym_coach_code', {'p_gym': gymId});
        if (rows.isEmpty) throw const ServerException('Couldn\'t create a code.');
        return GymModels.code(rows.first);
      });

  @override
  Future<Result<void>> respondToInvitation(String invitationId,
          {required bool accept}) =>
      _run(() => _remote.rpc('respond_gym_invitation',
          {'p_invitation': invitationId, 'p_accept': accept}));

  @override
  Future<Result<void>> cancelInvitation(String invitationId) => _run(() =>
      _remote.rpc('cancel_gym_invitation', {'p_invitation': invitationId}));

  @override
  Future<Result<void>> endAffiliation(String affiliationId) => _run(() =>
      _remote.rpc('end_gym_affiliation', {'p_affiliation': affiliationId}));

  // ---- Inquiries ----

  @override
  Future<Result<List<GymInquiry>>> getInquiries(String gymId) => _run(() async =>
      [for (final r in await _remote.inquiries(gymId)) GymModels.inquiry(r)]);

  @override
  Future<Result<void>> setInquiryStatus(
          String inquiryId, GymInquiryStatus status) =>
      _run(() => _remote.rpc('set_gym_inquiry_status',
          {'p_inquiry': inquiryId, 'p_status': status.dbValue}));

  // ---- Team & partnership ----

  @override
  Future<Result<List<GymStaffMember>>> getStaff(String gymId) => _run(() async =>
      [for (final r in await _remote.staff(gymId)) GymModels.staffMember(r)]);

  @override
  Future<Result<GymCode>> createStaffInvite(String gymId, GymStaffRole role) =>
      _run(() async {
        final rows = await _remote.rowsRpc('create_gym_staff_invite',
            {'p_gym': gymId, 'p_role': role.dbValue});
        if (rows.isEmpty) throw const ServerException('Couldn\'t create a code.');
        return GymModels.code(rows.first);
      });

  @override
  Future<Result<String>> acceptStaffInvite(String code) => _run(() async =>
      (await _remote.rpc('accept_gym_staff_invite', {'p_code': code.trim()}))
          as String);

  @override
  Future<Result<void>> setStaffRole(
          String gymId, String userId, GymStaffRole role) =>
      _run(() => _remote.rpc('set_gym_staff_role',
          {'p_gym': gymId, 'p_user': userId, 'p_role': role.dbValue}));

  @override
  Future<Result<void>> removeStaff(String gymId, String userId) => _run(() =>
      _remote.rpc('remove_gym_staff', {'p_gym': gymId, 'p_user': userId}));

  @override
  Future<Result<void>> requestPartnership(String gymId) =>
      _run(() => _remote.rpc('request_gym_partnership', {'p_gym': gymId}));

  // ---- Coach side ----

  @override
  Future<Result<MyGymAffiliations>> getMyAffiliations() => _run(() async =>
      GymModels.affiliations(Map<String, dynamic>.from(
          await _remote.rpc('get_my_gym_affiliations') as Map)));

  @override
  Future<Result<void>> requestAffiliation(String code) => _run(() =>
      _remote.rpc('request_gym_affiliation', {'p_code': code.trim()}));

  @override
  Future<Result<AiEntitlement>> getMyAiEntitlement() => _run(() async =>
      GymModels.entitlement(Map<String, dynamic>.from(
          await _remote.rpc('get_my_ai_entitlement') as Map)));
}
