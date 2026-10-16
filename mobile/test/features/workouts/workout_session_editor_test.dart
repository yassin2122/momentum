import 'package:flutter_test/flutter_test.dart';
import 'package:gym_app/features/workouts/domain/entities/logged_set.dart';
import 'package:gym_app/features/workouts/domain/entities/workout_enums.dart';
import 'package:gym_app/features/workouts/domain/entities/workout_template.dart';
import 'package:gym_app/features/workouts/domain/services/workout_finalizer.dart';
import 'package:gym_app/features/workouts/domain/services/workout_session_editor.dart';

import 'fixtures.dart';

void main() {
  final now = DateTime.utc(2026, 10, 16, 18);
  const pushDay = WorkoutTemplate(
    id: 'tpl-push',
    name: 'Push Day',
    exercises: [
      TemplateExercise(exercise: bench, defaultSets: 3),
      TemplateExercise(exercise: weightedDip),
    ],
  );

  group('starting', () {
    test('empty workout has no exercises and no template', () {
      final w = testEditor().startEmpty(userId: 'u', now: now);
      expect(w.exercises, isEmpty);
      expect(w.templateId, isNull);
      expect(WorkoutSessionEditor.templateAdditions(w), isEmpty);
    });

    test('from template: exercises in order with default set counts', () {
      final w = testEditor().startFromTemplate(pushDay,
          userId: 'u', now: now, unit: WeightUnit.lb);
      expect(w.templateId, 'tpl-push');
      expect(w.exercises.map((e) => e.exercise.id), ['ex-bench', 'ex-dip']);
      expect(w.exercises[0].sets, hasLength(3));
      expect(w.exercises[1].sets, hasLength(1)); // null target → 1
      expect(w.exercises.every((e) => e.unit == WeightUnit.lb), isTrue);
      expect(w.exercises.every((e) => !e.addedDuringWorkout), isTrue);
    });
  });

  group('template rules', () {
    late WorkoutSessionEditor editor;
    setUp(() => editor = testEditor());

    test('an added exercise joins the template on finish', () {
      var w = editor.startFromTemplate(pushDay,
          userId: 'u', now: now, unit: WeightUnit.kg);
      w = editor.addExercise(w, squat, unit: WeightUnit.kg);
      final added = w.exercises.last;
      w = editor.updateSet(w, added.id, added.sets.single.id,
          (s) => s.copyWith(reps: () => 5, enteredWeight: () => 100));
      w = editor.addSet(w, added.id); // pre-filled from the first set

      final additions = WorkoutSessionEditor.templateAdditions(w);
      expect(additions.map((a) => a.exerciseId), ['ex-squat']);
      expect(additions.single.defaultSets, 2);

      final payload =
          WorkoutFinalizer.prepare(w, completedAt: now).payload;
      expect(payload['template_additions'], [
        {'exercise_id': 'ex-squat', 'default_sets': 2},
      ]);
    });

    test('no template additions when the workout has no template', () {
      var w = editor.startEmpty(userId: 'u', now: now);
      w = editor.addExercise(w, squat, unit: WeightUnit.kg);
      expect(WorkoutSessionEditor.templateAdditions(w), isEmpty);
    });

    test('removing a template exercise never changes the template', () {
      var w = editor.startFromTemplate(pushDay,
          userId: 'u', now: now, unit: WeightUnit.kg);
      w = editor.removeExercise(w, w.exercises.first.id);
      expect(w.exercises.map((e) => e.exercise.id), ['ex-dip']);
      expect(WorkoutSessionEditor.templateAdditions(w), isEmpty);
      final payload = WorkoutFinalizer.prepare(w, completedAt: now).payload;
      expect(payload['template_additions'], isEmpty);
    });

    test('removing an added exercise drops its pending template addition',
        () {
      var w = editor.startFromTemplate(pushDay,
          userId: 'u', now: now, unit: WeightUnit.kg);
      w = editor.addExercise(w, squat, unit: WeightUnit.kg);
      w = editor.removeExercise(w, w.exercises.last.id);
      expect(WorkoutSessionEditor.templateAdditions(w), isEmpty);
    });

    test('replacing never changes the template, even an added exercise', () {
      var w = editor.startFromTemplate(pushDay,
          userId: 'u', now: now, unit: WeightUnit.kg);
      w = editor.replaceExercise(w, w.exercises.first.id, squat);
      expect(WorkoutSessionEditor.templateAdditions(w), isEmpty);

      w = editor.addExercise(w, pullUp, unit: WeightUnit.kg);
      w = editor.replaceExercise(w, w.exercises.last.id, plank);
      expect(WorkoutSessionEditor.templateAdditions(w), isEmpty);
    });

    test('the same exercise added twice is one addition', () {
      var w = editor.startFromTemplate(pushDay,
          userId: 'u', now: now, unit: WeightUnit.kg);
      w = editor.addExercise(w, squat, unit: WeightUnit.kg);
      w = editor.addExercise(w, squat, unit: WeightUnit.kg);
      expect(WorkoutSessionEditor.templateAdditions(w), hasLength(1));
    });
  });

  group('replace', () {
    test('same position, keeps set count and categories, records origin', () {
      final editor = testEditor();
      var w = workoutOf([
        entry(bench, [
          doneSet('a', type: SetType.warmup, kg: 40, reps: 10),
          doneSet('b', kg: 80, reps: 5),
        ]),
        entry(plank, [doneSet('c', seconds: 60)]),
      ]);
      w = editor.replaceExercise(w, 'entry-ex-bench', pullUp);

      final replaced = w.exercises.first;
      expect(replaced.exercise.id, 'ex-pullup');
      expect(replaced.replacedFromExerciseId, 'ex-bench');
      expect(replaced.sets.map((s) => s.setType),
          [SetType.warmup, SetType.working]);
      // reps fit bodyweight_reps; weight doesn't.
      expect(replaced.sets.map((s) => s.reps), [10, 5]);
      expect(replaced.sets.every((s) => s.enteredWeight == null), isTrue);
      expect(replaced.sets.every((s) => !s.completed), isTrue);
      expect(w.exercises[1].exercise.id, 'ex-plank');
    });

    test('same tracking type keeps the load', () {
      var w = workoutOf([
        entry(bench, [doneSet('a', kg: 80, reps: 5)]),
      ]);
      w = testEditor().replaceExercise(w, 'entry-ex-bench', squat);
      expect(w.exercises.single.sets.single.enteredWeight, 80);
    });

    test('replacing twice keeps the original exercise as origin', () {
      final editor = testEditor();
      var w = workoutOf([entry(bench, [doneSet('a', kg: 80, reps: 5)])]);
      w = editor.replaceExercise(w, 'entry-ex-bench', squat);
      w = editor.replaceExercise(w, 'entry-ex-bench', pullUp);
      expect(w.exercises.single.replacedFromExerciseId, 'ex-bench');
    });

    test('duration → reps clears the hold time', () {
      var w = workoutOf([entry(plank, [doneSet('a', seconds: 60)])]);
      w = testEditor().replaceExercise(w, 'entry-ex-plank', pullUp);
      expect(w.exercises.single.sets.single.durationS, isNull);
      expect(w.exercises.single.sets.single.reps, isNull);
    });
  });

  group('sets', () {
    test('add set copies the previous set as a working set', () {
      var w = workoutOf([
        entry(bench, [doneSet('a', type: SetType.warmup, kg: 60, reps: 8)]),
      ]);
      w = testEditor().addSet(w, 'entry-ex-bench');
      final added = w.exercises.single.sets.last;
      expect(added.setType, SetType.working);
      expect(added.completed, isFalse);
      expect(added.enteredWeight, 60);
      expect(added.reps, 8);
    });

    test('add set with no sets left uses the last session', () {
      var w = workoutOf([
        entry(bench, const []).copyWith(previousSets: const [
          PreviousSet(
              setType: SetType.working,
              reps: 8,
              loadKg: 61.23,
              enteredWeight: 135,
              enteredUnit: WeightUnit.lb),
        ]),
      ]);
      w = testEditor().addSet(w, 'entry-ex-bench');
      final added = w.exercises.single.sets.single;
      expect(added.reps, 8);
      expect(added.enteredWeight, 61.23); // exercise is in kg
      expect(added.enteredUnit, WeightUnit.kg);
    });

    test('history pre-fills untouched sets by position, exact in same unit',
        () {
      final editor = testEditor();
      var w = editor.startFromTemplate(
        const WorkoutTemplate(id: 't', name: 'T', exercises: [
          TemplateExercise(exercise: bench, defaultSets: 3),
        ]),
        userId: 'u',
        now: now,
        unit: WeightUnit.lb,
      );
      final id = w.exercises.single.id;
      w = editor.updateSet(w, id, w.exercises.single.sets[1].id,
          (s) => s.copyWith(reps: () => 3));
      w = editor.applyHistory(w, id, previousSets: const [
        PreviousSet(
            setType: SetType.working,
            reps: 8,
            loadKg: 61.23,
            enteredWeight: 135,
            enteredUnit: WeightUnit.lb),
        PreviousSet(setType: SetType.working, reps: 6, loadKg: 70),
      ], personalBests: const {PrMetric.maxWeight: 70});

      final sets = w.exercises.single.sets;
      expect(sets[0].enteredWeight, 135); // exact, not 134.99
      expect(sets[0].reps, 8);
      expect(sets[1].reps, 3); // user-touched: left alone
      expect(sets[1].enteredWeight, isNull);
      expect(sets[2].isEmpty, isTrue); // no matching previous set
      expect(w.exercises.single.personalBests[PrMetric.maxWeight], 70);
    });

    test('remove set re-indexes positions', () {
      var w = workoutOf([
        entry(bench, [
          doneSet('a', kg: 60, reps: 8),
          doneSet('b', kg: 70, reps: 6),
          doneSet('c', kg: 80, reps: 4),
        ]),
      ]);
      w = testEditor().removeSet(w, 'entry-ex-bench', 'b');
      expect(w.exercises.single.sets.map((s) => s.id), ['a', 'c']);

      final saved = WorkoutFinalizer.prepare(w, completedAt: now)
          .payload['exercises'] as List;
      final sets = (saved.single as Map)['sets'] as List;
      expect(sets.map((s) => (s as Map)['position']), [0, 1]);
      expect(sets.map((s) => (s as Map)['id']), ['a', 'c']);
    });

    test('canComplete follows the tracking type', () {
      const empty = LoggedSet(id: 'x');
      expect(WorkoutSessionEditor.canComplete(TrackingType.weightReps,
          empty.copyWith(reps: () => 5)), isFalse);
      expect(WorkoutSessionEditor.canComplete(TrackingType.weightReps,
          empty.copyWith(reps: () => 5, enteredWeight: () => 60)), isTrue);
      expect(WorkoutSessionEditor.canComplete(TrackingType.weightedBodyweight,
          empty.copyWith(reps: () => 5)), isTrue);
      expect(WorkoutSessionEditor.canComplete(TrackingType.duration,
          empty.copyWith(reps: () => 5)), isFalse);
    });
  });

  test('reorder moves an exercise', () {
    var w = workoutOf([entry(bench, []), entry(squat, []), entry(plank, [])]);
    w = testEditor().reorderExercise(w, 2, 0);
    expect(w.exercises.map((e) => e.exercise.id),
        ['ex-plank', 'ex-bench', 'ex-squat']);
  });
}
