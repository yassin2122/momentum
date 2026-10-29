/// Domain types for the Gym Partner Platform (CONNECT pillar).
///
/// Everything here mirrors what the gym or its visitors entered through
/// Grit (migration 20261029120000_gym_partner_platform). There is no
/// membership, attendance or payment data in this phase.
library;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Where a gym's public listing stands (`gym_listing_state`).
enum GymListingState {
  draft('draft', 'Draft'),
  pendingReview('pending_review', 'In review'),
  published('published', 'Published'),
  unpublished('unpublished', 'Unpublished'),
  suspended('suspended', 'Suspended');

  const GymListingState(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static GymListingState fromDb(String? v) => values.firstWhere(
        (s) => s.dbValue == v,
        orElse: () => GymListingState.draft,
      );

  bool get isLive => this == GymListingState.published;
  bool get isPublishedByOwner =>
      this == GymListingState.pendingReview || this == GymListingState.published;
}

/// A teammate's role at one gym. Rights are enforced by RLS; these getters
/// only decide which controls the app shows.
enum GymStaffRole {
  owner('owner', 'Owner', 'Everything, including the team'),
  manager('manager', 'Manager', 'Profile, branches, offers, coaches, inquiries'),
  marketing('marketing', 'Marketing', 'Profile, photos and offers'),
  frontDesk('front_desk', 'Front desk', 'Inquiries only');

  const GymStaffRole(this.dbValue, this.label, this.description);
  final String dbValue;
  final String label;
  final String description;

  static GymStaffRole fromDb(String? v) => values.firstWhere(
        (r) => r.dbValue == v,
        orElse: () => GymStaffRole.frontDesk,
      );

  bool get canEditProfile => this != GymStaffRole.frontDesk;
  bool get canManageBranches =>
      this == GymStaffRole.owner || this == GymStaffRole.manager;
  bool get canEditOffers => canEditProfile;
  bool get canManageCoaches => canManageBranches;
  bool get canSeeInquiries => this != GymStaffRole.marketing;
  bool get canPublish => canManageBranches;
  bool get canManageTeam => this == GymStaffRole.owner;
  bool get canSeePartnership => canManageBranches;
}

enum GymCoachRole {
  coach('coach', 'Coach'),
  headCoach('head_coach', 'Head coach');

  const GymCoachRole(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static GymCoachRole fromDb(String? v) =>
      v == 'head_coach' ? GymCoachRole.headCoach : GymCoachRole.coach;
}

enum GymInviteKind {
  gymInvite('gym_invite'),
  coachRequest('coach_request');

  const GymInviteKind(this.dbValue);
  final String dbValue;

  static GymInviteKind fromDb(String? v) =>
      v == 'coach_request' ? GymInviteKind.coachRequest : GymInviteKind.gymInvite;
}

enum GymInviteStatus {
  pending('pending', 'Pending'),
  accepted('accepted', 'Accepted'),
  declined('declined', 'Declined'),
  cancelled('cancelled', 'Cancelled'),
  expired('expired', 'Expired');

  const GymInviteStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static GymInviteStatus fromDb(String? v) => values.firstWhere(
        (s) => s.dbValue == v,
        orElse: () => GymInviteStatus.pending,
      );
}

enum GymPartnershipStatus {
  pendingReview('pending_review', 'In review'),
  active('active', 'Active'),
  suspended('suspended', 'Suspended'),
  expired('expired', 'Expired'),
  cancelled('cancelled', 'Cancelled');

  const GymPartnershipStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static GymPartnershipStatus fromDb(String? v) => values.firstWhere(
        (s) => s.dbValue == v,
        orElse: () => GymPartnershipStatus.pendingReview,
      );
}

enum GymInquiryStatus {
  fresh('new', 'New'),
  contacted('contacted', 'Contacted'),
  closed('closed', 'Closed');

  const GymInquiryStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static GymInquiryStatus fromDb(String? v) => values.firstWhere(
        (s) => s.dbValue == v,
        orElse: () => GymInquiryStatus.fresh,
      );

