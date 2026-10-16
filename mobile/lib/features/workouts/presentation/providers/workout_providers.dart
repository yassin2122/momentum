import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/result.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_state_notifier.dart';
import '../../data/datasources/workout_local_datasource.dart';
import '../../data/datasources/workout_remote_datasource.dart';
import '../../data/repositories/workout_repository_impl.dart';
import '../../domain/entities/workout_enums.dart';
import '../../domain/entities/workout_template.dart';
import '../../domain/repositories/workout_repository.dart';
import '../../domain/services/workout_session_editor.dart';
import '../../domain/usecases/finish_workout.dart';
import '../../domain/usecases/sync_pending_workouts.dart';

/// Dependency graph for the TRAIN workout logger (same shape as
/// auth_providers.dart: override one provider to swap an implementation).
final workoutLocalDataSourceProvider =
    Provider<WorkoutLocalDataSource>((ref) => WorkoutLocalDataSource());

final workoutRemoteDataSourceProvider = Provider<WorkoutRemoteDataSource>(
  (ref) => WorkoutRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final workoutRepositoryProvider = Provider<WorkoutRepository>(
  (ref) => WorkoutRepositoryImpl(
    ref.watch(workoutRemoteDataSourceProvider),
    ref.watch(workoutLocalDataSourceProvider),
  ),
);

final finishWorkoutProvider = Provider<FinishWorkout>(
  (ref) => FinishWorkout(ref.watch(workoutRepositoryProvider)),
);

final syncPendingWorkoutsProvider = Provider<SyncPendingWorkouts>(
  (ref) => SyncPendingWorkouts(ref.watch(workoutRepositoryProvider)),
);

final workoutSessionEditorProvider = Provider<WorkoutSessionEditor>((ref) {
  const uuid = Uuid();
  return WorkoutSessionEditor(newId: uuid.v4);
});

/// Signed-in user's id, or null.
final currentUserIdProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).valueOrNull?.id,
);

/// Preferred unit + latest bodyweight. Falls back to kg / unknown when
/// offline, so starting a workout never blocks on the network.
final workoutDefaultsProvider = FutureProvider<WorkoutDefaults>((ref) async {
  ref.watch(currentUserIdProvider);
  final result = await ref
      .watch(workoutRepositoryProvider)
      .getWorkoutDefaults()
      .timeout(
        const Duration(seconds: 4),
        onTimeout: () => const Result.success(
            WorkoutDefaults(preferredUnit: WeightUnit.kg)),
      );
  return result.valueOrNull ??
      const WorkoutDefaults(preferredUnit: WeightUnit.kg);
});

final workoutTemplatesProvider =
    FutureProvider.autoDispose<List<WorkoutTemplate>>((ref) async {
  ref.watch(currentUserIdProvider);
  final result = await ref.watch(workoutRepositoryProvider).getTemplates();
  return result.when(
    success: (templates) => templates,
    failure: (failure) => throw failure.message,
  );
});
