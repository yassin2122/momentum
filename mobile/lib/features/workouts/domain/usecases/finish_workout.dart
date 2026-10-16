import '../../../../core/error/failure.dart';
import '../entities/active_workout.dart';
import '../entities/pending_workout.dart';
import '../repositories/workout_repository.dart';
import '../services/workout_finalizer.dart';

/// Outcome of finishing: always a summary; [failure] is set when the
/// workout is saved on the device but not yet on the server.
final class FinishOutcome {
  const FinishOutcome({required this.summary, this.failure});

  final WorkoutSummary summary;
  final Failure? failure;
}

/// Finishes a workout without ever losing it:
///
/// 1. builds the `finish_workout` payload (empty unfinished sets dropped);
/// 2. adds it to the on-device retry queue, *then* clears the in-progress
///    copy — if the app dies in between, the workout is still on disk;
/// 3. sends it; on success it leaves the queue, otherwise it stays there
///    for [SyncPendingWorkouts].
class FinishWorkout {
  const FinishWorkout(this._repository);

  final WorkoutRepository _repository;

  Future<FinishOutcome> call(
    ActiveWorkout workout, {
    required DateTime completedAt,
  }) async {
    final prep = WorkoutFinalizer.prepare(workout, completedAt: completedAt);
    final pending = PendingWorkout(
      workoutId: workout.id,
      title: workout.title,
      payload: prep.payload,
    );

    final queue = await _repository.loadPendingWorkouts(workout.userId);
    await _repository.savePendingWorkouts(workout.userId, [
      for (final p in queue)
        if (p.workoutId != workout.id) p,
      pending,
    ]);
    await _repository.clearActiveWorkout(workout.userId);

    final result = await _repository.finishWorkout(prep.payload);
    return result.when(
      success: (bodyweightSnapshot) async {
        await _removeFromQueue(workout.userId, workout.id);
        return FinishOutcome(
          summary: WorkoutFinalizer.summarize(
            prep.workout,
            completedAt: completedAt,
            synced: true,
            bodyweightKg: bodyweightSnapshot,
          ),
        );
      },
      failure: (failure) async {
        await _markError(workout.userId, workout.id, failure.message);
        return FinishOutcome(
          failure: failure,
          summary: WorkoutFinalizer.summarize(
            prep.workout,
            completedAt: completedAt,
            synced: false,
          ),
        );
      },
    );
  }

  Future<void> _removeFromQueue(String userId, String workoutId) async {
    final queue = await _repository.loadPendingWorkouts(userId);
    await _repository.savePendingWorkouts(userId, [
      for (final p in queue)
        if (p.workoutId != workoutId) p,
    ]);
  }

  Future<void> _markError(String userId, String workoutId, String error) async {
    final queue = await _repository.loadPendingWorkouts(userId);
    await _repository.savePendingWorkouts(userId, [
      for (final p in queue) p.workoutId == workoutId ? p.withError(error) : p,
    ]);
  }
}