  /// The next step a staff member takes from this status.
  GymInquiryStatus get next => switch (this) {
        GymInquiryStatus.fresh => GymInquiryStatus.contacted,
        GymInquiryStatus.contacted => GymInquiryStatus.closed,
        GymInquiryStatus.closed => GymInquiryStatus.fresh,
      };
}

enum GymContactMethod {
  whatsapp('whatsapp', 'WhatsApp'),
  call('call', 'Call'),
  inApp('in_app', 'In Grit');

  const GymContactMethod(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static GymContactMethod fromDb(String? v) => values.firstWhere(
        (m) => m.dbValue == v,
        orElse: () => GymContactMethod.whatsapp,
      );
}

/// AI features a partnership can include. [available] is false for the ones
/// the app has no implementation of yet — the UI must say so.
enum GymAiFeature {
  planBuilder('ai_plan_builder', 'AI workout plan builder',
      'Drafts a program from a client’s goal, schedule and equipment'),
  progressSummary('ai_progress_summary', 'Progress summaries',
      'From Grit workouts the client chose to share'),
  workoutAdjustment('ai_workout_adjustment', 'Workout adjustments',
      'Suggests changes from recent sessions and goals'),
  coachingAssistant('ai_coaching_assistant', 'Coaching assistant',
      'Help with routine check-ins and replies');

  const GymAiFeature(this.dbValue, this.label, this.description);
  final String dbValue;
  final String label;
  final String description;

  static GymAiFeature? fromDb(String v) {
    for (final f in values) {
      if (f.dbValue == v) return f;
    }
    return null;
  }

  /// No AI service is connected to the app yet (no Edge Function / model
  /// provider). Flip per feature when its backend ships.
  bool get available => false;
}

// ---------------------------------------------------------------------------
// Public listing
// ---------------------------------------------------------------------------

/// One card in Find a gym (`get_gym_directory`).
final class GymDirectoryEntry {
  const GymDirectoryEntry({
    required this.gymId,
    required this.name,
    required this.facilities,
    required this.branchCount,
    required this.isPartner,
    this.headline,
    this.logoUrl,
    this.coverUrl,
    this.area,
    this.city,
    this.offersFrom,
    this.currency,
  });

  final String gymId;
  final String name;
  final String? headline;
  final String? logoUrl;
  final String? coverUrl;
  final String? area;
  final String? city;
  final List<String> facilities;
  final int branchCount;

  /// Lowest visible offer price the gym entered, if any.
  final double? offersFrom;
  final String? currency;
  final bool isPartner;

  String get locationLabel =>
      [if (area != null && area!.isNotEmpty) area!, if (city != null) city!]
          .join(', ');
}

/// Gym-level profile: listing fields + gym fields.
final class GymProfile {
  const GymProfile({
    required this.id,
    required this.listingId,
    required this.name,
    required this.isMultiBranch,
    required this.facilities,
    required this.equipment,
    required this.services,
    this.headline,
    this.description,
    this.logoUrl,
    this.coverPath,
    this.coverUrl,
    this.phone,
    this.whatsapp,
    this.email,
    this.website,
    this.address,
    this.area,
    this.city,
  });

  final String id;
  final String listingId;
  final String name;
  final String? headline;
  final String? description;
  final String? logoUrl;
  final String? coverPath;
  final String? coverUrl;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? website;
  final String? address;
  final String? area;
  final String? city;
  final bool isMultiBranch;
  final List<String> facilities;
  final List<String> equipment;
  final List<String> services;
}

/// One opening-hours rule, e.g. Sun–Thu 06:00–23:00.
final class GymHours {
  const GymHours({required this.days, required this.open, required this.close});

  /// 0 = Sunday … 6 = Saturday.
  final List<int> days;

  /// "HH:MM", 24-hour.
  final String open;
  final String close;

  static const _dayNames = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  String get label {
    final sorted = [...days]..sort();
    final String dayLabel;
    if (sorted.length == 7) {
      dayLabel = 'Every day';
    } else if (sorted.length > 2 &&
        sorted.last - sorted.first == sorted.length - 1) {
      dayLabel = '${_dayNames[sorted.first]}–${_dayNames[sorted.last]}';
    } else {
      dayLabel = sorted.map((d) => _dayNames[d % 7]).join(', ');
    }
    return '$dayLabel · $open–$close';
  }

