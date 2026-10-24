import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client_provider.dart';
import '../../../muscle_map/presentation/providers/muscle_map_providers.dart';
import '../../../workouts/domain/entities/workout_enums.dart';
import '../../../workouts/presentation/providers/workout_providers.dart';
import '../../data/datasources/body_progress_remote_datasource.dart';
import '../../data/datasources/recovery_remote_datasource.dart';
import '../../data/repositories/body_progress_repository_impl.dart';
import '../../data/repositories/recovery_repository_impl.dart';
import '../../domain/entities/body_progress.dart';
import '../../domain/entities/muscle_group_distribution.dart';
import '../../domain/entities/recovery.dart';
import '../../domain/repositories/body_progress_repository.dart';
import '../../domain/repositories/recovery_repository.dart';
import '../../domain/services/muscle_group_distribution_calculator.dart';
import '../../domain/services/recovery_insights.dart';

// ── Muscle-group distribution ──────────────────────────────────────────
// Reuses the muscle map's repository: same completed-workout query and
// exercise → muscle-group links, no second data source.

final distributionRangeProvider =
    StateProvider<DistributionRange>((ref) => DistributionRange.weeks4);

final muscleGroupDistributionProvider = FutureProvider.autoDispose
    .family<MuscleGroupDistribution, DistributionRange>((ref, range) async {
  ref.watch(currentUserIdProvider);
  final repo = ref.watch(muscleMapRepositoryProvider);
  final now = DateTime.now();
  final workouts = (await repo
          .getCompletedWorkouts(now.subtract(Duration(days: range.days))))
      .when(success: (w) => w, failure: (f) => throw f.message);
  final ids = {
    for (final w in workouts)
      for (final e in w.exercises) e.exerciseId,
  };
  final links = (await repo.getMuscleLinks(ids))
      .when(success: (l) => l, failure: (f) => throw f.message);
  return MuscleGroupDistributionCalculator.compute(
    workouts: workouts,
    linksByExercise: links,
    range: range,
    now: now,
  );
});

// ── Body progress ──────────────────────────────────────────────────────

final bodyProgressRepositoryProvider = Provider<BodyProgressRepository>(
  (ref) => BodyProgressRepositoryImpl(
    BodyProgressRemoteDataSource(ref.watch(supabaseClientProvider)),
  ),
);

final bodyProgressProvider =
    FutureProvider.autoDispose<BodyProgressData>((ref) async {
  ref.watch(currentUserIdProvider);
  final result = await ref.watch(bodyProgressRepositoryProvider).load();
  return result.when(success: (d) => d, failure: (f) => throw f.message);
});

/// The athlete's preferred weight unit (from `user_settings`), kg until
/// known. Bodyweight is stored in kg and converted only for display.
final bodyWeightUnitProvider = Provider<WeightUnit>(
  (ref) =>
      ref.watch(workoutDefaultsProvider).valueOrNull?.preferredUnit ??
      WeightUnit.kg,
);

/// Which metric the Body chart shows.
final selectedBodyMeasureProvider =
    StateProvider.autoDispose<BodyMeasure>((ref) => BodyMeasure.weight);

// ── Recovery ───────────────────────────────────────────────────────────

final recoveryRepositoryProvider = Provider<RecoveryRepository>(
  (ref) => RecoveryRepositoryImpl(
    RecoveryRemoteDataSource(ref.watch(supabaseClientProvider)),
  ),
);

final recoveryOverviewProvider =
    FutureProvider.autoDispose<RecoveryOverview>((ref) async {
  ref.watch(currentUserIdProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final since = DateTime(today.year, today.month, today.day - 27);

  final checkins = (await ref.watch(recoveryRepositoryProvider).getCheckins(since))
      .when(success: (c) => c, failure: (f) => throw f.message);
  final workouts =
      (await ref.watch(muscleMapRepositoryProvider).getCompletedWorkouts(since))
          .when(success: (w) => w, failure: (f) => throw f.message);

  final sorted = [...checkins]..sort((a, b) => b.date.compareTo(a.date));
  final latest = sorted.isEmpty ? null : sorted.first;
  return RecoveryOverview(
    today: latest != null && RecoveryInsights.daysBetween(latest.date, today) == 0
        ? latest
        : null,
    checkins: sorted,
    loads: RecoveryInsights.dailyLoads(workouts, today: today),
    insights: RecoveryInsights.compute(
      checkins: sorted,
      workouts: workouts,
      today: today,
    ),
  );
});
