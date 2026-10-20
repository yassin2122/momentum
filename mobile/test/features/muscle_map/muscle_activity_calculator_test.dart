import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/muscle_map/data/repositories/muscle_map_repository_impl.dart';
import 'package:grit/features/muscle_map/domain/entities/muscle.dart';
import 'package:grit/features/muscle_map/domain/entities/muscle_activity.dart';
import 'package:grit/features/muscle_map/domain/services/muscle_activity_calculator.dart';
import 'package:grit/features/muscle_map/domain/services/muscle_mapping.dart';

void main() {
  final now = DateTime(2026, 10, 18, 12);
  const links = {
    'bench': [
      MuscleLink(groupName: 'chest', isPrimary: true),
      MuscleLink(groupName: 'triceps', isPrimary: false),
      MuscleLink(groupName: 'shoulders', isPrimary: false),
    ],
    'squat': [
      MuscleLink(groupName: 'quadriceps', isPrimary: true),
      MuscleLink(groupName: 'glutes', isPrimary: false),
    ],
  };

  CompletedWorkoutRecord workout(String id, DateTime? at,
          List<(String, String, int)> exercises) =>
      CompletedWorkoutRecord(
        id: id,
        completedAt: at,
        exercises: [
          for (final (exId, name, sets) in exercises)
            LoggedExerciseRecord(
                exerciseId: exId, exerciseName: name, workingSets: sets),
        ],
      );

  MuscleActivityReport run(List<CompletedWorkoutRecord> w, {int days = 14}) =>
      MuscleActivityCalculator.compute(
        workouts: w,
        linksByExercise: links,
        now: now,
        windowDays: days,
      );

  test('counts primary and secondary sets separately', () {
    final r = run([
      workout('w1', now.subtract(const Duration(days: 1)),
          [('bench', 'Bench press', 4)]),
    ]);
    expect(r.byMuscle[Muscle.chest]!.primarySets, 4);
    expect(r.byMuscle[Muscle.chest]!.secondarySets, 0);
    expect(r.byMuscle[Muscle.triceps]!.secondarySets, 4);
    expect(r.byMuscle[Muscle.deltPosterior]!.secondarySets, 4);
    expect(r.byMuscle[Muscle.chest]!.load, 4);
    expect(r.byMuscle[Muscle.triceps]!.load, 2);
    expect(r.intensity(Muscle.chest), 1);
    expect(r.intensity(Muscle.triceps), 0.5);
    expect(r.intensity(Muscle.hamstrings), 0);
  });

  test('ignores incomplete workouts and ones outside the window', () {
    final r = run([
      workout('unfinished', null, [('bench', 'Bench press', 5)]),
      workout('old', now.subtract(const Duration(days: 20)),
          [('bench', 'Bench press', 5)]),
      workout('future', now.add(const Duration(hours: 1)),
          [('bench', 'Bench press', 5)]),
      workout('in', now.subtract(const Duration(days: 2)),
          [('squat', 'Squat', 3)]),
    ]);
    expect(r.workoutCount, 1);
    expect(r.byMuscle.containsKey(Muscle.chest), isFalse);
    expect(r.byMuscle[Muscle.quadriceps]!.primarySets, 3);
  });

  test('a longer window brings older workouts back in', () {
    final w = [
      workout('old', now.subtract(const Duration(days: 20)),
          [('bench', 'Bench press', 5)]),
    ];
    expect(run(w, days: 14).byMuscle, isEmpty);
    expect(run(w, days: 30).byMuscle[Muscle.chest]!.primarySets, 5);
  });

  test('tracks last trained, exercises and sessions newest first', () {
    final older = now.subtract(const Duration(days: 5));
    final newer = now.subtract(const Duration(days: 1));
    final r = run([
      workout('a', older, [('bench', 'Bench press', 3)]),
      workout('b', newer, [('bench', 'Incline bench', 2)]),
    ]);
    final chest = r.byMuscle[Muscle.chest]!;
    expect(chest.lastTrained, newer);
    expect(chest.sessions.map((s) => s.workoutId), ['b', 'a']);
    expect(chest.exerciseSets, {'Bench press': 3, 'Incline bench': 2});
  });

  test('reports exercises without muscle data and skips empty ones', () {
    final r = run([
      workout('w', now.subtract(const Duration(days: 1)), [
        ('mystery', 'Mystery move', 3),
        ('bench', 'Bench press', 0),
      ]),
    ]);
    expect(r.unmappedExercises, {'Mystery move'});
    expect(r.byMuscle, isEmpty);
    expect(r.maxLoad, 0);
  });

  group('row mapping', () {
    test('drops warm-up exercises and warm-up or unfinished sets', () {
      final rec = MuscleMapRepositoryImpl.workoutFromRow({
        'id': 'w1',
        'completed_at': '2026-10-17T10:00:00Z',
        'workout_log_exercises': [
          {
            'exercise_id': 'bench',
            'is_warmup': false,
            'exercises': {'name': 'Bench press'},
            'workout_log_sets': [
              {'completed': true, 'set_type': 'working'},
              {'completed': true, 'set_type': 'warmup'},
              {'completed': false, 'set_type': 'working'},
              {'completed': true, 'set_type': 'drop'},
            ],
          },
          {
            'exercise_id': 'squat',
            'is_warmup': true,
            'exercises': {'name': 'Squat'},
            'workout_log_sets': [
              {'completed': true, 'set_type': 'working'},
            ],
          },
        ],
      });
      expect(rec.exercises, hasLength(1));
      expect(rec.exercises.single.workingSets, 2);
      expect(rec.completedAt, isNotNull);
    });

    test('groups link rows by exercise and skips broken rows', () {
      final links = MuscleMapRepositoryImpl.linksFromRows([
        {'exercise_id': 'a', 'is_primary': true, 'muscle_groups': {'name': 'chest'}},
        {'exercise_id': 'a', 'is_primary': false, 'muscle_groups': {'name': 'triceps'}},
        {'exercise_id': 'b', 'is_primary': true, 'muscle_groups': null},
      ]);
      expect(links.keys, ['a']);
      expect(links['a']!.map((l) => l.groupName), ['chest', 'triceps']);
    });
  });
}
