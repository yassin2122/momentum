import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/gym_entities.dart';

/// Contract for the Gym Partner Platform. Reads go through RLS; lifecycle
/// changes (create, publish, invitations, staff, inquiries) go through
/// `security definer` RPCs. Partnership status and AI allowances have no
/// write method at all — only Grit admins change them.
abstract interface class GymRepository {
  // ---- Public ----

  Future<Result<List<GymDirectoryEntry>>> getDirectory({
    String? search,
    String? facility,
  });

  /// Profile + published branches + visible offers + photos + coaches of a
  /// listed gym. Also counts one profile view (once per day per viewer).
  Future<Result<GymPublicDetail>> getPublicGym(String gymId);

  Future<Result<String>> submitInquiry({
    required String gymId,
    required String name,
    required GymContactMethod contactMethod,
    String? phone,
    String? message,
    String? branchId,
    String? offerId,
  });

  // ---- Owner / staff ----

  Future<Result<List<MyGym>>> getMyGyms();

  /// Creates the gym as a private draft and makes the caller its owner.
  Future<Result<String>> createGym({
    required String name,
    required String city,
    required String phone,
    String? email,
    required bool multiBranch,
  });

  Future<Result<GymAdminOverview>> getOverview(String gymId);

  /// All branches/offers (hidden ones too) + photos, for the editors.
  Future<Result<GymAdminDetail>> getAdminDetail(String gymId);

  Future<Result<void>> updateProfile(GymProfile current, GymProfilePatch patch);

  /// Publish / unpublish; returns the new listing state.
  Future<Result<GymListingState>> setPublished(String gymId, bool publish);

  Future<Result<void>> saveBranch(String gymId, GymBranchDraft draft,
      {String? branchId});

  Future<Result<void>> deleteBranch(String branchId);

  Future<Result<void>> saveOffer(String gymId, GymOfferDraft draft,
      {String? offerId});

  Future<Result<void>> setOfferVisible(String offerId, bool visible);

  Future<Result<void>> deleteOffer(String offerId);

  /// Uploads to `gym-media/<gymId>/…` and records a gallery photo.
  Future<Result<void>> addPhoto(String gymId, Uint8List bytes, String contentType);

  Future<Result<void>> deletePhoto(GymPhoto photo);

  Future<Result<void>> setCover(
      GymProfile profile, Uint8List bytes, String contentType);

  Future<Result<void>> setLogo(
      GymProfile profile, Uint8List bytes, String contentType);

  // ---- Coaches ----

  Future<Result<GymCoachesAdmin>> getCoachesAdmin(String gymId);

  /// Invites an approved Grit coach by the email on their account.
  Future<Result<void>> inviteCoach({
    required String gymId,
    required String email,
    required GymCoachRole role,
    required List<String> branchIds,
    String? message,
  });

  /// New 7-day coach code; the full code is returned only here.
  Future<Result<GymCode>> rotateCoachCode(String gymId);

  Future<Result<void>> respondToInvitation(String invitationId,
      {required bool accept});

  Future<Result<void>> cancelInvitation(String invitationId);

  Future<Result<void>> endAffiliation(String affiliationId);

  // ---- Inquiries ----

  Future<Result<List<GymInquiry>>> getInquiries(String gymId);

  Future<Result<void>> setInquiryStatus(String inquiryId, GymInquiryStatus status);

  // ---- Team & partnership ----

  Future<Result<List<GymStaffMember>>> getStaff(String gymId);

  Future<Result<GymCode>> createStaffInvite(String gymId, GymStaffRole role);

  Future<Result<String>> acceptStaffInvite(String code);

  Future<Result<void>> setStaffRole(String gymId, String userId, GymStaffRole role);

  Future<Result<void>> removeStaff(String gymId, String userId);

  Future<Result<void>> requestPartnership(String gymId);

  // ---- Coach side ----

  Future<Result<MyGymAffiliations>> getMyAffiliations();

  /// Ask to join a gym with its coach code; the gym approves.
  Future<Result<void>> requestAffiliation(String code);

  Future<Result<AiEntitlement>> getMyAiEntitlement();
}
