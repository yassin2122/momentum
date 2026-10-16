import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:gym_app/core/constants/app_constants.dart';
import 'package:gym_app/core/theme/app_theme.dart';
import 'package:gym_app/features/workouts/domain/entities/logged_set.dart';
import 'package:gym_app/features/workouts/domain/entities/workout_enums.dart';
import 'package:gym_app/features/workouts/domain/services/workout_finalizer.dart';
import 'package:gym_app/features/workouts/presentation/providers/workout_providers.dart';
import 'package:gym_app/features/workouts/presentation/screens/active_workout_screen.dart';
import 'package:gym_app/features/workouts/presentation/screens/workout_summary_screen.dart';

import 'fake_workout_repository.dart';
import 'fixtures.dart';

void main() {
  testWidgets('log a set in lb, add a pre-filled set, change its category, '
      'finish', (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = FakeWorkoutRepository()
      ..active = workoutOf([
        entry(bench, [const LoggedSet(id: 'set-1')]),
      ]);

    final router = GoRouter(
      initialLocation: AppRoutes.activeWorkout,
      routes: [
        GoRoute(
          path: AppRoutes.activeWorkout,
          builder: (_, __) => const ActiveWorkoutScreen(),
        ),
        GoRoute(
          path: AppRoutes.workoutSummary,
          builder: (_, state) =>
              WorkoutSummaryScreen(summary: state.extra! as WorkoutSummary),
        ),
        GoRoute(
          path: AppRoutes.workouts,
          builder: (_, __) => const Text('workouts tab'),
        ),
      ],
    );

    await tester.pumpWidget(ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('user-1'),
        workoutRepositoryProvider.overrideWithValue(repo),
      ],
      child: MaterialApp.router(
        theme: AppTheme.darkTheme,
        routerConfig: router,
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Bench Press'), findsOneWidget);

    // Switch this exercise to lb and log 135 lb × 8.
    await tester.tap(find.text('lb'));
    await tester.pump();
    await tester.enterText(find.byType(TextField).at(0), '135');
    await tester.enterText(find.byType(TextField).at(1), '8');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    var set = repo.active!.exercises.single.sets.single;
    expect(set.completed, isTrue);
    expect(set.enteredWeight, 135);
    expect(set.enteredUnit, WeightUnit.lb);
    expect(set.loadKg, 61.23);

    // Add set: pre-filled from the previous set, as a working set.
    await tester.tap(find.text('Add set'));
    await tester.pump();
    expect(find.text('135'), findsNWidgets(2));
    expect(find.text('2'), findsOneWidget); // second working set badge

    // An incomplete set can't be checked off without values.
    await tester.enterText(find.byType(TextField).at(3), '');
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();
    expect(find.text('Fill in this set before checking it off.'),
        findsOneWidget);

    // Make the second set a drop set.
    await tester.enterText(find.byType(TextField).at(3), '10');
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester
        .tap(find.widgetWithText(CheckedPopupMenuItem<Object>, 'Drop set'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('D'), findsOneWidget);
    await tester.tap(find.byType(Checkbox).at(1));
    await tester.pump();

    set = repo.active!.exercises.single.sets[1];
    expect(set.setType, SetType.drop);
    expect(set.completed, isTrue);

    // Finish → confirm → summary.
    await tester.tap(find.widgetWithText(FilledButton, 'Finish'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.widgetWithText(TextButton, 'Finish'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Workout complete'), findsOneWidget);
    expect(repo.active, isNull);
    final sets = ((repo.sent.single['exercises'] as List).single
        as Map)['sets'] as List;
    expect(sets[0], containsPair('entered_weight', 135.0));
    expect(sets[0], containsPair('entered_unit', 'lb'));
    expect(sets[0], containsPair('weight_kg', 61.23));
    expect(sets[1], containsPair('set_type', 'drop'));

    // Volume counts only the working set: 61.23 kg × 8 ≈ 490 kg.
    expect(find.text('490 kg'), findsOneWidget);
    expect(find.text('Working sets'.toUpperCase()), findsOneWidget);
    expect(find.text('Saved to your training history.'), findsOneWidget);
  });
}
