import '../entities/logged_set.dart';
import '../entities/trackable_exercise.dart';
import '../entities/workout_enums.dart';
import 'weight_units.dart';

/// The load actually moved in one rep, in kg.
///
/// * `weight_reps`: the weight on the bar.
/// * bodyweight types: `bodyweight × bw_factor + added − assist`
///   (never below 0). With no bodyweight on record, bodyweight counts as 0,
///   so only the added load contributes.
/// * `duration`: no load (null).
abstract final class EffectiveLoad {
  static double? of({
    required TrackableExercise exercise,
    required LoggedSet set,
    double? bodyweightKg,
  }) {
    final load = set.loadKg;
    final bodyPart = (bodyweightKg ?? 0) * exercise.bwFactor;
    final value = switch (exercise.trackingType) {
      TrackingType.weightReps => load,
      TrackingType.bodyweightReps => bodyPart,
      TrackingType.weightedBodyweight => bodyPart + (load ?? 0),
      TrackingType.assistedBodyweight => bodyPart - (load ?? 0),
      TrackingType.duration => null,
    };
    if (value == null) return null;
    return WeightUnits.round2(value < 0 ? 0 : value);
  }
}
