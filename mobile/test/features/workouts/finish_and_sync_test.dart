import 'package:flutter_test/flutter_test.dart';
import 'package:grit/core/error/failure.dart';
import 'package:grit/features/workouts/domain/entities/active_workout.dart';
import 'package:grit/features/workouts/domain/usecases/finish_workout.dart';
import 'package:grit/features/workouts/domain/usecases/sync_pending_workouts.dart';

import 'fake_workout_repository.dart';
import 'fixtures.dart';

void main() {
  final end = DateTime.utc(2026, 10, 16, 19);
  late FakeWorkoutRepository repo;
  late ActiveWorkout workout;

  setUp(() {
    repo = FakeWorkoutRepository();
    workout = workoutOf([
      entry(pullUp, [doneSet('1', reps: 10)]),
    ]);
    repo.active = workout;
  });

  test('online: saved, removed from queue, server bodyweight used', () async {
    final outcome = await FinishWorkout(repo)(workout, completedAt: end);

    expect(outcome.failure, isNull);
    expect(outcome.summary.synced, isTrue);
    expect(outcome.summary.volumeKg, 825); // 82.5 kg snapshot × 10
    expect(repo.sent.single['id'], workout.id);
    expect(repo.pending, isEmpty);
    expect(repo.active, isNull);
  });

  test('offline: kept in the queue, then sent by sync', () async {
    repo.online = false;
    final outcome = await FinishWorkout(repo)(workout, completedAt: end);

    expect(outcome.failure, isA<NetworkFailure>());
    expect(outcome.summary.synced, isFalse);
    expect(repo.active, isNull); // no longer "in progress"…
    expect(repo.pending.single.workoutId, workout.id); // …but not lost
    expect(repo.pending.single.lastError, isNotNull);

    expect(await SyncPendingWorkouts(repo)('user-1'), hasLength(1));

    repo.online = true;
    expect(await SyncPendingWorkouts(repo)('user-1'), isEmpty);
    expect(repo.sent.single['id'], workout.id);
    expect(repo.pending, isEmpty);
  });
}
