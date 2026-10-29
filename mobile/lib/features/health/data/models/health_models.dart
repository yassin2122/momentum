import '../../domain/entities/health_entities.dart';

/// Parses rows / jsonb from the health RPCs and builds update rows.
abstract final class HealthModels {
  static String _s(Object? v) => v?.toString() ?? '';
  static String? _ns(Object? v) {
    final s = v?.toString().trim();
    return s == null || s.isEmpty ? null : s;
  }

  static int? _ni(Object? v) =>
      v is num ? v.toInt() : (v == null ? null : int.tryParse('$v'));
  static double? _nd(Object? v) =>
      v is num ? v.toDouble() : (v == null ? null : double.tryParse('$v'));
  static bool _b(Object? v) => v == true;
  static DateTime? _ndt(Object? v) =>
      v == null ? null : DateTime.tryParse('$v')?.toLocal();
  static List<String> _strings(Object? v) =>
      v is List ? [for (final x in v) if (x != null && '$x'.trim().isNotEmpty) '$x'] : const [];
  static List<Map<String, dynamic>> _maps(Object? v) => v is List
      ? [for (final x in v) if (x is Map) Map<String, dynamic>.from(x)]
      : const [];
  static List<HealthServiceMode> _modes(Object? v) => [
        for (final m in _strings(v))
          if (HealthServiceMode.fromDb(m) case final HealthServiceMode mode) mode,
      ];

  // ---- public ----

  static HealthDirectoryEntry entry(Map<String, dynamic> r) => HealthDirectoryEntry(
        listingId: _s(r['listing_id']),
        kind: HealthKind.fromDb(_ns(r['kind'])),
        name: _s(r['name']),
        headline: _ns(r['headline']),
        specialties: _strings(r['specialties']),
        photoUrl: _ns(r['photo_url']),
        area: _ns(r['area']),
        city: _ns(r['city']),
        serviceModes: _modes(r['service_modes']),
        consultationFee: _nd(r['consultation_fee']),
        feeCurrency: _ns(r['fee_currency']) ?? 'EGP',
        licenseVerified: _b(r['license_verified']),
        isSaved: _b(r['is_saved']),
      );

  static HealthProviderDetail detail(Map<String, dynamic> r) => HealthProviderDetail(
        listingId: _s(r['listing_id']),
        kind: HealthKind.fromDb(_ns(r['kind'])),
        name: _s(r['name']),
        headline: _ns(r['headline']),
        description: _ns(r['description']),
        specialties: _strings(r['specialties']),
        photoUrl: _ns(r['photo_url']),
        phone: _ns(r['phone']),
        phoneVerified: _b(r['phone_verified']),
        whatsapp: _ns(r['whatsapp']),
        website: _ns(r['website']),
        bookingUrl: _ns(r['booking_url']),
        address: _ns(r['address']),
        area: _ns(r['area']),
        city: _ns(r['city']),
        latitude: _nd(r['latitude']),
        longitude: _nd(r['longitude']),
        clinicName: _ns(r['clinic_name']),
        availabilityNote: _ns(r['availability_note']),
        consultationFee: _nd(r['consultation_fee']),
        feeCurrency: _ns(r['fee_currency']) ?? 'EGP',
        services: _strings(r['services']),
        languages: _strings(r['languages']),
        experienceYears: _ni(r['experience_years']),
        serviceModes: _modes(r['service_modes']),
        isSaved: _b(r['is_saved']),
        isPreview: _b(r['is_preview']),
        credentials: [
          for (final c in _maps(r['credentials']))
            HealthPublicCredential(
              kind: HealthCredentialKind.fromDb(_ns(c['kind'])),
              title: _s(c['title']),
              issuer: _ns(c['issuer']),
              year: _ni(c['year']),
              verified: _b(c['verified']),
              verifiedAt: _ndt(c['verified_at']),
            ),
        ],
      );

  // ---- owner ----

  static HealthCredential credential(Map<String, dynamic> r) => HealthCredential(
        id: _s(r['id']),
        kind: HealthCredentialKind.fromDb(_ns(r['kind'])),
        title: _s(r['title']),
        issuer: _ns(r['issuer']),
        year: _ni(r['year']),
        documentPath: _ns(r['document_path']),
        status: HealthCredentialStatus.fromDb(_ns(r['status'])),
        reviewNote: _ns(r['review_note']),
      );

