/// Enums shared by the TRAIN workout logger. Each one mirrors a Postgres
/// enum from migration 20261016000001_train_workout_logging.sql; [dbValue]
/// is the exact database label.
library;

/// What a set records for an exercise (`tracking_type`).
enum TrackingType {
  weightReps('weight_reps'),
  bodyweightReps('bodyweight_reps'),
  weightedBodyweight('weighted_bodyweight'),
  assistedBodyweight('assisted_bodyweight'),
  duration('duration');

  const TrackingType(this.dbValue);

  final String dbValue;

  static TrackingType fromDb(String? value) => TrackingType.values.firstWhere(
        (t) => t.dbValue == value,
        orElse: () => TrackingType.weightReps,
      );

  /// Bodyweight types use `bw_factor` and the bodyweight snapshot.
  bool get isBodyweight =>
      this == bodyweightReps ||
      this == weightedBodyweight ||
      this == assistedBodyweight;

  /// Whether a set has a weight-like input (weight, added or assist kg).
  bool get hasLoadInput =>
      this == weightReps ||
      this == weightedBodyweight ||
      this == assistedBodyweight;

  bool get hasReps => this != duration;

  String get label => switch (this) {
        weightReps => 'Weight & reps',
        bodyweightReps => 'Bodyweight reps',
        weightedBodyweight => 'Weighted bodyweight',
        assistedBodyweight => 'Assisted bodyweight',
        duration => 'Duration',
      };

  /// Header for the load column in the set table.
  String get loadLabel => switch (this) {
        weightedBodyweight => '+ Added',
        assistedBodyweight => '− Assist',
        _ => 'Weight',
      };
}

/// Set category (`set_type`). Only [working] sets count toward volume and PRs.
enum SetType {
  warmup('warmup', 'Warm-up', 'W'),
  working('working', 'Working', '•'),
  drop('drop', 'Drop set', 'D');

  const SetType(this.dbValue, this.label, this.shortLabel);

  final String dbValue;
  final String label;
  final String shortLabel;

  static SetType fromDb(String? value) => SetType.values.firstWhere(
        (t) => t.dbValue == value,
        orElse: () => SetType.working,
      );
}

/// Weight unit (`weight_unit`).
enum WeightUnit {
  kg('kg'),
  lb('lb');

  const WeightUnit(this.dbValue);

  final String dbValue;

  static WeightUnit fromDb(String? value) =>
      value == 'lb' ? WeightUnit.lb : WeightUnit.kg;

  WeightUnit get other => this == kg ? lb : kg;
}

/// Personal-record metric (`pr_metric_type`).
enum PrMetric {
  maxWeight('max_weight', 'Heaviest weight'),
  estimated1rm('estimated_1rm', 'Best est. 1RM'),
  maxReps('max_reps', 'Most reps'),
  maxHoldSeconds('max_hold_seconds', 'Longest hold');

  const PrMetric(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static PrMetric? fromDb(String? value) {
    for (final m in PrMetric.values) {
      if (m.dbValue == value) return m;
    }
    return null;
  }

  /// Whether the metric's value is a weight in kg (vs reps / seconds).
  bool get isWeight => this == maxWeight || this == estimated1rm;
}
