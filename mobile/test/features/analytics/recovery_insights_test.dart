import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/analytics/data/models/analytics_rows.dart';
import 'package:grit/features/analytics/domain/entities/recovery.dart';
import 'package:grit/features/analytics/domain/services/recovery_insights.dart';
import 'package:grit/features/muscle_map/domain/entities/muscle_activity.dart';

void main() {
  final today = DateTime(2026, 10, 24);
  DateTime ago(int d) => DateTime(today.year, today.month, today.day - d);

  RecoveryCheckin c(int daysAgo,
          {double sleep = 7.5, int sore = 2, int energy = 3, int fatigue = 3}) =>
      RecoveryCheckin(
        date: ago(daysAgo),
        sleepHours: sleep,
        soreness: sore,
        energy: energy,
        fatigue: fatigue,
      );

  CompletedWorkoutRecord w(int daysAgo, int sets) => CompletedWorkoutRecord(
        id: 'w$daysAgo-$sets',
        completedAt: ago(daysAgo).add(const Duration(hours: 18)),
        exercises: [
          LoggedExerciseRecord(exerciseId: 'e', exerciseName: 'E', workingSets: sets),
        ],
      );

  List<RecoveryInsight> run(List<RecoveryCheckin> checkins,
          [List<CompletedWorkoutRecord> workouts = const []]) =>
      RecoveryInsights.compute(checkins: checkins, workouts: workouts, today: today);

  bool has(List<RecoveryInsight> i, String title) => i.any((x) => x.title == title);

  test('too few check-ins gives a neutral prompt, no patterns', () {
    final i = run([c(0, sore: 5), c(1, sore: 5)]);
    expect(i.single.tone, InsightTone.info);
    expect(i.single.basis, contains('2 of 3'));
  });

  test('sleep below own baseline is flagged with its numbers', () {
    final i = run([
      c(0, sleep: 5.5), c(1, sleep: 6), c(2, sleep: 5.5),
      c(8, sleep: 8), c(9, sleep: 7.5), c(10, sleep: 8),
    ]);
    final s = i.firstWhere((x) => x.title == 'Sleeping less than your usual');
    expect(s.tone, InsightTone.caution);
    expect(s.basis, contains('5.7 h'));
    expect(s.basis, contains('7.8 h'));
  });

  test('short sleep without a baseline', () {
    expect(has(run([c(0, sleep: 5), c(1, sleep: 5.5), c(3, sleep: 5)]),
        'Short sleep this week'), isTrue);
  });

  test('three close high-soreness check-ins are flagged', () {
    expect(has(run([c(0, sore: 4), c(1, sore: 5), c(2, sore: 4)]),
        'Soreness has stayed high'), isTrue);
    // Spread over more than 4 days: not a run.
    expect(has(run([c(0, sore: 4), c(3, sore: 5), c(9, sore: 4)]),
        'Soreness has stayed high'), isFalse);
  });

  test('low energy + high fatigue today only uses today', () {
    expect(has(run([c(0, energy: 2, fatigue: 4), c(1), c(2)]),
        'Low energy, high fatigue today'), isTrue);
    expect(has(run([c(1, energy: 1, fatigue: 5), c(2), c(3)]),
        'Low energy, high fatigue today'), isFalse);
  });

  test('feeling fresh is positive', () {
    final i = run([
      c(0, energy: 4, fatigue: 1, sore: 1),
      c(1, energy: 5, fatigue: 2, sore: 2),
      c(2, energy: 4, fatigue: 2, sore: 1),
    ]);
    expect(i.firstWhere((x) => x.title == 'Feeling fresh').tone, InsightTone.positive);
  });

  test('volume jump vs the three weeks before', () {
    final checkins = [c(0), c(1), c(2)];
    final jump = run(checkins, [w(1, 30), w(3, 20), w(9, 10), w(16, 10), w(23, 10)]);
    expect(has(jump, 'Training volume jumped this week'), isTrue);
    final light = run(checkins, [w(1, 4), w(9, 20), w(16, 20), w(23, 20)]);
    expect(has(light, 'A lighter week'), isTrue);
    // No baseline → nothing claimed.
    final none = run(checkins, [w(1, 40)]);
    expect(has(none, 'Training volume jumped this week'), isFalse);
  });

  test('daily loads are zero-filled, oldest first, ending today', () {
    final loads = RecoveryInsights.dailyLoads([w(0, 5), w(0, 3), w(13, 2), w(20, 9)], today: today);
    expect(loads.length, 14);
    expect(loads.last.date, today);
    expect(loads.last.workingSets, 8);
    expect(loads.last.workouts, 2);
    expect(loads.first.date, ago(13));
    expect(loads.first.workingSets, 2);
  });

  test('check-in row round trip', () {
    final row = AnalyticsRows.checkinRow(RecoveryCheckin(
      date: DateTime(2026, 1, 5),
      sleepHours: 6.5,
      soreness: 3,
      energy: 4,
      fatigue: 2,
      note: ' ',
    ));
    expect(row['checkin_date'], '2026-01-05');
    expect(row['note'], isNull);
    final back = AnalyticsRows.checkin({...row, 'id': 'id1'})!;
    expect(back.sleepHours, 6.5);
    expect(back.energy, 4);
    expect(AnalyticsRows.checkin({'checkin_date': '2026-01-05'}), isNull);
  });
}
