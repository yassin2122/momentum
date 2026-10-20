import '../entities/muscle.dart';
import 'muscle_mapping.dart';

/// Turns exercise muscle data into body-map highlight intensities (0–1).
///
/// Everything comes from the library's `exercise_muscle_groups` links via
/// [MuscleMapping]; an exercise with no links lights nothing.
abstract final class MuscleHighlight {
  /// Glow for a primary target.
  static const double primary = 1.0;

  /// Glow for a secondary (assisting) muscle.
  static const double secondary = 0.4;

  /// Ceiling for the rest of a workout while one exercise is focused, so
  /// the focused exercise always reads brightest.
  static const double context = 0.25;

  /// Primary muscles full, secondary dimmer.
  static Map<Muscle, double> fromInvolvement(Map<Muscle, Involvement> m) => {
        for (final e in m.entries)
          e.key: e.value == Involvement.primary ? primary : secondary,
      };

  /// Highlight for one exercise.
  static Map<Muscle, double> forExercise(Iterable<MuscleLink> links) =>
      fromInvolvement(MuscleMapping.involvement(links));

  /// Highlight for a whole workout or template. With [focusExerciseId]
  /// (an exercise in the workout) that exercise lights normally and the
  /// rest of the workout stays faint context; without it every exercise
  /// lights normally. The brighter value wins where exercises overlap.
  static Map<Muscle, double> forWorkout({
    required Iterable<String> exerciseIds,
    required Map<String, List<MuscleLink>> linksByExercise,
    String? focusExerciseId,
  }) {
    final out = <Muscle, double>{};
    void merge(Map<Muscle, double> m, {double cap = 1}) {
      m.forEach((muscle, v) {
        final value = v < cap ? v : cap;
        if (value > (out[muscle] ?? 0)) out[muscle] = value;
      });
    }

    for (final id in exerciseIds) {
      final m = forExercise(linksByExercise[id] ?? const []);
      final focused = focusExerciseId == null || id == focusExerciseId;
      merge(m, cap: focused ? 1 : context);
    }
    return out;
  }

  /// Highlighted muscles the body map can't draw (e.g. lower back), so a
  /// screen can name them instead of silently showing nothing.
  static Set<Muscle> undrawn(Map<Muscle, double> intensities) => {
        for (final e in intensities.entries)
          if (e.value > 0 && e.key.views.isEmpty) e.key,
      };

  /// The side showing the most highlight; front on a tie or when empty.
  static BodyView bestView(Map<Muscle, double> intensities) {
    var front = 0.0, back = 0.0;
    intensities.forEach((m, v) {
      if (m.views.contains(BodyView.front)) front += v;
      if (m.views.contains(BodyView.back)) back += v;
    });
    return back > front ? BodyView.back : BodyView.front;
  }
}
