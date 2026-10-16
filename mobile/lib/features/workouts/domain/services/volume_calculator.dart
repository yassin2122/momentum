import '../entities/active_workout.dart';
import '../entities/logged_set.dart';
import '../entities/workout_enums.dart';
import 'effective_load.dart';
import 'weight_units.dart';

/// Volume = Σ(effective load × reps) over completed WORKING sets only.
/// Warm-up and drop sets never count.
abstract final class VolumeCalculator {
  static bool counts(LoggedSet set) =>
      set.completed && set.setType == SetType.working;

  static double exerciseVolume(LoggedExercise entry, {double? bodyweightKg}) {
    var total = 0.0;
    for (final set in entry.sets) {
      if (!counts(set) || set.reps == null) continue;
      final load = EffectiveLoad.of(
        exercise: entry.exercise,
        set: set,
        bodyweightKg: bodyweightKg,
      );
      if (load == null) continue;
      total += load * set.reps!;
    }
    return WeightUnits.round2(total);
  }

  static double workoutVolume(
    List<LoggedExercise> exercises, {
    double? bodyweightKg,
  }) =>
      WeightUnits.round2(exercises.fold(
        0.0,
        (sum, e) => sum + exerciseVolume(e, bodyweightKg: bodyweightKg),
      ));

  static int completedWorkingSets(List<LoggedExercise> exercises) => exercises
      .expand((e) => e.sets)
      .where(counts)
      .length;
}
