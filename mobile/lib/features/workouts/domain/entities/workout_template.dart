import 'trackable_exercise.dart';

/// A `workout_templates` row with its exercises in order.
final class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.exercises,
  });

  final String id;
  final String name;
  final List<TemplateExercise> exercises;
}

/// A `workout_template_exercises` row.
final class TemplateExercise {
  const TemplateExercise({required this.exercise, this.defaultSets});

  final TrackableExercise exercise;

  /// `target_sets`; the logger starts with this many sets (min 1).
  final int? defaultSets;
}
