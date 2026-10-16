import 'package:gym_app/features/workouts/domain/entities/active_workout.dart';
import 'package:gym_app/features/workouts/domain/entities/logged_set.dart';
import 'package:gym_app/features/workouts/domain/entities/trackable_exercise.dart';
import 'package:gym_app/features/workouts/domain/entities/workout_enums.dart';
import 'package:gym_app/features/workouts/domain/services/workout_session_editor.dart';

const bench = TrackableExercise(
  id: 'ex-bench',
  name: 'Bench Press',
  trackingType: TrackingType.weightReps,
);
const squat = TrackableExercise(
  id: 'ex-squat',
  name: 'Squat',
  trackingType: TrackingType.weightReps,
);
const pullUp = TrackableExercise(
  id: 'ex-pullup',
  name: 'Pull-up',
  trackingType: TrackingType.bodyweightReps,
  bwFactor: 1.0,
);
const weightedDip = TrackableExercise(
  id: 'ex-dip',
  name: 'Weighted Dip',
  trackingType: TrackingType.weightedBodyweight,
  bwFactor: 1.0,
);
const assistedPullUp = TrackableExercise(
  id: 'ex-assisted',
  name: 'Assisted Pull-up',
  trackingType: TrackingType.assistedBodyweight,
  bwFactor: 1.0,
);
const plank = TrackableExercise(
  id: 'ex-plank',
  name: 'Plank',
  trackingType: TrackingType.duration,
);

/// Deterministic id generator: id-1, id-2, …
WorkoutSessionEditor testEditor() {
  var n = 0;
  return WorkoutSessionEditor(newId: () => 'id-${++n}');
}

LoggedSet doneSet(
  String id, {
  SetType type = SetType.working,
  double? kg,
  int? reps,
  int? seconds,
  bool completed = true,
}) =>
    LoggedSet(
      id: id,
      setType: type,
      completed: completed,
      reps: reps,
      enteredWeight: kg,
      enteredUnit: kg == null ? null : WeightUnit.kg,
      durationS: seconds,
    );

LoggedExercise entry(
  TrackableExercise exercise,
  List<LoggedSet> sets, {
  String? id,
  Map<PrMetric, double> bests = const {},
}) =>
    LoggedExercise(
      id: id ?? 'entry-${exercise.id}',
      exercise: exercise,
      unit: WeightUnit.kg,
      sets: sets,
      personalBests: bests,
    );

ActiveWorkout workoutOf(
  List<LoggedExercise> exercises, {
  String? templateId,
  double? bodyweightKg,
}) =>
    ActiveWorkout(
      id: 'workout-1',
      userId: 'user-1',
      startedAt: DateTime.utc(2026, 10, 16, 18),
      exercises: exercises,
      templateId: templateId,
      bodyweightKg: bodyweightKg,
    );
