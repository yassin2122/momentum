/// Domain types for the Doctors & Physiotherapists marketplace (CONNECT).
///
/// Discovery and contact only (migration 20261029140000_health_providers):
/// there are no appointments, slots, payments, consultations or medical
/// records anywhere in this feature. Everything shown is what the provider
/// entered, except `verified` flags, which only Grit sets.
library;

// ---------------------------------------------------------------------------
// Enums
// ---------------------------------------------------------------------------

/// Provider type (`marketplace_listings.provider_type`).
enum HealthKind {
  doctor('doctor', 'Doctor', 'Doctors'),
  physio('physical_therapist', 'Physiotherapist', 'Physiotherapists');

  const HealthKind(this.dbValue, this.label, this.plural);
  final String dbValue;
  final String label;
  final String plural;

  static HealthKind fromDb(String? v) =>
      v == 'physical_therapist' ? HealthKind.physio : HealthKind.doctor;
}

/// Where the provider sees people.
enum HealthServiceMode {
  clinic('clinic', 'Clinic visits'),
  home('home', 'Home visits');

  const HealthServiceMode(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static HealthServiceMode? fromDb(String v) {
    for (final m in values) {
      if (m.dbValue == v) return m;
    }
    return null;
  }
}

enum HealthCredentialKind {
  license('license', 'Practising licence'),
  degree('degree', 'Degree'),
  certification('certification', 'Certification'),
  membership('membership', 'Membership');

  const HealthCredentialKind(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static HealthCredentialKind fromDb(String? v) => values.firstWhere(
        (k) => k.dbValue == v,
        orElse: () => HealthCredentialKind.certification,
      );
}

/// Owner-side credential status. The public only ever sees verified vs
/// provider-submitted.
enum HealthCredentialStatus {
  submitted('submitted', 'Provider-submitted'),
  pending('pending', 'In review'),
  verified('verified', 'Verified'),
  rejected('rejected', 'Not verified');

  const HealthCredentialStatus(this.dbValue, this.label);
  final String dbValue;
  final String label;

  static HealthCredentialStatus fromDb(String? v) => values.firstWhere(
        (s) => s.dbValue == v,
        orElse: () => HealthCredentialStatus.submitted,
      );
}

/// Where the provider's own profile stands.
enum HealthProfileState {
  draft('Draft · not visible yet', 'Finish your profile and submit it for review.'),
  inReview('In review', 'Grit is checking your profile before it appears.'),
  live('Live', 'Athletes can find and contact you.'),
  hidden('Hidden', 'You hid your profile. Show it again any time.'),
  suspended('Suspended', 'Grit paused this profile. Contact Grit support.');

  const HealthProfileState(this.title, this.explainer);
  final String title;
  final String explainer;
}

// ---------------------------------------------------------------------------
// Public
// ---------------------------------------------------------------------------

/// One card in Find a health pro (`get_health_directory`).
final class HealthDirectoryEntry {
  const HealthDirectoryEntry({
    required this.listingId,
    required this.kind,
    required this.name,
    required this.specialties,
    required this.serviceModes,
    required this.licenseVerified,
    required this.isSaved,
    this.headline,
    this.photoUrl,
    this.area,
    this.city,
    this.consultationFee,
    this.feeCurrency = 'EGP',
  });

  final String listingId;
  final HealthKind kind;
  final String name;
  final String? headline;
  final List<String> specialties;
  final String? photoUrl;
  final String? area;
  final String? city;
  final List<HealthServiceMode> serviceModes;

  /// Exactly as the provider entered it; null = not listed.
  final double? consultationFee;
  final String feeCurrency;

  /// True only when Grit checked the practising licence.
  final bool licenseVerified;
  final bool isSaved;

  String get specialtyLabel =>
      specialties.isNotEmpty ? specialties.join(' · ') : (headline ?? kind.label);

  String get locationLabel => [
        if (area != null && area!.isNotEmpty) area!,
        if (city != null && city!.isNotEmpty) city!,
      ].join(', ');

