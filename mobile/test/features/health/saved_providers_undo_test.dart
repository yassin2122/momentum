import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grit/core/error/result.dart';
import 'package:grit/core/widgets/provider_card.dart';
import 'package:grit/features/gyms/presentation/providers/gym_providers.dart';
import 'package:grit/features/health/domain/entities/health_entities.dart';
import 'package:grit/features/health/domain/repositories/health_repository.dart';
import 'package:grit/features/health/presentation/providers/health_providers.dart';
import 'package:grit/features/health/presentation/screens/saved_providers_screen.dart';

class _FakeRepo implements HealthRepository {
  final saved = <String>{'l1'};
  final calls = <(String, bool)>[];

  @override
  Future<Result<List<HealthDirectoryEntry>>> getSaved() async =>
      Result.success([
        for (final id in saved)
          HealthDirectoryEntry(
            listingId: id,
            kind: HealthKind.doctor,
            name: 'Dr. Nour Hassan',
            specialties: const [],
            serviceModes: const [],
            licenseVerified: true,
            isSaved: true,
          ),
      ]);

  @override
  Future<Result<void>> setSaved(String listingId, bool value) async {
    calls.add((listingId, value));
    value ? saved.add(listingId) : saved.remove(listingId);
    return const Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('unsave hides the card at once and Undo restores it',
      (tester) async {
    final repo = _FakeRepo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        healthRepositoryProvider.overrideWithValue(repo),
        gymAccountProvider.overrideWithValue(true),
      ],
      child: const MaterialApp(home: Scaffold(body: SavedProvidersScreen())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Dr. Nour Hassan'), findsOneWidget);

    await tester.tap(find.byType(ProviderSaveButton));
    await tester.pump();
    expect(find.text('Dr. Nour Hassan'), findsNothing); // optimistic
    await tester.pumpAndSettle();
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('Dr. Nour Hassan'), findsOneWidget);
    expect(repo.calls, [('l1', false), ('l1', true)]);
  });
}
