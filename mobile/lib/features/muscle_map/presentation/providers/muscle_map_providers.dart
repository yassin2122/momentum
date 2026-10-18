import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client_provider.dart';
import '../../../workouts/presentation/providers/workout_providers.dart';
import '../../data/datasources/muscle_map_remote_datasource.dart';
import '../../data/repositories/muscle_map_repository_impl.dart';
import '../../domain/entities/muscle.dart';
import '../../domain/entities/muscle_activity.dart';
import '../../domain/repositories/muscle_map_repository.dart';
import '../../domain/services/muscle_activity_calculator.dart';
import '../../domain/services/muscle_mapping.dart';

final muscleMapRepositoryProvider = Provider<MuscleMapRepository>(
  (ref) => MuscleMapRepositoryImpl(
    MuscleMapRemoteDataSource(ref.watch(supabaseClientProvider)),
  ),
);

/// Window options for "recent training", in days.
const muscleWindowOptions = [7, 14, 30, 90];

final muscleWindowDaysProvider = StateProvider<int>((ref) => 14);

/// Per-muscle activity from completed workouts in the chosen window.
final muscleActivityProvider =
    FutureProvider.autoDispose<MuscleActivityReport>((ref) async {
  ref.watch(currentUserIdProvider);
  final days = ref.watch(muscleWindowDaysProvider);
  final repo = ref.watch(muscleMapRepositoryProvider);
  final now = DateTime.now();

  final workouts = (await repo
          .getCompletedWorkouts(now.subtract(Duration(days: days))))
      .when(success: (w) => w, failure: (f) => throw f.message);
  final ids = {
    for (final w in workouts)
      for (final e in w.exercises) e.exerciseId,
  };
  final links = (await repo.getMuscleLinks(ids))
      .when(success: (l) => l, failure: (f) => throw f.message);

  return MuscleActivityCalculator.compute(
    workouts: workouts,
    linksByExercise: links,
    now: now,
    windowDays: days,
  );
});

/// Muscle links for a set of exercises, keyed by the ids sorted and
/// comma-joined (so equal sets share one fetch). Empty on failure: a card
/// without data just stays unlit.
final exerciseMuscleLinksProvider = FutureProvider.autoDispose
    .family<Map<String, List<MuscleLink>>, String>((ref, key) async {
  final ids = key.isEmpty ? <String>{} : key.split(',').toSet();
  final result = await ref.watch(muscleMapRepositoryProvider).getMuscleLinks(ids);
  return result.valueOrNull ?? const {};
});

String exerciseIdsKey(Iterable<String> ids) => (ids.toSet().toList()..sort()).join(',');

/// Regions a list of exercises works, for lighting a plan card: primary
/// muscles full, secondary at a lower glow.
Map<Muscle, double> involvementIntensities(Map<Muscle, Involvement> m) => {
      for (final e in m.entries)
        e.key: e.value == Involvement.primary ? 1.0 : 0.4,
    };
