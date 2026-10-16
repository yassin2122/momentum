import '../entities/active_workout.dart';
import '../entities/logged_set.dart';
import '../entities/workout_enums.dart';
import 'pr_detector.dart';
import 'volume_calculator.dart';
import 'workout_session_editor.dart';

/// What the finish screen shows.
final class WorkoutSummary {
  const WorkoutSummary({
    required this.workoutId,
    required this.title,
    required this.duration,
    required this.completedWorkingSets,
    required this.volumeKg,
    required this.newRecords,
    required this.synced,
  });

  final String workoutId;
  final String title;
  final Duration duration;
  final int completedWorkingSets;
  final double volumeKg;
  final List<NewPersonalRecord> newRecords;

  /// False while the workout is waiting in the offline retry queue.
  final bool synced;

  WorkoutSummary copyWith({bool? synced, double? volumeKg}) => WorkoutSummary(
        workoutId: workoutId,
        title: title,
        duration: duration,
        completedWorkingSets: completedWorkingSets,
        volumeKg: volumeKg ?? this.volumeKg,
        newRecords: newRecords,
        synced: synced ?? this.synced,
      );
}

/// Result of [WorkoutFinalizer.prepare].
final class FinishPreparation {
  const FinishPreparation({
    required this.workout,
    required this.payload,
    required this.hasCompletedSets,
  });

  /// The workout with empty, uncompleted sets dropped.
  final ActiveWorkout workout;

  /// Body for the `finish_workout` RPC.
  final Map<String, dynamic> payload;
  final bool hasCompletedSets;
}

/// Turns an in-progress workout into the `finish_workout` payload and the
/// on-device summary.
abstract final class WorkoutFinalizer {
  static FinishPreparation prepare(
    ActiveWorkout workout, {
    required DateTime completedAt,
  }) {
    final cleaned = workout.copyWith(exercises: [
      for (final e in workout.exercises)
        e.copyWith(sets: [
          for (final s in e.sets)
            if (s.completed || !s.isEmpty) s,
        ]),
    ]);

    final saved = <Map<String, dynamic>>[];
    for (final entry in cleaned.exercises) {
      final type = entry.exercise.trackingType;
      final done = [
        for (final s in entry.sets)
          if (s.completed && WorkoutSessionEditor.canComplete(type, s)) s,
      ];
      if (done.isEmpty) continue;
      saved.add({
        'id': entry.id,
        'exercise_id': entry.exercise.id,
        'position': saved.length,
        'notes': entry.notes,
        'replaced_from_exercise_id': entry.replacedFromExerciseId,
        'sets': [
          for (var i = 0; i < done.length; i++) setPayload(type, done[i], i),
        ],
      });
    }

    return FinishPreparation(
      workout: cleaned,
      hasCompletedSets: saved.isNotEmpty,
      payload: {
        'id': cleaned.id,
        'template_id': cleaned.templateId,
        'started_at': cleaned.startedAt.toUtc().toIso8601String(),
        'completed_at': completedAt.toUtc().toIso8601String(),
        'exercises': saved,
        'template_additions': [
          for (final a in WorkoutSessionEditor.templateAdditions(cleaned))
            a.toJson(),
        ],
      },
    );
  }

  /// One `workout_log_sets` row. The canonical kg goes to the column that
  /// matches the tracking type; the typed value and unit are kept as-is.
  static Map<String, dynamic> setPayload(
    TrackingType type,
    LoggedSet set,
    int position,
  ) {
    final kg = set.loadKg;
    return {
      'id': set.id,
      'position': position,
      'set_type': set.setType.dbValue,
      'reps': type.hasReps ? set.reps : null,
      'weight_kg': type == TrackingType.weightReps ? kg : null,
      'added_kg': type == TrackingType.weightedBodyweight ? kg : null,
      'assist_kg': type == TrackingType.assistedBodyweight ? kg : null,
      'entered_weight': type.hasLoadInput ? set.enteredWeight : null,
      'entered_unit':
          type.hasLoadInput && set.enteredWeight != null
              ? (set.enteredUnit ?? WeightUnit.kg).dbValue
              : null,
      'duration_s': type == TrackingType.duration ? set.durationS : null,
      'rpe': set.rpe,
    };
  }

  static WorkoutSummary summarize(
    ActiveWorkout workout, {
    required DateTime completedAt,
    required bool synced,
    double? bodyweightKg,
  }) {
    final bw = bodyweightKg ?? workout.bodyweightKg;
    return WorkoutSummary(
      workoutId: workout.id,
      title: workout.title,
      duration: completedAt.difference(workout.startedAt),
      completedWorkingSets:
          VolumeCalculator.completedWorkingSets(workout.exercises),
      volumeKg:
          VolumeCalculator.workoutVolume(workout.exercises, bodyweightKg: bw),
      newRecords: PrDetector.detect(workout.exercises),
      synced: synced,
    );
  }
}