  HealthDirectoryEntry copyWith({bool? isSaved}) => HealthDirectoryEntry(
        listingId: listingId,
        kind: kind,
        name: name,
        headline: headline,
        specialties: specialties,
        photoUrl: photoUrl,
        area: area,
        city: city,
        serviceModes: serviceModes,
        consultationFee: consultationFee,
        feeCurrency: feeCurrency,
        licenseVerified: licenseVerified,
        isSaved: isSaved ?? this.isSaved,
      );
}

/// A qualification as other users see it.
final class HealthPublicCredential {
  const HealthPublicCredential({
    required this.kind,
    required this.title,
    required this.verified,
    this.issuer,
    this.year,
    this.verifiedAt,
  });

  final HealthCredentialKind kind;
  final String title;
  final String? issuer;
  final int? year;
  final bool verified;
  final DateTime? verifiedAt;

  String get subtitle => [
        if (issuer != null && issuer!.isNotEmpty) issuer!,
        if (year != null) '$year',
      ].join(' · ');
}

/// A provider's public profile (`get_health_provider`). Phone / WhatsApp
/// are present only when the provider chose to show them.
final class HealthProviderDetail {
  const HealthProviderDetail({
    required this.listingId,
    required this.kind,
    required this.name,
    required this.specialties,
    required this.services,
    required this.languages,
    required this.serviceModes,
    required this.credentials,
    required this.phoneVerified,
    required this.isSaved,
    required this.isPreview,
    this.headline,
    this.description,
    this.photoUrl,
    this.phone,
    this.whatsapp,
    this.website,
    this.bookingUrl,
    this.address,
    this.area,
    this.city,
    this.latitude,
    this.longitude,
    this.clinicName,
    this.availabilityNote,
    this.consultationFee,
    this.feeCurrency = 'EGP',
    this.experienceYears,
  });

  final String listingId;
  final HealthKind kind;
  final String name;
  final String? headline;
  final String? description;
  final List<String> specialties;
  final String? photoUrl;
  final String? phone;
  final bool phoneVerified;
  final String? whatsapp;
  final String? website;
  final String? bookingUrl;
  final String? address;
  final String? area;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? clinicName;
  final String? availabilityNote;
  final double? consultationFee;
  final String feeCurrency;
  final List<String> services;
  final List<String> languages;
  final int? experienceYears;
  final List<HealthServiceMode> serviceModes;
  final List<HealthPublicCredential> credentials;
  final bool isSaved;

  /// The owner looking at their own profile before it's live.
  final bool isPreview;

  bool get licenseVerified => credentials
      .any((c) => c.verified && c.kind == HealthCredentialKind.license);

  bool get hasLocation =>
      (latitude != null && longitude != null) ||
      (address != null && address!.isNotEmpty) ||
      (city != null && city!.isNotEmpty);

  String get addressLabel => [
        if (address != null && address!.isNotEmpty) address!,
        if (area != null && area!.isNotEmpty) area!,
        if (city != null && city!.isNotEmpty) city!,
      ].join(', ');

  bool get hasAnyContact =>
      phone != null || whatsapp != null || website != null || bookingUrl != null || hasLocation;
}

// ---------------------------------------------------------------------------
// Provider (owner) side
// ---------------------------------------------------------------------------

final class HealthCredential {
  const HealthCredential({
    required this.id,
    required this.kind,
    required this.title,
    required this.status,
    this.issuer,
    this.year,
    this.documentPath,
    this.reviewNote,
  });

  final String id;
  final HealthCredentialKind kind;
  final String title;
  final String? issuer;
  final int? year;
  final String? documentPath;
  final HealthCredentialStatus status;
  final String? reviewNote;

