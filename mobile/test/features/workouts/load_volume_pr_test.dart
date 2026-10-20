import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/workouts/domain/entities/logged_set.dart';
import 'package:grit/features/workouts/domain/entities/workout_enums.dart';
import 'package:grit/features/workouts/domain/services/effective_load.dart';
import 'package:grit/features/workouts/domain/services/pr_detector.dart';
import 'package:grit/features/workouts/domain/services/volume_calculator.dart';

import 'fixtures.dart';

void main() {
  group('EffectiveLoad', () {
    test('weight_reps is the weight on the bar', () {
      expect(
        EffectiveLoad.of(
            exercise: bench, set: doneSet('a', kg: 80, reps: 5), bodyweightKg: 75),
        80,
      );
    });

    test('lb input is converted to kg', () {
      const set = LoggedSet(
          id: 'a', reps: 5, enteredWeight: 135, enteredUnit: WeightUnit.lb);
      expect(EffectiveLoad.of(exercise: bench, set: set), 61.23);
    });

    test('bodyweight_reps is bodyweight × bw_factor', () {
      expect(
        EffectiveLoad.of(
            exercise: pullUp, set: doneSet('a', reps: 10), bodyweightKg: 80),
        80,
      );
    });

    test('weighted_bodyweight adds the added load', () {
      expect(
        EffectiveLoad.of(
            exercise: weightedDip,
            set: doneSet('a', kg: 20, reps: 8),
            bodyweightKg: 80),
        100,
      );
    });

    test('assisted_bodyweight subtracts the assist, never below 0', () {
      expect(
        EffectiveLoad.of(
            exercise: assistedPullUp,
            set: doneSet('a', kg: 30, reps: 8),
            bodyweightKg: 80),
        50,
      );
      expect(
        EffectiveLoad.of(
            exercise: assistedPullUp,
            set: doneSet('a', kg: 90, reps: 8),
            bodyweightKg: 80),
        0,
      );
    });

    test('missing bodyweight counts as 0', () {
      expect(
        EffectiveLoad.of(
            exercise: weightedDip, set: doneSet('a', kg: 20, reps: 8)),
        20,
      );
    });

    test('duration has no load', () {
      expect(
        EffectiveLoad.of(
            exercise: plank, set: doneSet('a', seconds: 60), bodyweightKg: 80),
        isNull,
      );
    });
  });

  group('VolumeCalculator', () {
    test('counts completed working sets only', () {
      final e = entry(bench, [
        doneSet('w', type: SetType.warmup, kg: 40, reps: 10), // excluded
        doneSet('1', kg: 80, reps: 5), // 400
        doneSet('2', kg: 80, reps: 5), // 400
        doneSet('d', type: SetType.drop, kg: 60, reps: 8), // excluded
        doneSet('x', kg: 80, reps: 5, completed: false), // excluded
      ]);
      expect(VolumeCalculator.exerciseVolume(e), 800);
      expect(VolumeCalculator.completedWorkingSets([e]), 2);
    });

    test('sums across exercises and uses bodyweight for bodyweight types', () {
      final exercises = [
        entry(bench, [doneSet('1', kg: 100, reps: 3)]), // 300
        entry(pullUp, [doneSet('2', reps: 10)]), // 80 × 10 = 800
        entry(plank, [doneSet('3', seconds: 60)]), // no volume
      ];
      expect(
          VolumeCalculator.workoutVolume(exercises, bodyweightKg: 80), 1100);
    });
  });

  group('PrDetector', () {
    test('Epley 1RM', () {
      expect(PrDetector.epley1rm(100, 5), 116.67);
      expect(PrDetector.epley1rm(100, 1), 103.33);
    });

    test('weight_reps: heaviest weight and e1RM for <= 10 reps', () {
      final c = PrDetector.candidates(
          TrackingType.weightReps, doneSet('a', kg: 100, reps: 5));
      expect(c, {PrMetric.maxWeight: 100, PrMetric.estimated1rm: 116.67});

      final high = PrDetector.candidates(
          TrackingType.weightReps, doneSet('a', kg: 60, reps: 12));
      expect(high, {PrMetric.maxWeight: 60});
    });

    test('bodyweight and duration metrics', () {
      expect(
          PrDetector.candidates(
              TrackingType.bodyweightReps, doneSet('a', reps: 15)),
          {PrMetric.maxReps: 15});
      expect(
          PrDetector.candidates(
              TrackingType.assistedBodyweight, doneSet('a', kg: 20, reps: 9)),
          {PrMetric.maxReps: 9});
      expect(
          PrDetector.candidates(
              TrackingType.weightedBodyweight, doneSet('a', kg: 25, reps: 5)),
          {PrMetric.maxWeight: 25});
      expect(
          PrDetector.candidates(
              TrackingType.duration, doneSet('a', seconds: 90)),
          {PrMetric.maxHoldSeconds: 90});
    });

    test('warm-up, drop and uncompleted sets never count', () {
      for (final set in [
        doneSet('a', type: SetType.warmup, kg: 200, reps: 1),
        doneSet('b', type: SetType.drop, kg: 200, reps: 1),
        doneSet('c', kg: 200, reps: 1, completed: false),
      ]) {
        expect(PrDetector.candidates(TrackingType.weightReps, set), isEmpty);
      }
    });

    test('detects only records that beat the previous best', () {
      final records = PrDetector.detect([
        entry(
          bench,
          [
            doneSet('w', type: SetType.warmup, kg: 150, reps: 1),
            doneSet('1', kg: 100, reps: 5), // e1RM 116.67
            doneSet('2', kg: 105, reps: 1), // weight 105, e1RM 108.5
          ],
          bests: {PrMetric.maxWeight: 102.5, PrMetric.estimated1rm: 120},
        ),
      ]);
      expect(records, hasLength(1));
      expect(records.single.metric, PrMetric.maxWeight);
      expect(records.single.value, 105);
      expect(records.single.previous, 102.5);
    });

    test('first time logging an exercise is a PR', () {
      final records = PrDetector.detect([
        entry(pullUp, [doneSet('1', reps: 8), doneSet('2', reps: 10)]),
      ]);
      expect(records.single.metric, PrMetric.maxReps);
      expect(records.single.value, 10);
      expect(records.single.previous, isNull);
    });

    test('same exercise logged twice is merged', () {
      final records = PrDetector.detect([
        entry(squat, [doneSet('1', kg: 100, reps: 12)], id: 'a'),
        entry(squat, [doneSet('2', kg: 110, reps: 12)], id: 'b'),
      ]);
      expect(records, hasLength(1));
      expect(records.single.value, 110);
    });
  });
}
