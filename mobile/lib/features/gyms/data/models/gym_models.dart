import '../../domain/entities/gym_entities.dart';

/// Row → entity mapping for the gyms feature. Pure functions: the datasource
/// hands over raw maps, these turn them into domain types. [publicUrl]
/// resolves a `gym-media` storage path to its public URL.
abstract final class GymModels {
  // ---- small readers ----

  static String _s(Object? v) => v?.toString() ?? '';
  static String? _ns(Object? v) {
    final s = v?.toString();
    return s == null || s.isEmpty ? null : s;
  }

  static int _i(Object? v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;
  static int? _ni(Object? v) =>
      v == null ? null : (v is num ? v.toInt() : int.tryParse('$v'));
  static double? _nd(Object? v) =>
      v == null ? null : (v is num ? v.toDouble() : double.tryParse('$v'));
  static bool _b(Object? v) => v == true;
  static DateTime _dt(Object? v) =>
      DateTime.tryParse(_s(v))?.toLocal() ?? DateTime.now();
  static DateTime? _ndt(Object? v) =>
      v == null ? null : DateTime.tryParse(_s(v))?.toLocal();
  static List<String> _strings(Object? v) =>
      v is List ? [for (final e in v) if (e != null) e.toString()] : const [];
  static List<Map<String, dynamic>> _maps(Object? v) => v is List
      ? [for (final e in v) if (e is Map) Map<String, dynamic>.from(e)]
      : const [];
  static List<GymAiFeature> _features(Object? v) => [
        for (final f in _strings(v))
          if (GymAiFeature.fromDb(f) case final GymAiFeature feature) feature,
      ];

  static String _personName(Map<String, dynamic> r) =>
      _ns(r['display_name']) ?? _ns(r['username']) ?? 'Coach';

  // ---- public ----

  static GymDirectoryEntry directoryEntry(
    Map<String, dynamic> r,
    String Function(String path) publicUrl,
  ) {
    final cover = _ns(r['cover_path']);
    return GymDirectoryEntry(
      gymId: _s(r['gym_id']),
      name: _s(r['name']),
      headline: _ns(r['headline']),
      logoUrl: _ns(r['logo_url']),
      coverUrl: cover == null ? null : publicUrl(cover),
      area: _ns(r['area']),
      city: _ns(r['city']),
      facilities: _strings(r['facilities']),
      branchCount: _i(r['branch_count']),
      offersFrom: _nd(r['offers_from']),
      currency: _ns(r['currency'])?.trim(),
      isPartner: _b(r['is_partner']),
    );
  }

  static GymProfile profile(
    Map<String, dynamic> r,
    String Function(String path) publicUrl,
  ) {
    final listing = r['marketplace_listings'] is Map
        ? Map<String, dynamic>.from(r['marketplace_listings'] as Map)
        : const <String, dynamic>{};
    final cover = _ns(r['cover_path']);
    return GymProfile(
      id: _s(r['id']),
      listingId: _s(r['listing_id']),
      name: _s(listing['name']),
      headline: _ns(listing['headline']),
      description: _ns(listing['description']),
      logoUrl: _ns(listing['logo_url']),
      coverPath: cover,
      coverUrl: cover == null ? null : publicUrl(cover),
      phone: _ns(listing['phone']),
      whatsapp: _ns(listing['whatsapp']),
      email: _ns(listing['email']),
      website: _ns(listing['website']),
      address: _ns(listing['address']),
      area: _ns(listing['area']),
      city: _ns(listing['city']),
      isMultiBranch: _b(r['is_multi_branch']),
      facilities: _strings(r['facilities']),
      equipment: _strings(r['equipment']),
      services: _strings(r['services']),
    );
  }

  static GymHours? _hours(Map<String, dynamic> r) {
    final days = [
      for (final d in (r['days'] is List ? r['days'] as List : const []))
        if (_ni(d) case final int day) day,
    ];
    final open = _ns(r['open']);
    final close = _ns(r['close']);
    if (days.isEmpty || open == null || close == null) return null;
    return GymHours(days: days, open: open, close: close);
  }

  static GymBranch branch(Map<String, dynamic> r) => GymBranch(
        id: _s(r['id']),
        gymId: _s(r['gym_id']),
        name: _s(r['name']),
        address: _ns(r['address']),
        area: _ns(r['area']),
        city: _s(r['city']),
        phone: _ns(r['phone']),
        open24h: _b(r['open_24h']),
        hours: [
          for (final h in _maps(r['opening_hours']))
            if (_hours(h) case final GymHours hours) hours,
        ],
        hoursNote: _ns(r['hours_note']),
        facilities: _strings(r['facilities']),
        isPublished: _b(r['is_published']),
      );

  static GymOffer offer(Map<String, dynamic> r) => GymOffer(
        id: _s(r['id']),
        gymId: _s(r['gym_id']),
        name: _s(r['name']),
        priceAmount: _nd(r['price_amount']),
        currency: (_ns(r['currency']) ?? 'EGP').trim(),
        durationDays: _ni(r['duration_days']),
        durationLabel: _ns(r['duration_label']),
        benefits: _strings(r['benefits']),
        branchIds: _strings(r['branch_ids']),
        isVisible: _b(r['is_visible']),
      );

  static GymPhoto photo(
    Map<String, dynamic> r,
    String Function(String path) publicUrl,
  ) =>
      GymPhoto(
        id: _s(r['id']),
        storagePath: _s(r['storage_path']),
        url: publicUrl(_s(r['storage_path'])),
      );

  static GymPublicCoach publicCoach(Map<String, dynamic> r) => GymPublicCoach(
        coachId: _s(r['coach_id']),
        name: _personName(r),
        avatarUrl: _ns(r['avatar_url']),
        headline: _ns(r['headline']),
        role: GymCoachRole.fromDb(_ns(r['role'])),
      );

  // ---- admin ----

  static MyGym myGym(Map<String, dynamic> r) => MyGym(
        gymId: _s(r['gym_id']),
        name: _s(r['name']),
        logoUrl: _ns(r['logo_url']),
        role: GymStaffRole.fromDb(_ns(r['role'])),
      );

  static GymPartnership? _partnership(Object? v) {
    if (v is! Map) return null;
    final r = Map<String, dynamic>.from(v);
    return GymPartnership(
      id: _s(r['id']),
      status: GymPartnershipStatus.fromDb(_ns(r['status'])),
      startsOn: _ndt(r['starts_on']),
      endsOn: _ndt(r['ends_on']),
      monthlyAllowance: _i(r['ai_monthly_allowance']),
      perCoachCap: _ni(r['ai_per_coach_cap']),
      features: _features(r['ai_features']),
      usedThisMonth: _i(r['ai_used_month']),
    );
  }

  static GymAdminOverview overview(Map<String, dynamic> r) => GymAdminOverview(
        gymId: _s(r['gym_id']),
        name: _s(r['name']),
        logoUrl: _ns(r['logo_url']),
        role: GymStaffRole.fromDb(_ns(r['role'])),
        listingState: GymListingState.fromDb(_ns(r['listing_state'])),
        branchCount: _i(r['branch_count']),
        offerCount: _i(r['offer_count']),
        photoCount: _i(r['photo_count']),
        hasDescription: _b(r['has_description']),
        hasCover: _ns(r['cover_path']) != null,
        staffCount: _i(r['staff_count']),
        coachCount: _i(r['coach_count']),
        pendingInvites: _i(r['pending_invites']),
        views30d: _i(r['views_30d']),
        views14d: [
          for (final d in _maps(r['views_14d']))
            GymDayViews(day: _dt(d['day']), views: _i(d['views'])),
        ],
        newInquiries: _ni(r['inquiries_new']),
        inquiriesThisMonth: _ni(r['inquiries_month']),
        partnership: _partnership(r['partnership']),
      );

  static GymCoachesAdmin coachesAdmin(Map<String, dynamic> r) =>
      GymCoachesAdmin(
        coaches: [
          for (final c in _maps(r['coaches']))
            GymCoachAffiliation(
              id: _s(c['id']),
              coachId: _s(c['coach_id']),
              name: _personName(c),
              avatarUrl: _ns(c['avatar_url']),
              role: GymCoachRole.fromDb(_ns(c['role'])),
              branchIds: _strings(c['branch_ids']),
              startedAt: _dt(c['started_at']),
              aiUsedThisMonth: _i(c['ai_used_month']),
            ),
        ],
        invitations: [
          for (final i in _maps(r['invitations']))
            GymCoachInvitation(
              id: _s(i['id']),
              kind: GymInviteKind.fromDb(_ns(i['kind'])),
              coachId: _s(i['coach_id']),
              name: _personName(i),
              avatarUrl: _ns(i['avatar_url']),
              role: GymCoachRole.fromDb(_ns(i['role'])),
              status: GymInviteStatus.fromDb(_ns(i['status'])),
              createdAt: _dt(i['created_at']),
              expiresAt: _dt(i['expires_at']),
              respondedAt: _ndt(i['responded_at']),
            ),
        ],
        codeHint: _ns(r['code_hint']),
        codeExpiresAt: _ndt(r['code_expires_at']),
      );

  static GymInquiry inquiry(Map<String, dynamic> r) => GymInquiry(
        id: _s(r['id']),
        gymId: _s(r['gym_id']),
        branchId: _ns(r['branch_id']),
        offerId: _ns(r['offer_id']),
        name: _s(r['name']),
        phone: _ns(r['phone']),
        contactMethod: GymContactMethod.fromDb(_ns(r['contact_method'])),
        message: _ns(r['message']),
        status: GymInquiryStatus.fromDb(_ns(r['status'])),
        createdAt: _dt(r['created_at']),
      );

  static GymStaffMember staffMember(Map<String, dynamic> r) => GymStaffMember(
        userId: _s(r['user_id']),
        name: _ns(r['display_name']) ?? _ns(r['username']) ?? 'Teammate',
        avatarUrl: _ns(r['avatar_url']),
        role: GymStaffRole.fromDb(_ns(r['role'])),
      );

  static GymCode code(Map<String, dynamic> r) => GymCode(
        code: _s(r['code']),
        expiresAt: _dt(r['expires_at']),
      );

  // ---- coach ----

  static MyGymAffiliations affiliations(Map<String, dynamic> r) =>
      MyGymAffiliations(
        affiliations: [
          for (final a in _maps(r['affiliations']))
            CoachGymAffiliation(
              id: _s(a['id']),
              gymId: _s(a['gym_id']),
              gymName: _s(a['gym_name']),
              logoUrl: _ns(a['logo_url']),
              role: GymCoachRole.fromDb(_ns(a['role'])),
              startedAt: _dt(a['started_at']),
            ),
        ],
        invitations: [
          for (final i in _maps(r['invitations']))
            CoachGymInvitation(
              id: _s(i['id']),
              kind: GymInviteKind.fromDb(_ns(i['kind'])),
              gymId: _s(i['gym_id']),
              gymName: _s(i['gym_name']),
              logoUrl: _ns(i['logo_url']),
              role: GymCoachRole.fromDb(_ns(i['role'])),
              message: _ns(i['message']),
              branchNames: _strings(i['branch_names']),
              invitedBy: _ns(i['invited_by']),
              createdAt: _dt(i['created_at']),
              expiresAt: _dt(i['expires_at']),
            ),
        ],
      );

  static AiEntitlement entitlement(Map<String, dynamic> r) {
    if (!_b(r['eligible'])) return AiEntitlement.none;
    return AiEntitlement(
      eligible: true,
      gymName: _ns(r['gym_name']),
      features: _features(r['features']),
      monthlyAllowance: _i(r['monthly_allowance']),
      gymUsed: _i(r['gym_used']),
      perCoachCap: _ni(r['per_coach_cap']),
      myUsed: _i(r['my_used']),
      resetsOn: _ndt(r['resets_on']),
    );
  }

  // ---- drafts → rows ----

  static String? _clean(String? v) {
    final t = v?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  static Map<String, dynamic> branchRow(GymBranchDraft d) => {
        'name': d.name.trim(),
        'address': _clean(d.address),
        'area': _clean(d.area),
        'city': d.city.trim(),
        'phone': _clean(d.phone),
        'open_24h': d.open24h,
        'opening_hours': [for (final h in d.hours) h.toJson()],
        'facilities': d.facilities,
        'is_published': d.isPublished,
      };

  static Map<String, dynamic> offerRow(GymOfferDraft d) => {
        'name': d.name.trim(),
        'price_amount': d.priceAmount,
        'duration_days': d.durationDays,
        'benefits': [for (final b in d.benefits) if (b.trim().isNotEmpty) b.trim()],
        'branch_ids': d.branchIds,
        'is_visible': d.isVisible,
      };

  /// Splits a patch into marketplace_listings and gyms columns.
  static (Map<String, dynamic>, Map<String, dynamic>) patchRows(
      GymProfilePatch p) {
    String? opt(String? v) => v == null ? null : _clean(v);
    final listing = <String, dynamic>{
      if (p.name != null) 'name': p.name!.trim(),
      if (p.headline != null) 'headline': opt(p.headline),
      if (p.description != null) 'description': opt(p.description),
      if (p.phone != null) 'phone': opt(p.phone),
      if (p.whatsapp != null) 'whatsapp': opt(p.whatsapp),
      if (p.email != null) 'email': opt(p.email),
      if (p.website != null) 'website': opt(p.website),
      if (p.address != null) 'address': opt(p.address),
      if (p.area != null) 'area': opt(p.area),
      if (p.city != null) 'city': p.city!.trim(),
    };
    final gym = <String, dynamic>{
      if (p.facilities != null) 'facilities': p.facilities,
      if (p.equipment != null) 'equipment': p.equipment,
      if (p.services != null) 'services': p.services,
    };
    return (listing, gym);
  }
}
