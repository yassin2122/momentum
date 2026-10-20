import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/workouts/domain/entities/active_workout.dart';
import 'package:grit/features/workouts/domain/entities/logged_set.dart';
import 'package:grit/features/workouts/domain/entities/workout_enums.dart';
import 'package:grit/features/workouts/domain/services/workout_finalizer.dart';

import 'fixtures.dart';

void main() {
  final end = DateTime.utc(2026, 10, 16, 19, 5);

  test('drops empty uncompleted sets, saves completed sets only', () {
    final w = workoutOf([
      entry(bench, [
        doneSet('a', kg: 80, reps: 5),
        const LoggedSet(id: 'empty'),
        doneSet('typed', kg: 85, reps: 3, completed: false),
      ]),
      entry(squat, [const LoggedSet(id: 'empty2')]),
    ]);
    final prep = WorkoutFinalizer.prepare(w, completedAt: end);

    expect(prep.hasCompletedSets, isTrue);
    // Cleaned workout: the empty sets are gone, typed-but-unfinished stays.
    expect(prep.workout.exercises[0].sets.map((s) => s.id), ['a', 'typed']);
    expect(prep.workout.exercises[1].sets, isEmpty);
    // Payload: only exercises with completed sets, only completed sets.
    final saved = prep.payload['exercises'] as List;
    expect(saved, hasLength(1));
    expect(((saved.single as Map)['sets'] as List).single['id'], 'a');
  });

  test('warns (hasCompletedSets = false) when nothing was completed', () {
    final w = workoutOf([
      entry(bench, [doneSet('a', kg: 80, reps: 5, completed: false)]),
    ]);
    expect(WorkoutFinalizer.prepare(w, completedAt: end).hasCompletedSets,
        isFalse);
  });

  test('stores canonical kg and the value exactly as typed', () {
    const set = LoggedSet(
      id: 's',
      completed: true,
      reps: 5,
      enteredWeight: 135,
      enteredUnit: WeightUnit.lb,
    );
    expect(WorkoutFinalizer.setPayload(TrackingType.weightReps, set, 0), {
      'id': 's',
      'position': 0,
      'set_type': 'working',
      'reps': 5,
      'weight_kg': 61.23,
      'added_kg': null,
      'assist_kg': null,
      'entered_weight': 135.0,
      'entered_unit': 'lb',
      'duration_s': null,
      'rpe': null,
    });
  });

  test('load goes to the column matching the tracking type', () {
    final dip = WorkoutFinalizer.setPayload(TrackingType.weightedBodyweight,
        doneSet('a', kg: 20, reps: 8), 0);
    expect(dip['added_kg'], 20);
    expect(dip['weight_kg'], isNull);

    final assisted = WorkoutFinalizer.setPayload(
        TrackingType.assistedBodyweight, doneSet('b', kg: 30, reps: 8), 0);
    expect(assisted['assist_kg'], 30);

    final hold = WorkoutFinalizer.setPayload(
        TrackingType.duration, doneSet('c', seconds: 45), 0);
    expect(hold['duration_s'], 45);
    expect(hold['reps'], isNull);
  });

  test('summary: duration, working sets, volume and PRs', () {
    final w = workoutOf([
      entry(bench, [
        doneSet('w', type: SetType.warmup, kg: 40, reps: 10),
        doneSet('1', kg: 80, reps: 5),
        doneSet('d', type: SetType.drop, kg: 60, reps: 10),
      ]),
      entry(pullUp, [doneSet('2', reps: 10)]),
    ], bodyweightKg: 75);
    final s = WorkoutFinalizer.summarize(w, completedAt: end, synced: true);

    expect(s.duration, const Duration(hours: 1, minutes: 5));
    expect(s.completedWorkingSets, 2);
    expect(s.volumeKg, 80 * 5 + 75 * 10);
    expect(s.newRecords.map((r) => r.metric).toSet(),
        {PrMetric.maxWeight, PrMetric.estimated1rm, PrMetric.maxReps});
  });

  test('server bodyweight snapshot overrides the local one', () {
    final w = workoutOf([entry(pullUp, [doneSet('1', reps: 10)])],
        bodyweightKg: 75);
    final s = WorkoutFinalizer.summarize(w,
        completedAt: end, synced: true, bodyweightKg: 80);
    expect(s.volumeKg, 800);
  });

  test('active workout survives a JSON round trip (local persistence)', () {
    final w = workoutOf([
      entry(bench, [
        const LoggedSet(
            id: 'a',
            reps: 5,
            enteredWeight: 135,
            enteredUnit: WeightUnit.lb,
            setType: SetType.warmup),
      ], bests: const {PrMetric.maxWeight: 100}),
    ], templateId: 'tpl', bodyweightKg: 80);

    final restored = ActiveWorkout.fromJson(
        jsonDecode(jsonEncode(w.toJson())) as Map<String, dynamic>);
    final set = restored.exercises.single.sets.single;
    expect(restored.templateId, 'tpl');
    expect(restored.startedAt, w.startedAt);
    expect(restored.bodyweightKg, 80);
    expect(set.enteredWeight, 135);
    expect(set.enteredUnit, WeightUnit.lb);
    expect(set.setType, SetType.warmup);
    expect(restored.exercises.single.personalBests[PrMetric.maxWeight], 100);
  });
}
