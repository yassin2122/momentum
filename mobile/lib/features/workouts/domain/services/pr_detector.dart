import '../entities/active_workout.dart';
import '../entities/logged_set.dart';
import '../entities/trackable_exercise.dart';
import '../entities/workout_enums.dart';
import 'weight_units.dart';

/// A record beaten in this workout.
final class NewPersonalRecord {
  const NewPersonalRecord({
    required this.exercise,
    required this.metric,
    required this.value,
    this.previous,
  });

  final TrackableExercise exercise;
  final PrMetric metric;

  /// kg for weight metrics, reps, or seconds.
  final double value;
  final double? previous;
}

/// PR rules. The database trigger `check_and_update_personal_record`
/// (migration 20261016000001) applies the same rules and is what actually
/// writes `personal_records`; this class only drives the finish summary.
///
/// * Only completed WORKING sets count.
/// * `weight_reps`: heaviest weight, and best Epley e1RM
///   `w × (1 + reps / 30)` for sets of 1–10 reps.
/// * `weighted_bodyweight`: heaviest added weight.
/// * `bodyweight_reps`, `assisted_bodyweight`: most reps.
/// * `duration`: longest hold.
abstract final class PrDetector {
  static const int maxRepsFor1rm = 10;

  static double epley1rm(double weightKg, int reps) =>
      WeightUnits.round2(weightKg * (1 + reps / 30));

  /// Metric values one set achieves (empty if it can't count).
  static Map<PrMetric, double> candidates(TrackingType type, LoggedSet set) {
    if (!set.completed || set.setType != SetType.working) return const {};
    final load = set.loadKg;
    final reps = set.reps;
    final result = <PrMetric, double>{};
    void put(PrMetric metric, num? value) {
      if (value != null && value > 0) result[metric] = value.toDouble();
    }

    switch (type) {
      case TrackingType.weightReps:
        put(PrMetric.maxWeight, load);
        if (load != null &&
            reps != null &&
            reps >= 1 &&
            reps <= maxRepsFor1rm) {
          put(PrMetric.estimated1rm, epley1rm(load, reps));
        }
      case TrackingType.weightedBodyweight:
        put(PrMetric.maxWeight, load);
      case TrackingType.bodyweightReps:
      case TrackingType.assistedBodyweight:
        put(PrMetric.maxReps, reps);
      case TrackingType.duration:
        put(PrMetric.maxHoldSeconds, set.durationS);
    }
    return result;
  }

  /// Records in [exercises] that beat each exercise's
  /// [LoggedExercise.personalBests]. The same exercise logged twice is
  /// treated as one.
  static List<NewPersonalRecord> detect(List<LoggedExercise> exercises) {
    final best = <String, Map<PrMetric, double>>{};
    final previous = <String, Map<PrMetric, double>>{};
    final byId = <String, TrackableExercise>{};

    for (final entry in exercises) {
      final id = entry.exercise.id;
      byId[id] = entry.exercise;
      previous.putIfAbsent(id, () => entry.personalBests);
      final bucket = best.putIfAbsent(id, () => {});
      for (final set in entry.sets) {
        candidates(entry.exercise.trackingType, set).forEach((metric, value) {
          if (value > (bucket[metric] ?? 0)) bucket[metric] = value;
        });
      }
    }

    return [
      for (final id in best.keys)
        for (final e in best[id]!.entries)
          if (e.value > (previous[id]![e.key] ?? 0))
            NewPersonalRecord(
              exercise: byId[id]!,
              metric: e.key,
              value: e.value,
              previous: previous[id]![e.key],
            ),
    ];
  }
}