  /// [listing] = marketplace_listings row embedding `health_profiles(...)`.
  static MyHealthProfile mine(
    Map<String, dynamic> listing,
    List<Map<String, dynamic>> credentials,
  ) {
    final hp = listing['health_profiles'];
    final h = hp is Map
        ? Map<String, dynamic>.from(hp)
        : (hp is List && hp.isNotEmpty ? Map<String, dynamic>.from(hp.first as Map) : <String, dynamic>{});
    return MyHealthProfile(
      listingId: _s(listing['id']),
      kind: HealthKind.fromDb(_ns(listing['provider_type'])),
      name: _s(listing['name']),
      headline: _ns(listing['headline']),
      description: _ns(listing['description']),
      specialties: _strings(listing['specialties']),
      photoUrl: _ns(listing['logo_url']),
      photoPath: _ns(h['photo_path']),
      phone: _ns(listing['phone']),
      whatsapp: _ns(listing['whatsapp']),
      email: _ns(listing['email']),
      website: _ns(listing['website']),
      address: _ns(listing['address']),
      area: _ns(listing['area']),
      city: _ns(listing['city']),
      latitude: _nd(listing['latitude']),
      longitude: _nd(listing['longitude']),
      status: _ns(listing['status']) ?? 'pending',
      isPublished: _b(listing['is_published']),
      clinicName: _ns(h['clinic_name']),
      availabilityNote: _ns(h['availability_note']),
      consultationFee: _nd(h['consultation_fee']),
      feeCurrency: _ns(h['fee_currency']) ?? 'EGP',
      experienceYears: _ni(h['experience_years']),
      services: _strings(h['services']),
      languages: _strings(h['languages']),
      serviceModes: _modes(h['service_modes']),
      bookingUrl: _ns(h['booking_url']),
      showPhone: _b(h['show_phone']),
      showWhatsapp: _b(h['show_whatsapp']),
      phoneVerified: h['phone_verified_at'] != null,
      submittedAt: _ndt(h['submitted_at']),
      credentials: [for (final c in credentials) credential(c)],
    );
  }

  // ---- writes ----

  static String? _clean(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  /// Website / booking links must be https; add it when people type a bare
  /// domain.
  static String? normalizeUrl(String? v) {
    final t = _clean(v);
    if (t == null) return null;
    if (t.startsWith('https://')) return t;
    if (t.startsWith('http://')) return 'https://${t.substring(7)}';
    return 'https://$t';
  }

  /// Splits a patch into marketplace_listings and health_profiles columns.
  static (Map<String, dynamic>, Map<String, dynamic>) patchRows(HealthProfilePatch p) {
    final listing = <String, dynamic>{
      if (p.name != null) 'name': p.name!.trim(),
      if (p.headline != null) 'headline': _clean(p.headline),
      if (p.description != null) 'description': _clean(p.description),
      if (p.specialties != null) 'specialties': p.specialties,
      if (p.phone != null) 'phone': _clean(p.phone),
      if (p.whatsapp != null) 'whatsapp': _clean(p.whatsapp),
      if (p.website != null) 'website': normalizeUrl(p.website),
      if (p.address != null) 'address': _clean(p.address),
      if (p.area != null) 'area': _clean(p.area),
      if (p.city != null) 'city': p.city!.trim(),
    };
    final health = <String, dynamic>{
      if (p.clinicName != null) 'clinic_name': _clean(p.clinicName),
      if (p.availabilityNote != null) 'availability_note': _clean(p.availabilityNote),
      if (p.clearFee) 'consultation_fee': null else if (p.consultationFee != null) 'consultation_fee': p.consultationFee,
      if (p.clearExperience) 'experience_years': null else if (p.experienceYears != null) 'experience_years': p.experienceYears,
      if (p.services != null) 'services': p.services,
      if (p.languages != null) 'languages': p.languages,
      if (p.serviceModes != null) 'service_modes': [for (final m in p.serviceModes!) m.dbValue],
      if (p.bookingUrl != null) 'booking_url': normalizeUrl(p.bookingUrl),
      if (p.showPhone != null) 'show_phone': p.showPhone,
      if (p.showWhatsapp != null) 'show_whatsapp': p.showWhatsapp,
    };
    return (listing, health);
  }

  static Map<String, dynamic> credentialRow(HealthCredentialDraft d) => {
        'kind': d.kind.dbValue,
        'title': d.title.trim(),
        'issuer': _clean(d.issuer),
        'year': d.year,
      };
}
