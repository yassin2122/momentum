import '../entities/pending_workout.dart';
import '../repositories/workout_repository.dart';

/// Resends finished workouts that didn't reach Supabase. Safe to call any
/// time — `finish_workout` ignores a workout id it has already saved.
/// Returns what is still waiting afterwards.
class SyncPendingWorkouts {
  const SyncPendingWorkouts(this._repository);

  final WorkoutRepository _repository;

  Future<List<PendingWorkout>> call(String userId) async {
    final queue = await _repository.loadPendingWorkouts(userId);
    if (queue.isEmpty) return queue;

    final remaining = <PendingWorkout>[];
    for (final item in queue) {
      final result = await _repository.finishWorkout(item.payload);
      if (result.isFailure) {
        remaining.add(item.withError(result.failureOrNull!.message));
      }
    }

    // Re-read so a workout finished while this ran isn't dropped.
    final sentIds = {
      for (final item in queue)
        if (!remaining.any((r) => r.workoutId == item.workoutId)) item.workoutId,
    };
    final latest = await _repository.loadPendingWorkouts(userId);
    final merged = [
      for (final p in latest)
        if (!sentIds.contains(p.workoutId))
          remaining.firstWhere((r) => r.workoutId == p.workoutId,
              orElse: () => p),
    ];
    await _repository.savePendingWorkouts(userId, merged);
    return merged;
  }
}