  Map<String, dynamic> toJson() => {'days': days, 'open': open, 'close': close};
}

final class GymBranch {
  const GymBranch({
    required this.id,
    required this.gymId,
    required this.name,
    required this.city,
    required this.open24h,
    required this.hours,
    required this.facilities,
    required this.isPublished,
    this.address,
    this.area,
    this.phone,
    this.hoursNote,
  });

  final String id;
  final String gymId;
  final String name;
  final String? address;
  final String? area;
  final String city;
  final String? phone;
  final bool open24h;
  final List<GymHours> hours;
  final String? hoursNote;
  final List<String> facilities;
  final bool isPublished;

  bool get hasHours => open24h || hours.isNotEmpty;

  String get hoursLabel => open24h
      ? 'Open 24 hours'
      : hours.isEmpty
          ? 'Hours not set'
          : hours.map((h) => h.label).join('\n');

  String get addressLabel => [
        if (address != null && address!.isNotEmpty) address!,
        if (area != null && area!.isNotEmpty) area!,
        city,
      ].join(', ');
}

final class GymOffer {
  const GymOffer({
    required this.id,
    required this.gymId,
    required this.name,
    required this.currency,
    required this.benefits,
    required this.branchIds,
    required this.isVisible,
    this.priceAmount,
    this.durationDays,
    this.durationLabel,
  });

  final String id;
  final String gymId;
  final String name;

  /// Exactly as the gym entered it; null means "ask the gym".
  final double? priceAmount;
  final String currency;
  final int? durationDays;
  final String? durationLabel;
  final List<String> benefits;

  /// Empty = every branch.
  final List<String> branchIds;
  final bool isVisible;

  String get durationText {
    if (durationLabel != null && durationLabel!.isNotEmpty) {
      return durationLabel!;
    }
    final d = durationDays;
    if (d == null) return '';
    if (d == 1) return '1 day';
    if (d % 30 == 0) {
      final m = d ~/ 30;
      return m == 1 ? '1 month' : '$m months';
    }
    return '$d days';
  }

  bool appliesTo(String branchId) =>
      branchIds.isEmpty || branchIds.contains(branchId);
}

final class GymPhoto {
  const GymPhoto({required this.id, required this.storagePath, required this.url});

  final String id;
  final String storagePath;
  final String url;
}

/// A coach listed on a gym's public page.
final class GymPublicCoach {
  const GymPublicCoach({
    required this.coachId,
    required this.name,
    required this.role,
    this.avatarUrl,
    this.headline,
  });

  final String coachId;
  final String name;
  final String? avatarUrl;
  final String? headline;
  final GymCoachRole role;
}

/// Everything the public gym page shows.
final class GymPublicDetail {
  const GymPublicDetail({
    required this.profile,
    required this.branches,
    required this.offers,
    required this.photos,
    required this.coaches,
  });

  final GymProfile profile;
  final List<GymBranch> branches;
  final List<GymOffer> offers;
  final List<GymPhoto> photos;
  final List<GymPublicCoach> coaches;
}

// ---------------------------------------------------------------------------
// Gym admin
// ---------------------------------------------------------------------------

/// A gym the signed-in user works at (`get_my_gyms`).
final class MyGym {
  const MyGym({
    required this.gymId,
    required this.name,
    required this.role,
    this.logoUrl,
  });

  final String gymId;
  final String name;
  final String? logoUrl;
  final GymStaffRole role;
}

final class GymPartnership {
  const GymPartnership({
    required this.id,
    required this.status,
    required this.monthlyAllowance,
    required this.features,
    required this.usedThisMonth,
    this.perCoachCap,
    this.startsOn,
    this.endsOn,
  });

  final String id;
  final GymPartnershipStatus status;
  final DateTime? startsOn;
  final DateTime? endsOn;
  final int monthlyAllowance;
  final int? perCoachCap;
  final List<GymAiFeature> features;
  final int usedThisMonth;

  bool get isActive => status == GymPartnershipStatus.active;

