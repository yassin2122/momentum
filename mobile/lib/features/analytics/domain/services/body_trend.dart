import '../entities/body_progress.dart';

/// One point on a body-metric chart.
final class TrendPoint {
  const TrendPoint(this.date, this.value);

  final DateTime date;
  final double value;
}

/// Progress toward the bodyweight goal.
final class GoalProgress {
  const GoalProgress({
    required this.start,
    required this.current,
    required this.target,
  });

  final double start;
  final double current;
  final double target;

  bool get isLosing => target < start;

  /// 0–1 of the way from [start] to [target]; moving away counts as 0.
  double get fraction {
    final span = target - start;
    if (span == 0) return current == target ? 1 : 0;
    return ((current - start) / span).clamp(0.0, 1.0);
  }

  /// Distance still to go (always ≥ 0; 0 once reached or passed).
  double get remaining {
    final left = isLosing ? current - target : target - current;
    return left < 0 ? 0 : left;
  }

  bool get reached => remaining == 0;
}

/// Pure helpers for the Body progress screen. Everything is derived from
/// the athlete's own logged entries — nothing is estimated or filled in.
abstract final class BodyTrend {
  /// The measure's values oldest → newest, one per calendar day (the most
  /// recently saved entry of a day wins), optionally from [since].
  static List<TrendPoint> series(
    List<BodyEntry> entries,
    BodyMeasure measure, {
    DateTime? since,
  }) {
    final byDay = <DateTime, BodyEntry>{};
    for (final e in entries) {
      final v = e[measure];
      if (v == null) continue;
      final day = DateTime(e.loggedOn.year, e.loggedOn.month, e.loggedOn.day);
      if (since != null && day.isBefore(since)) continue;
      final prev = byDay[day];
      if (prev == null || e.createdAt.isAfter(prev.createdAt)) byDay[day] = e;
    }
    final days = byDay.keys.toList()..sort();
    return [for (final d in days) TrendPoint(d, byDay[d]![measure]!)];
  }

  /// Trailing average over the previous [windowDays] calendar days at each
  /// point — smooths day-to-day water swings without inventing points.
  static List<TrendPoint> rollingAverage(
    List<TrendPoint> points, {
    int windowDays = 7,
  }) {
    final out = <TrendPoint>[];
    for (var i = 0; i < points.length; i++) {
      final d = points[i].date;
      final from = DateTime(d.year, d.month, d.day - (windowDays - 1));
      var sum = 0.0;
      var n = 0;
      for (var j = i; j >= 0 && !points[j].date.isBefore(from); j--) {
        sum += points[j].value;
        n++;
      }
      out.add(TrendPoint(d, sum / n));
    }
    return out;
  }

  /// Latest recorded value of [measure], or null.
  static TrendPoint? latest(List<BodyEntry> entries, BodyMeasure measure) {
    final s = series(entries, measure);
    return s.isEmpty ? null : s.last;
  }

  /// Change from the first to the last point; null with fewer than two.
  static double? change(List<TrendPoint> points) =>
      points.length < 2 ? null : points.last.value - points.first.value;

  /// Measures that have at least one value, in [BodyMeasure] order.
  static List<BodyMeasure> recorded(List<BodyEntry> entries) => [
        for (final m in BodyMeasure.values)
          if (entries.any((e) => e[m] != null)) m,
      ];

  /// Goal progress, or null without a goal or any bodyweight. The origin is
  /// the goal's saved start weight, else the first weight logged on or
  /// after the goal was set, else the earliest weight on record.
  static GoalProgress? goalProgress(BodyGoal? goal, List<BodyEntry> entries) {
    if (goal == null) return null;
    final weights = series(entries, BodyMeasure.weight);
    if (weights.isEmpty) return null;
    final setOn = DateTime(
        goal.createdAt.year, goal.createdAt.month, goal.createdAt.day);
    final start = goal.startWeightKg ??
        weights
            .firstWhere((p) => !p.date.isBefore(setOn),
                orElse: () => weights.first)
            .value;
    return GoalProgress(
      start: start,
      current: weights.last.value,
      target: goal.targetWeightKg,
    );
  }
}
