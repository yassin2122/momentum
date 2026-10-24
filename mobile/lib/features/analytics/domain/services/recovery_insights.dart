import '../../../muscle_map/domain/entities/muscle_activity.dart';
import '../entities/recovery.dart';

/// Simple, transparent rules over the athlete's own check-ins and logged
/// training. Each insight states the numbers behind it. These are
/// patterns, not assessments: nothing here diagnoses overtraining or
/// claims to measure readiness.
abstract final class RecoveryInsights {
  static const String disclaimer =
      'These are simple patterns in what you have logged, not a medical '
      'or performance assessment. Grit can\'t diagnose overtraining or '
      'measure readiness. If pain or exhaustion persists, talk to a '
      'qualified professional.';

  /// Check-ins needed before any pattern is shown.
  static const int minCheckins = 3;

  /// Days from [from] to [to] as whole calendar days (DST-safe).
  static int daysBetween(DateTime from, DateTime to) =>
      DateTime.utc(to.year, to.month, to.day)
          .difference(DateTime.utc(from.year, from.month, from.day))
          .inDays;

  /// Completed working sets per local day for the [days] days ending
  /// [today], oldest first, zero-filled.
  static List<DailyTrainingLoad> dailyLoads(
    List<CompletedWorkoutRecord> workouts, {
    required DateTime today,
    int days = 14,
  }) {
    final sets = List<int>.filled(days, 0);
    final count = List<int>.filled(days, 0);
    for (final w in workouts) {
      final done = w.completedAt;
      if (done == null) continue;
      final ago = daysBetween(done, today);
      if (ago < 0 || ago >= days) continue;
      final i = days - 1 - ago;
      count[i]++;
      for (final e in w.exercises) {
        sets[i] += e.workingSets;
      }
    }
    return [
      for (var i = 0; i < days; i++)
        DailyTrainingLoad(
          date: DateTime(today.year, today.month, today.day - (days - 1 - i)),
          workouts: count[i],
          workingSets: sets[i],
        ),
    ];
  }