  double get usedFraction => monthlyAllowance == 0
      ? 0
      : (usedThisMonth / monthlyAllowance).clamp(0, 1).toDouble();
}

final class GymDayViews {
  const GymDayViews({required this.day, required this.views});
  final DateTime day;
  final int views;
}

/// `get_gym_admin_overview` — counts only.
final class GymAdminOverview {
  const GymAdminOverview({
    required this.gymId,
    required this.name,
    required this.role,
    required this.listingState,
    required this.branchCount,
    required this.offerCount,
    required this.photoCount,
    required this.hasDescription,
    required this.hasCover,
    required this.staffCount,
    required this.coachCount,
    required this.pendingInvites,
    required this.views30d,
    required this.views14d,
    this.logoUrl,
    this.newInquiries,
    this.inquiriesThisMonth,
    this.partnership,
  });

  final String gymId;
  final String name;
  final String? logoUrl;
  final GymStaffRole role;
  final GymListingState listingState;
  final int branchCount;
  final int offerCount;
  final int photoCount;
  final bool hasDescription;
  final bool hasCover;
  final int staffCount;
  final int coachCount;
  final int pendingInvites;
  final int views30d;
  final List<GymDayViews> views14d;

  /// Null when the role can't see inquiries.
  final int? newInquiries;
  final int? inquiriesThisMonth;
  final GymPartnership? partnership;

  /// Setup checklist: (label, done).
  List<(String, bool)> get checklist => [
        ('Add a description', hasDescription),
        ('Add a cover photo', hasCover),
        ('Add a branch with opening hours', branchCount > 0),
        ('Add at least 3 gallery photos', photoCount >= 3),
        ('Add a public offer', offerCount > 0),
        ('Invite your coaches', coachCount > 0 || pendingInvites > 0),
      ];
}

/// Everything the admin profile editor needs (all rows, incl. hidden ones).
final class GymAdminDetail {
  const GymAdminDetail({
    required this.profile,
    required this.branches,
    required this.offers,
    required this.photos,
  });

  final GymProfile profile;
  final List<GymBranch> branches;
  final List<GymOffer> offers;
  final List<GymPhoto> photos;
}

final class GymCoachAffiliation {
  const GymCoachAffiliation({
    required this.id,
    required this.coachId,
    required this.name,
    required this.role,
    required this.branchIds,
    required this.startedAt,
    required this.aiUsedThisMonth,
    this.avatarUrl,
  });

  final String id;
  final String coachId;
  final String name;
  final String? avatarUrl;
  final GymCoachRole role;
  final List<String> branchIds;
  final DateTime startedAt;
  final int aiUsedThisMonth;
}

final class GymCoachInvitation {
  const GymCoachInvitation({
    required this.id,
    required this.kind,
    required this.coachId,
    required this.name,
    required this.role,
    required this.status,
    required this.createdAt,
    required this.expiresAt,
    this.avatarUrl,
    this.respondedAt,
  });

  final String id;
  final GymInviteKind kind;
  final String coachId;
  final String name;
  final String? avatarUrl;
  final GymCoachRole role;
  final GymInviteStatus status;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime? respondedAt;
}

final class GymCoachesAdmin {
  const GymCoachesAdmin({
    required this.coaches,
    required this.invitations,
    this.codeHint,
    this.codeExpiresAt,
  });

  final List<GymCoachAffiliation> coaches;
  final List<GymCoachInvitation> invitations;

  /// Last 4 characters of the current coach code, if one is active.
  final String? codeHint;
  final DateTime? codeExpiresAt;

  bool get hasActiveCode =>
      codeHint != null &&
      codeExpiresAt != null &&
      codeExpiresAt!.isAfter(DateTime.now());
}

final class GymInquiry {
  const GymInquiry({
    required this.id,
    required this.gymId,
    required this.name,
    required this.contactMethod,
    required this.status,
    required this.createdAt,
    this.branchId,
    this.offerId,
    this.phone,
    this.message,
  });

  final String id;
  final String gymId;
  final String? branchId;
  final String? offerId;
  final String name;
  final String? phone;
  final GymContactMethod contactMethod;
  final String? message;
  final GymInquiryStatus status;
  final DateTime createdAt;
}

final class GymStaffMember {
  const GymStaffMember({
    required this.userId,
    required this.name,
    required this.role,
    this.avatarUrl,
  });

