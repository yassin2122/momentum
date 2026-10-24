import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/analytics/domain/entities/muscle_group_distribution.dart';
import 'package:grit/features/analytics/domain/services/muscle_group_distribution_calculator.dart';
import 'package:grit/features/muscle_map/domain/entities/muscle_activity.dart';
import 'package:grit/features/muscle_map/domain/services/muscle_mapping.dart';

void main() {
  final now = DateTime(2026, 10, 24, 18);
  const links = {
    'bench': [
      MuscleLink(groupName: 'chest', isPrimary: true),
      MuscleLink(groupName: 'triceps', isPrimary: false),
      MuscleLink(groupName: 'shoulders', isPrimary: false),
    ],
    'row': [
      MuscleLink(groupName: 'Middle_Back', isPrimary: true),
      MuscleLink(groupName: 'lats', isPrimary: true),
      MuscleLink(groupName: 'biceps', isPrimary: false),
    ],
    'squat': [
      MuscleLink(groupName: 'quads', isPrimary: true),
      MuscleLink(groupName: 'glutes', isPrimary: false),
    ],
    'mystery': [MuscleLink(groupName: 'spleen', isPrimary: true)],
  };

  CompletedWorkoutRecord w(String id, DateTime? at, List<(String, String, int)> ex) =>
      CompletedWorkoutRecord(
        id: id,
        completedAt: at,
        exercises: [
          for (final (exId, name, sets) in ex)
            LoggedExerciseRecord(exerciseId: exId, exerciseName: name, workingSets: sets),
        ],
      );

  MuscleGroupDistribution run(List<CompletedWorkoutRecord> workouts,
          [DistributionRange range = DistributionRange.weeks4]) =>
      MuscleGroupDistributionCalculator.compute(
        workouts: workouts,
        linksByExercise: links,
        range: range,
        now: now,
      );

  test('counts primary and assisting sets per library group', () {
    final d = run([
      w('a', now.subtract(const Duration(days: 1)),
          [('bench', 'Bench press', 4), ('row', 'Barbell row', 3)]),
    ]);
    expect(d.byGroup('chest')!.primarySets, 4);
    expect(d.byGroup('triceps')!.primarySets, 0);
    expect(d.byGroup('triceps')!.secondarySets, 4);
    expect(d.byGroup('middle back')!.primarySets, 3, reason: 'normalised name');
    expect(d.byGroup('lats')!.primarySets, 3);
    expect(d.workingSets, 7, reason: 'each set counted once overall');
    expect(d.totalPrimarySets, 10, reason: 'row hits two primary groups');
    expect(d.groups.first.group, 'chest');
  });

  test('aliases resolve to canonical groups', () {
    expect(MuscleGroupDistributionCalculator.canonicalGroup('Quads'), 'quadriceps');
    expect(MuscleGroupDistributionCalculator.canonicalGroup('upper back'), 'middle back');
    expect(MuscleGroupDistributionCalculator.canonicalGroup('spleen'), isNull);
  });

  test('skips unfinished and out-of-range workouts; reports unmapped', () {
    final d = run([
      w('unfinished', null, [('bench', 'Bench press', 5)]),
      w('old', now.subtract(const Duration(days: 40)), [('bench', 'Bench press', 5)]),
      w('ok', now.subtract(const Duration(days: 2)),
          [('squat', 'Squat', 5), ('mystery', 'Mystery move', 3)]),
    ]);
    expect(d.workoutCount, 1);
    expect(d.byGroup('chest'), isNull);
    expect(d.byGroup('quadriceps')!.primarySets, 5);
    expect(d.unmappedExercises, {'Mystery move'});
    expect(d.workingSets, 5);
  });

  test('regions split primary sets', () {
    final d = run([
      w('a', now.subtract(const Duration(days: 1)),
          [('bench', 'Bench', 4), ('squat', 'Squat', 6)]),
    ]);
    expect(d.regionSets[BodyRegion.upper], 4);
    expect(d.regionSets[BodyRegion.lower], 6);
    expect(d.regionSets[BodyRegion.core], 0);
    expect(d.shareOf(d.byGroup('quadriceps')!), closeTo(0.6, 1e-9));
  });

  test('7-day range buckets by day, 4 weeks by week, newest last', () {
    final today = w('t', now.subtract(const Duration(hours: 2)), [('bench', 'Bench', 3)]);
    final sixDays = w('s', now.subtract(const Duration(days: 6)), [('bench', 'Bench', 2)]);
    final daily = run([today, sixDays], DistributionRange.days7);
    expect(daily.bucketDays, 1);
    expect(daily.bucketStarts.length, 7);
    expect(daily.bucketStarts.last, DateTime(2026, 10, 24));
    expect(daily.byGroup('chest')!.bucketSets, [2, 0, 0, 0, 0, 0, 3]);

    final weekly = run([today, sixDays, w('x', now.subtract(const Duration(days: 20)), [('bench', 'Bench', 1)])]);
    expect(weekly.bucketDays, 7);
    expect(weekly.bucketStarts.length, 4);
    expect(weekly.byGroup('chest')!.bucketSets, [0, 1, 0, 5]);
  });

  test('sessions are newest first with per-workout sets', () {
    final d = run([
      w('old', now.subtract(const Duration(days: 5)), [('bench', 'Bench', 2)]),
      w('new', now.subtract(const Duration(days: 1)), [('bench', 'Bench', 3)]),
    ]);
    final chest = d.byGroup('chest')!;
    expect(chest.sessions.map((s) => s.workoutId), ['new', 'old']);
    expect(chest.sessions.first.sets, 3);
    expect(chest.lastTrained, now.subtract(const Duration(days: 1)));
  });

  test('empty input is empty, not an error', () {
    final d = run(const []);
    expect(d.isEmpty, isTrue);
    expect(d.totalPrimarySets, 0);
  });
}
