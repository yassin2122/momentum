/// One `recovery_checkins` row. Scales are 1–5:
/// soreness 1 = none … 5 = very sore; energy 1 = very low … 5 = high;
/// fatigue 1 = fresh … 5 = exhausted; sleep quality 1 = poor … 5 = great.
final class RecoveryCheckin {
  const RecoveryCheckin({
    required this.date,
    required this.sleepHours,
    required this.soreness,
    required this.energy,
    required this.fatigue,
    this.id,
    this.sleepQuality,
    this.note,
  });

  /// Null for a check-in that hasn't been saved yet.
  final String? id;

  /// Local calendar date.
  final DateTime date;
  final double sleepHours;
  final int? sleepQuality;
  final int soreness;
  final int energy;
  final int fatigue;
  final String? note;
}

/// Completed training on one local day.
final class DailyTrainingLoad {
  const DailyTrainingLoad({
    required this.date,
    required this.workouts,
    required this.workingSets,
  });

  final DateTime date;
  final int workouts;
  final int workingSets;
}

enum InsightTone { info, caution, positive }

/// A plain-language pattern in the athlete's own logs. [basis] says
/// exactly which numbers it came from, so nothing is a black box.
final class RecoveryInsight {
  const RecoveryInsight({
    required this.tone,
    required this.title,
    required this.detail,
    required this.basis,
  });

  final InsightTone tone;
  final String title;
  final String detail;
  final String basis;
}

/// Everything the Recovery screen shows.
final class RecoveryOverview {
  const RecoveryOverview({
    required this.today,
    required this.checkins,
    required this.loads,
    required this.insights,
  });

  /// Today's check-in, if done.
  final RecoveryCheckin? today;

  /// Newest first, last 28 days.
  final List<RecoveryCheckin> checkins;

  /// One per day for the last 14 days, oldest first (zeros included).
  final List<DailyTrainingLoad> loads;
  final List<RecoveryInsight> insights;
}