  final String userId;
  final String name;
  final String? avatarUrl;
  final GymStaffRole role;
}

/// A code returned once by an RPC (coach code / staff code).
final class GymCode {
  const GymCode({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
}

// ---------------------------------------------------------------------------
// Coach side
// ---------------------------------------------------------------------------

final class CoachGymInvitation {
  const CoachGymInvitation({
    required this.id,
    required this.kind,
    required this.gymId,
    required this.gymName,
    required this.role,
    required this.branchNames,
    required this.createdAt,
    required this.expiresAt,
    this.logoUrl,
    this.message,
    this.invitedBy,
  });

  final String id;
  final GymInviteKind kind;
  final String gymId;
  final String gymName;
  final String? logoUrl;
  final GymCoachRole role;
  final String? message;
  final List<String> branchNames;
  final String? invitedBy;
  final DateTime createdAt;
  final DateTime expiresAt;

  /// A request the coach sent with a gym code, waiting on the gym.
  bool get isMyRequest => kind == GymInviteKind.coachRequest;
}

final class CoachGymAffiliation {
  const CoachGymAffiliation({
    required this.id,
    required this.gymId,
    required this.gymName,
    required this.role,
    required this.startedAt,
    this.logoUrl,
  });

  final String id;
  final String gymId;
  final String gymName;
  final String? logoUrl;
  final GymCoachRole role;
  final DateTime startedAt;
}

final class MyGymAffiliations {
  const MyGymAffiliations({required this.affiliations, required this.invitations});

  final List<CoachGymAffiliation> affiliations;
  final List<CoachGymInvitation> invitations;
}

/// `get_my_ai_entitlement` — AI the coach gets through a gym partnership.
final class AiEntitlement {
  const AiEntitlement({
    required this.eligible,
    this.gymName,
    this.features = const [],
    this.monthlyAllowance = 0,
    this.gymUsed = 0,
    this.perCoachCap,
    this.myUsed = 0,
    this.resetsOn,
  });

  static const none = AiEntitlement(eligible: false);

  final bool eligible;
  final String? gymName;
  final List<GymAiFeature> features;
  final int monthlyAllowance;
  final int gymUsed;
  final int? perCoachCap;
  final int myUsed;
  final DateTime? resetsOn;

  /// What this coach can still use this month (gym pool and own cap).
  int get remaining {
    final gymLeft = monthlyAllowance - gymUsed;
    final cap = perCoachCap;
    final mine = cap == null ? gymLeft : cap - myUsed;
    final left = gymLeft < mine ? gymLeft : mine;
    return left < 0 ? 0 : left;
  }

  int get myLimit => perCoachCap ?? monthlyAllowance;
}

// ---------------------------------------------------------------------------
// Drafts (what the editors send)
// ---------------------------------------------------------------------------

final class GymBranchDraft {
  const GymBranchDraft({
    required this.name,
    required this.city,
    required this.open24h,
    required this.hours,
    required this.facilities,
    required this.isPublished,
    this.address,
    this.area,
    this.phone,
  });

  final String name;
  final String? address;
  final String? area;
  final String city;
  final String? phone;
  final bool open24h;
  final List<GymHours> hours;
  final List<String> facilities;
  final bool isPublished;
}

final class GymOfferDraft {
  const GymOfferDraft({
    required this.name,
    required this.benefits,
    required this.branchIds,
    required this.isVisible,
    this.priceAmount,
    this.durationDays,
  });

  final String name;
  final double? priceAmount;
  final int? durationDays;
  final List<String> benefits;
  final List<String> branchIds;
  final bool isVisible;
}

/// Profile fields the editor changes. Null = leave unchanged; empty string
/// clears an optional text field.
final class GymProfilePatch {
  const GymProfilePatch({
    this.name,
    this.headline,
    this.description,
    this.phone,
    this.whatsapp,
    this.email,
    this.website,
    this.address,
    this.area,
    this.city,
    this.facilities,
    this.equipment,
    this.services,
  });

  final String? name;
  final String? headline;
  final String? description;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? website;
  final String? address;
  final String? area;
  final String? city;
  final List<String>? facilities;
  final List<String>? equipment;
  final List<String>? services;

  /// Name or contact changes send an approved listing back to Grit's review
  /// (guard_marketplace_listing).
  bool get triggersReview =>
      name != null ||
      phone != null ||
      whatsapp != null ||
      email != null ||
      website != null;
}