  static String _h(double v) {
    final r = (v * 10).round() / 10;
    return r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);
  }

  /// [checkins] newest first; [workouts] should cover the last 28 days.
  static List<RecoveryInsight> compute({
    required List<RecoveryCheckin> checkins,
    required List<CompletedWorkoutRecord> workouts,
    required DateTime today,
  }) {
    final out = <RecoveryInsight>[];
    final recent = checkins
        .where((c) => daysBetween(c.date, today) >= 0 && daysBetween(c.date, today) < 28)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    if (recent.length < minCheckins) {
      out.add(RecoveryInsight(
        tone: InsightTone.info,
        title: 'Patterns appear after a few check-ins',
        detail: 'Check in on $minCheckins or more days and this space will '
            'point out trends in your sleep, soreness and energy.',
        basis: '${recent.length} of $minCheckins check-ins in the last 28 days',
      ));
    } else {
      _sleep(recent, today, out);
      _soreness(recent, today, out);
      _todayState(recent, today, out);
      _feelingFresh(recent, out);
    }
    _load(workouts, today, out);
    return out;
  }

  static void _sleep(
      List<RecoveryCheckin> recent, DateTime today, List<RecoveryInsight> out) {
    final last7 = recent.where((c) => daysBetween(c.date, today) < 7).toList();
    final before = recent.where((c) => daysBetween(c.date, today) >= 7).toList();
    if (last7.length < minCheckins) return;
    final avg7 =
        last7.fold<double>(0, (s, c) => s + c.sleepHours) / last7.length;
    if (before.length >= minCheckins) {
      final base =
          before.fold<double>(0, (s, c) => s + c.sleepHours) / before.length;
      if (avg7 <= base - 0.75) {
        out.add(RecoveryInsight(
          tone: InsightTone.caution,
          title: 'Sleeping less than your usual',
          detail: 'This week\'s sleep is below your own recent average. '
              'Shorter sleep can make training feel harder.',
          basis: 'Avg ${_h(avg7)} h over ${last7.length} check-ins this week '
              'vs ${_h(base)} h over ${before.length} earlier check-ins',
        ));
        return;
      }
    }
    if (avg7 < 6) {
      out.add(RecoveryInsight(
        tone: InsightTone.caution,
        title: 'Short sleep this week',
        detail: 'Your logged sleep has averaged under 6 hours this week.',
        basis: 'Avg ${_h(avg7)} h over ${last7.length} check-ins in the last 7 days',
      ));
    }
  }

  static void _soreness(
      List<RecoveryCheckin> recent, DateTime today, List<RecoveryInsight> out) {
    final last3 = recent.take(3).toList();
    if (last3.length < 3) return;
    final spanDays = daysBetween(last3.last.date, last3.first.date);
    if (spanDays > 4) return; // only a recent, close-together run counts
    if (last3.every((c) => c.soreness >= 4)) {
      out.add(const RecoveryInsight(
        tone: InsightTone.caution,
        title: 'Soreness has stayed high',
        detail: 'You\'ve reported high soreness on your last three '
            'check-ins. Lighter work for the sore areas may help; get '
            'persistent or sharp pain checked by a professional.',
        basis: 'Soreness 4–5 of 5 on the last 3 check-ins',
      ));
    }
  }

  static void _todayState(
      List<RecoveryCheckin> recent, DateTime today, List<RecoveryInsight> out) {
    final latest = recent.first;
    if (daysBetween(latest.date, today) > 0) return;
    if (latest.energy <= 2 && latest.fatigue >= 4) {
      out.add(RecoveryInsight(
        tone: InsightTone.caution,
        title: 'Low energy, high fatigue today',
        detail: 'If you train today, an easier session is a reasonable '
            'choice. How you feel is the best guide.',
        basis: 'Today: energy ${latest.energy}/5, fatigue ${latest.fatigue}/5',
      ));
    }
  }

  static void _feelingFresh(
      List<RecoveryCheckin> recent, List<RecoveryInsight> out) {
    final last3 = recent.take(3).toList();
    if (last3.length < 3) return;
    if (last3.every((c) => c.energy >= 4 && c.fatigue <= 2 && c.soreness <= 2)) {
      out.add(const RecoveryInsight(
        tone: InsightTone.positive,
        title: 'Feeling fresh',
        detail: 'Your last three check-ins show good energy with low '
            'fatigue and soreness.',
        basis: 'Energy ≥ 4, fatigue ≤ 2, soreness ≤ 2 on the last 3 check-ins',
      ));
    }
  }

  static void _load(List<CompletedWorkoutRecord> workouts, DateTime today,
      List<RecoveryInsight> out) {
    var thisWeek = 0;
    var earlier = 0;
    var earlierWorkouts = 0;
    for (final w in workouts) {
      final done = w.completedAt;
      if (done == null) continue;
      final ago = daysBetween(done, today);
      if (ago < 0 || ago >= 28) continue;
      final sets = w.exercises.fold<int>(0, (s, e) => s + e.workingSets);
      if (ago < 7) {
        thisWeek += sets;
      } else {
        earlier += sets;
        earlierWorkouts++;
      }
    }
    // Need a real baseline: some training in the 3 weeks before.
    if (earlierWorkouts < 2 || earlier == 0) return;
    final weeklyAvg = earlier / 3;
    final ratio = thisWeek / weeklyAvg;
    final basis = '$thisWeek working sets in the last 7 days vs '
        '${weeklyAvg.round()} per week over the 3 weeks before';
    if (ratio >= 1.5) {
      out.add(RecoveryInsight(
        tone: InsightTone.caution,
        title: 'Training volume jumped this week',
        detail: 'You\'ve done noticeably more than usual. Big jumps are '
            'easier to absorb with good sleep and some easier days.',
        basis: basis,
      ));
    } else if (ratio <= 0.5) {
      out.add(RecoveryInsight(
        tone: InsightTone.info,
        title: 'A lighter week',
        detail: 'Your volume is well below your recent weeks — planned '
            'deload or a break, either is fine.',
        basis: basis,
      ));
    }
  }
}
