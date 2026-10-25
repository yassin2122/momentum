import 'package:flutter_test/flutter_test.dart';
import 'package:grit/features/analytics/data/models/analytics_rows.dart';
import 'package:grit/features/analytics/domain/entities/body_progress.dart';
import 'package:grit/features/analytics/domain/services/body_trend.dart';

BodyEntry e(String id, DateTime day, Map<BodyMeasure, double> v, {DateTime? created}) =>
    BodyEntry(id: id, loggedOn: day, values: v, createdAt: created ?? day);

void main() {
  final entries = [
    e('3', DateTime(2026, 10, 20), {BodyMeasure.weight: 80, BodyMeasure.waist: 84}),
    e('2b', DateTime(2026, 10, 10), {BodyMeasure.weight: 82},
        created: DateTime(2026, 10, 10, 20)),
    e('2a', DateTime(2026, 10, 10), {BodyMeasure.weight: 83},
        created: DateTime(2026, 10, 10, 8)),
    e('1', DateTime(2026, 10, 1), {BodyMeasure.weight: 84}),
  ];

  test('series is oldest first, one point per day, latest save wins', () {
    final s = BodyTrend.series(entries, BodyMeasure.weight);
    expect(s.map((p) => p.value), [84, 82, 80]);
    expect(BodyTrend.series(entries, BodyMeasure.waist).single.value, 84);
    expect(BodyTrend.series(entries, BodyMeasure.weight, since: DateTime(2026, 10, 5))
        .map((p) => p.value), [82, 80]);
  });

  test('change, latest and recorded measures', () {
    final s = BodyTrend.series(entries, BodyMeasure.weight);
    expect(BodyTrend.change(s), -4);
    expect(BodyTrend.change(s.take(1).toList()), isNull);
    expect(BodyTrend.latest(entries, BodyMeasure.weight)!.value, 80);
    expect(BodyTrend.recorded(entries), [BodyMeasure.weight, BodyMeasure.waist]);
  });

  test('rolling average only uses real points inside the window', () {
    final pts = [
      TrendPoint(DateTime(2026, 10, 1), 80),
      TrendPoint(DateTime(2026, 10, 3), 82),
      TrendPoint(DateTime(2026, 10, 20), 70),
    ];
    final avg = BodyTrend.rollingAverage(pts);
    expect(avg[0].value, 80);
    expect(avg[1].value, 81);
    expect(avg[2].value, 70, reason: 'earlier points are outside 7 days');
  });

  group('goal progress', () {
    test('uses the saved start weight', () {
      final g = BodyGoal(
          targetWeightKg: 76, startWeightKg: 84, createdAt: DateTime(2026, 10, 1));
      final p = BodyTrend.goalProgress(g, entries)!;
      expect(p.isLosing, isTrue);
      expect(p.fraction, closeTo(0.5, 1e-9));
      expect(p.remaining, 4);
      expect(p.reached, isFalse);
    });

    test('falls back to first weigh-in after the goal was set', () {
      final g = BodyGoal(targetWeightKg: 78, createdAt: DateTime(2026, 10, 5, 9));
      final p = BodyTrend.goalProgress(g, entries)!;
      expect(p.start, 82);
    });

    test('gaining goal, passing target clamps to reached', () {
      final g = BodyGoal(
          targetWeightKg: 79, startWeightKg: 75, createdAt: DateTime(2026, 9, 1));
      final p = BodyTrend.goalProgress(g, entries)!;
      expect(p.isLosing, isFalse);
      expect(p.fraction, 1);
      expect(p.reached, isTrue);
    });

    test('moving away from target counts as zero progress', () {
      final g = BodyGoal(
          targetWeightKg: 90, startWeightKg: 85, createdAt: DateTime(2026, 9, 1));
      expect(BodyTrend.goalProgress(g, entries)!.fraction, 0);
    });

    test('null without goal or weights', () {
      expect(BodyTrend.goalProgress(null, entries), isNull);
      expect(
          BodyTrend.goalProgress(
              BodyGoal(targetWeightKg: 70, createdAt: DateTime(2026)), const []),
          isNull);
    });
  });

  group('rows', () {
    test('entry row maps measures, drops blank note, keeps local date', () {
      final row = AnalyticsRows.entryRow(NewBodyEntry(
        loggedOn: DateTime(2026, 3, 7),
        values: {BodyMeasure.weight: 80.5, BodyMeasure.arm: 38},
        note: '  ',
      ));
      expect(row, {'logged_at': '2026-03-07', 'weight_kg': 80.5, 'arm_cm': 38.0});
    });

    test('entry from row reads only present measures', () {
      final entry = AnalyticsRows.entry({
        'id': 'x',
        'logged_at': '2026-10-02',
        'weight_kg': 81.25,
        'waist_cm': null,
        'body_fat_pct': 15,
        'created_at': '2026-10-02T06:00:00Z',
      });
      expect(entry.loggedOn, DateTime(2026, 10, 2));
      expect(entry.values, {BodyMeasure.weight: 81.25, BodyMeasure.bodyFat: 15.0});
    });

    test('goal without a target is ignored', () {
      expect(AnalyticsRows.goal(null), isNull);
      expect(AnalyticsRows.goal({'target_weight_kg': null}), isNull);
      expect(AnalyticsRows.goal({
        'target_weight_kg': 75,
        'start_weight_kg': 80,
        'target_date': '2027-01-31',
        'created_at': '2026-10-01T00:00:00Z',
      })!.targetDate, DateTime(2027, 1, 31));
    });

    test('photo pose falls back to other', () {
      expect(PhotoPose.fromDb('side'), PhotoPose.side);
      expect(PhotoPose.fromDb('weird'), PhotoPose.other);
    });
  });
}
