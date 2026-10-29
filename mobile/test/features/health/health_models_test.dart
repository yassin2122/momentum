import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/health/data/models/health_models.dart';
import 'package:grit/features/health/domain/entities/health_entities.dart';
import 'package:grit/features/health/presentation/widgets/health_ui.dart';

void main() {
  group('HealthModels.detail', () {
    test('reads consented contacts and splits verified from provider-submitted', () {
      final p = HealthModels.detail({
        'listing_id': 'l1',
        'kind': 'doctor',
        'name': 'Dr. Nour Hassan',
        'headline': 'Sports medicine physician',
        'specialties': ['Sports medicine'],
        'phone': '+20 2 2358 4400',
        'phone_verified': true,
        'whatsapp': null,
        'booking_url': 'https://clinic.example/book',
        'city': 'Cairo',
        'consultation_fee': '600',
        'service_modes': ['clinic', 'unknown'],
        'credentials': [
          {'kind': 'license', 'title': 'Licence to practise', 'verified': true, 'verified_at': '2026-09-01T10:00:00Z'},
          {'kind': 'degree', 'title': 'MSc Sports Medicine', 'issuer': 'Cairo University', 'year': 2016, 'verified': false},
        ],
      });
      expect(p.kind, HealthKind.doctor);
      expect(p.whatsapp, isNull);
      expect(p.phoneVerified, isTrue);
      expect(p.consultationFee, 600);
      expect(p.serviceModes, [HealthServiceMode.clinic]);
      expect(p.licenseVerified, isTrue);
      expect(p.credentials[1].verified, isFalse);
      expect(p.credentials[1].subtitle, 'Cairo University · 2016');
      expect(p.hasAnyContact, isTrue);
    });

    test('a provider with no verified licence is not shown as verified', () {
      final p = HealthModels.detail({
        'listing_id': 'l2',
        'kind': 'physical_therapist',
        'name': 'Karim Hegazy, PT',
        'credentials': [
          {'kind': 'license', 'title': 'Licence', 'verified': false},
        ],
      });
      expect(p.kind, HealthKind.physio);
      expect(p.licenseVerified, isFalse);
      expect(p.hasAnyContact, isFalse);
    });
  });

  group('MyHealthProfile', () {
    Map<String, dynamic> listing({String status = 'pending', bool published = false, String? submitted}) => {
          'id': 'l1',
          'provider_type': 'doctor',
          'status': status,
          'is_published': published,
          'name': 'Dr. Nour',
          'headline': 'Sports medicine physician',
          'description': 'I work with athletes on sports injuries and return to training.',
          'specialties': ['Sports medicine'],
          'phone': '+20 2 2358 4400',
          'health_profiles': {
            'show_phone': true,
            'show_whatsapp': false,
            'service_modes': ['clinic'],
            'submitted_at': submitted,
          },
        };

    test('state follows submission, approval and visibility', () {
      expect(HealthModels.mine(listing(), const []).state, HealthProfileState.draft);
      expect(HealthModels.mine(listing(published: true, submitted: '2026-10-01'), const []).state,
          HealthProfileState.inReview);
      expect(
          HealthModels.mine(listing(status: 'approved', published: true, submitted: '2026-10-01'), const [])
              .state,
          HealthProfileState.live);
      expect(
          HealthModels.mine(listing(status: 'approved', published: false, submitted: '2026-10-01'), const [])
              .state,
          HealthProfileState.hidden);
      expect(HealthModels.mine(listing(status: 'suspended'), const []).state, HealthProfileState.suspended);
    });

    test('missing lists what blocks submission', () {
      final ok = HealthModels.mine(listing(), const []);
      expect(ok.missing, isEmpty);
      final l = listing()..['description'] = 'Short';
      (l['health_profiles'] as Map)['show_phone'] = false;
      expect(HealthModels.mine(l, const []).missing,
          ['Biography (40+ characters)', 'A public way to reach you']);
    });

    test('credential status comes from the row', () {
      final p = HealthModels.mine(listing(), [
        {'id': 'c1', 'kind': 'degree', 'title': 'MSc', 'status': 'pending', 'document_path': 'l1/x.jpg'},
      ]);
      expect(p.credentials.single.status, HealthCredentialStatus.pending);
    });
  });

  group('HealthModels.patchRows', () {
    test('splits columns, normalises links and clears blanks', () {
      final (listing, health) = HealthModels.patchRows(const HealthProfilePatch(
        website: 'clinic.example',
        headline: '  ',
        bookingUrl: 'http://clinic.example/book',
        clearFee: true,
        serviceModes: [HealthServiceMode.clinic, HealthServiceMode.home],
        showWhatsapp: true,
      ));
      expect(listing, {'website': 'https://clinic.example', 'headline': null});
      expect(health, {
        'consultation_fee': null,
        'service_modes': ['clinic', 'home'],
        'booking_url': 'https://clinic.example/book',
        'show_whatsapp': true,
      });
    });

    test('only name and contact changes trigger review', () {
      expect(const HealthProfilePatch(whatsapp: '010').triggersReview, isTrue);
      expect(const HealthProfilePatch(description: 'x').triggersReview, isFalse);
    });
  });

  group('contact links', () {
    test('call, WhatsApp and maps use only the published details', () {
      expect(healthCallUri('+20 2 2358-4400').toString(), 'tel:+20223584400');
      expect(healthWhatsappUri('+20 100 555 2140').toString(), 'https://wa.me/201005552140');
      final p = HealthModels.detail({
        'listing_id': 'l1',
        'kind': 'doctor',
        'name': 'Dr. N',
        'latitude': 29.96,
        'longitude': 31.25,
      });
      expect(healthMapsUri(p)!.queryParameters['query'], '29.96,31.25');
    });
  });
}