  String get subtitle => [
        if (issuer != null && issuer!.isNotEmpty) issuer!,
        if (year != null) '$year',
        if (documentPath == null) 'no document',
      ].join(' · ');
}

/// Everything the owner's editor needs: listing + health profile + all
/// credentials.
final class MyHealthProfile {
  const MyHealthProfile({
    required this.listingId,
    required this.kind,
    required this.name,
    required this.specialties,
    required this.status,
    required this.isPublished,
    required this.services,
    required this.languages,
    required this.serviceModes,
    required this.showPhone,
    required this.showWhatsapp,
    required this.phoneVerified,
    required this.credentials,
    this.headline,
    this.description,
    this.photoUrl,
    this.photoPath,
    this.phone,
    this.whatsapp,
    this.email,
    this.website,
    this.bookingUrl,
    this.address,
    this.area,
    this.city,
    this.latitude,
    this.longitude,
    this.clinicName,
    this.availabilityNote,
    this.consultationFee,
    this.feeCurrency = 'EGP',
    this.experienceYears,
    this.submittedAt,
  });

  final String listingId;
  final HealthKind kind;
  final String name;
  final String? headline;
  final String? description;
  final List<String> specialties;
  final String? photoUrl;
  final String? photoPath;
  final String? phone;
  final String? whatsapp;
  final String? email;
  final String? website;
  final String? bookingUrl;
  final String? address;
  final String? area;
  final String? city;
  final double? latitude;
  final double? longitude;
  final String? clinicName;
  final String? availabilityNote;
  final double? consultationFee;
  final String feeCurrency;
  final int? experienceYears;
  final List<String> services;
  final List<String> languages;
  final List<HealthServiceMode> serviceModes;
  final bool showPhone;
  final bool showWhatsapp;
  final bool phoneVerified;
  final List<HealthCredential> credentials;

  /// `marketplace_listings.status`: pending / approved / suspended.
  final String status;
  final bool isPublished;
  final DateTime? submittedAt;

  HealthProfileState get state {
    if (status == 'suspended') return HealthProfileState.suspended;
    if (submittedAt == null) return HealthProfileState.draft;
    if (!isPublished) return HealthProfileState.hidden;
    if (status == 'approved') return HealthProfileState.live;
    return HealthProfileState.inReview;
  }

  /// What still blocks "Submit for review" (mirrors submit_health_profile).
  List<String> get missing => [
        if ((headline ?? '').trim().length < 3) 'Professional title',
        if ((description ?? '').trim().length < 40) 'Biography (40+ characters)',
        if (specialties.isEmpty) 'At least one specialty',
        if (!((showPhone && phone != null) ||
            (showWhatsapp && whatsapp != null) ||
            website != null ||
            bookingUrl != null))
          'A public way to reach you',
      ];
}

/// Fields the editor changes. Null = unchanged; empty string clears an
/// optional text field.
final class HealthProfilePatch {
  const HealthProfilePatch({
    this.name,
    this.headline,
    this.description,
    this.specialties,
    this.phone,
    this.whatsapp,
    this.website,
    this.address,
    this.area,
    this.city,
    this.clinicName,
    this.availabilityNote,
    this.consultationFee,
    this.clearFee = false,
    this.experienceYears,
    this.clearExperience = false,
    this.services,
    this.languages,
    this.serviceModes,
    this.bookingUrl,
    this.showPhone,
    this.showWhatsapp,
  });

  final String? name;
  final String? headline;
  final String? description;
  final List<String>? specialties;
  final String? phone;
  final String? whatsapp;
  final String? website;
  final String? address;
  final String? area;
  final String? city;
  final String? clinicName;
  final String? availabilityNote;
  final double? consultationFee;
  final bool clearFee;
  final int? experienceYears;
  final bool clearExperience;
  final List<String>? services;
  final List<String>? languages;
  final List<HealthServiceMode>? serviceModes;
  final String? bookingUrl;
  final bool? showPhone;
  final bool? showWhatsapp;

  /// Name or contact changes send an approved profile back to review.
  bool get triggersReview =>
      name != null || phone != null || whatsapp != null || website != null;
}

final class HealthCredentialDraft {
  const HealthCredentialDraft({
    required this.kind,
    required this.title,
    this.issuer,
    this.year,
  });

  final HealthCredentialKind kind;
  final String title;
  final String? issuer;
  final int? year;
}
