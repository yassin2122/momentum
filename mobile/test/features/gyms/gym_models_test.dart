import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/gyms/data/models/gym_models.dart';
import 'package:grit/features/gyms/domain/entities/gym_entities.dart';
import 'package:grit/features/gyms/presentation/widgets/gym_ui.dart';

void main() {
  group('GymModels.branch', () {
    test('parses hours and skips malformed rules', () {
      final b = GymModels.branch({
        'id': 'b1',
        'gym_id': 'g1',
        'name': 'Maadi',
        'city': 'Cairo',
        'open_24h': false,
        'is_published': true,
        'facilities': ['Sauna'],
        'opening_hours': [
          {'days': [0, 1, 2, 3, 4], 'open': '06:00', 'close': '23:00'},
          {'days': [], 'open': '08:00', 'close': '20:00'},
          {'days': [5], 'open': null, 'close': '20:00'},
        ],
      });
      expect(b.hours, hasLength(1));
      expect(b.hours.first.label, 'Sun–Thu · 06:00–23:00');
      expect(b.hasHours, isTrue);
      expect(b.addressLabel, 'Cairo');
    });

    test('open 24 hours needs no rules', () {
      final b = GymModels.branch({
        'id': 'b1',
        'gym_id': 'g1',
        'name': 'Zayed',
        'city': 'Giza',
        'open_24h': true,
        'opening_hours': [],
      });
      expect(b.hasHours, isTrue);
      expect(b.hoursLabel, 'Open 24 hours');
    });
  });

  group('GymModels.offer', () {
    test('null price means ask the gym; durations read naturally', () {
      final o = GymModels.offer({
        'id': 'o1',
        'gym_id': 'g1',
        'name': 'Monthly',
        'price_amount': null,
        'duration_days': 90,
        'branch_ids': [],
        'is_visible': true,
      });
      expect(o.priceAmount, isNull);
      expect(o.currency, 'EGP');
      expect(o.durationText, '3 months');
      expect(o.appliesTo('any-branch'), isTrue);
    });

    test('branch-limited offer applies only to its branches', () {
      final o = GymModels.offer({
        'id': 'o1',
        'gym_id': 'g1',
        'name': 'Day pass',
        'price_amount': '150',
        'duration_days': 1,
        'branch_ids': ['b1'],
        'is_visible': true,
      });
      expect(o.priceAmount, 150);
      expect(o.durationText, '1 day');
      expect(o.appliesTo('b1'), isTrue);
      expect(o.appliesTo('b2'), isFalse);
    });
  });

  group('GymModels.overview', () {
    test('reads counts, partnership and checklist', () {
      final o = GymModels.overview({
        'gym_id': 'g1',
        'name': 'Iron House',
        'role': 'manager',
        'listing_state': 'pending_review',
        'branch_count': 1,
        'offer_count': 0,
        'photo_count': 4,
        'has_description': true,
        'cover_path': 'g1/cover.jpg',
        'staff_count': 2,
        'coach_count': 0,
        'pending_invites': 1,
        'views_30d': 12,
        'views_14d': [
          {'day': '2026-10-28', 'views': 3},
        ],
        'inquiries_new': 2,
        'partnership': {
          'id': 'p1',
          'status': 'active',
          'ai_monthly_allowance': 200,
          'ai_per_coach_cap': 50,
          'ai_features': ['ai_plan_builder', 'unknown_feature'],
          'ai_used_month': 50,
        },
      });
      expect(o.role, GymStaffRole.manager);
      expect(o.listingState, GymListingState.pendingReview);
      expect(o.hasCover, isTrue);
      expect(o.views14d.single.views, 3);
      expect(o.partnership!.isActive, isTrue);
      expect(o.partnership!.features, [GymAiFeature.planBuilder]);
      expect(o.partnership!.usedFraction, 0.25);
      final done = {for (final (label, ok) in o.checklist) label: ok};
      expect(done['Add a public offer'], isFalse);
      expect(done['Invite your coaches'], isTrue);
    });

    test('a role that cannot see inquiries gets null counts', () {
      final o = GymModels.overview({
        'gym_id': 'g1',
        'name': 'Iron House',
        'role': 'marketing',
        'listing_state': 'draft',
      });
      expect(o.newInquiries, isNull);
      expect(o.role.canSeeInquiries, isFalse);
      expect(o.partnership, isNull);
    });
  });

  group('AiEntitlement', () {
    test('not eligible when the gym has no active partnership', () {
      expect(GymModels.entitlement({'eligible': false}).eligible, isFalse);
    });

    test('remaining is the smaller of the gym pool and the coach cap', () {
      final e = GymModels.entitlement({
        'eligible': true,
        'gym_name': 'Iron House',
        'features': ['ai_plan_builder'],
        'monthly_allowance': 100,
        'gym_used': 95,
        'per_coach_cap': 20,
        'my_used': 4,
      });
      expect(e.remaining, 5);
      expect(e.myLimit, 20);
    });

    test('no AI feature is marked available until a service ships', () {
      expect(GymAiFeature.values.where((f) => f.available), isEmpty);
    });
  });

  group('GymModels.patchRows', () {
    test('splits listing and gym columns and clears blank optionals', () {
      final (listing, gym) = GymModels.patchRows(const GymProfilePatch(
        headline: '  ',
        city: ' Cairo ',
        facilities: ['Sauna'],
      ));
      expect(listing, {'headline': null, 'city': 'Cairo'});
      expect(gym, {
        'facilities': ['Sauna'],
      });
    });

    test('name and contact changes trigger review, others do not', () {
      expect(const GymProfilePatch(phone: '0100').triggersReview, isTrue);
      expect(const GymProfilePatch(description: 'x').triggersReview, isFalse);
    });
  });

  group('Inquiry status', () {
    test('moves new → contacted → closed → new', () {
      expect(GymInquiryStatus.fromDb('new').next, GymInquiryStatus.contacted);
      expect(GymInquiryStatus.contacted.next, GymInquiryStatus.closed);
      expect(GymInquiryStatus.closed.next, GymInquiryStatus.fresh);
    });
  });

  group('formatting', () {
    test('prices group thousands and keep real decimals', () {
      expect(gymPrice(900, 'EGP'), '900 EGP');
      expect(gymPrice(12500, 'EGP'), '12,500 EGP');
      expect(gymPrice(99.5, 'EGP'), '99.50 EGP');
    });
  });
}
