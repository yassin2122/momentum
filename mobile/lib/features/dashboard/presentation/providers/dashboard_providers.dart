import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/supabase_client_provider.dart';
import '../../../workouts/presentation/providers/workout_providers.dart';
import '../../data/datasources/dashboard_remote_datasource.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../domain/entities/discipline_score.dart';
import '../../domain/entities/streak_status.dart';
import '../../domain/repositories/dashboard_repository.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepositoryImpl(
    DashboardRemoteDataSource(ref.watch(supabaseClientProvider)),
  ),
);

/// Records today's app open and yields the streak. The dashboard
/// invalidates it on resume, so a new day is counted without a restart.
/// Null when signed out or offline — the header then hides the streak.
final streakProvider = FutureProvider.autoDispose<StreakStatus?>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return null;
  final result =
      await ref.watch(dashboardRepositoryProvider).recordAppOpen(DateTime.now());
  return result.valueOrNull;
});

/// Discipline score; waits for the open to be recorded so today counts.
final disciplineProvider =
    FutureProvider.autoDispose<DisciplineScore?>((ref) async {
  if (ref.watch(currentUserIdProvider) == null) return null;
  await ref.watch(streakProvider.future);
  // Templates added or removed change the plan part of the score.
  ref.watch(workoutTemplatesProvider);
  final result = await ref
      .watch(dashboardRepositoryProvider)
      .getDisciplineScore(DateTime.now());
  return result.valueOrNull;
});
