import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../auth/presentation/providers/auth_state_notifier.dart';
import '../../data/datasources/gym_remote_datasource.dart';
import '../../data/repositories/gym_repository_impl.dart';
import '../../domain/entities/gym_entities.dart';
import '../../domain/repositories/gym_repository.dart';

/// Dependency graph and read models for the gym screens. Every write goes
/// through [GymRepository]; screens invalidate the provider they changed.

final gymRemoteDataSourceProvider = Provider<GymRemoteDataSource>(
  (ref) => GymRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final gymRepositoryProvider = Provider<GymRepository>(
  (ref) => GymRepositoryImpl(ref.watch(gymRemoteDataSourceProvider)),
);

T _unwrap<T>(Result<T> result) => result.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );

/// Readable message for an error coming out of these providers.
String gymErrorMessage(Object error) =>
    error is Failure ? error.message : 'Something went wrong. Try again.';

/// True for signed-in, non-guest users (gyms need a real account).
final gymAccountProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  return user != null && !user.isGuest;
});

// ---- Public ----

/// Search + one facility filter for Find a gym.
typedef GymDirectoryQuery = ({String search, String? facility});

final gymDirectoryProvider = FutureProvider.autoDispose
    .family<List<GymDirectoryEntry>, GymDirectoryQuery>((ref, q) async {
  final repo = ref.watch(gymRepositoryProvider);
  return _unwrap(await repo.getDirectory(
    search: q.search.isEmpty ? null : q.search,
    facility: q.facility,
  ));
});

final gymPublicProvider = FutureProvider.autoDispose
    .family<GymPublicDetail, String>((ref, gymId) async {
  final repo = ref.watch(gymRepositoryProvider);
  return _unwrap(await repo.getPublicGym(gymId));
});

// ---- Owner / staff ----

/// Gyms the signed-in user works at. Empty for guests.
final myGymsProvider = FutureProvider.autoDispose<List<MyGym>>((ref) async {
  if (!ref.watch(gymAccountProvider)) return const [];
  final repo = ref.watch(gymRepositoryProvider);
  return _unwrap(await repo.getMyGyms());
});

final gymOverviewProvider = FutureProvider.autoDispose
    .family<GymAdminOverview, String>((ref, gymId) async {
  final repo = ref.watch(gymRepositoryProvider);
  return _unwrap(await repo.getOverview(gymId));
});

final gymAdminDetailProvider = FutureProvider.autoDispose
    .family<GymAdminDetail, String>((ref, gymId) async {
  final repo = ref.watch(gymRepositoryProvider);
  return _unwrap(await repo.getAdminDetail(gymId));
});

final gymCoachesAdminProvider = FutureProvider.autoDispose
    .family<GymCoachesAdmin, String>((ref, gymId) async {
  final repo = ref.watch(gymRepositoryProvider);
  return _unwrap(await repo.getCoachesAdmin(gymId));
});

final gymInquiriesProvider = FutureProvider.autoDispose
    .family<List<GymInquiry>, String>((ref, gymId) async {
  final repo = ref.watch(gymRepositoryProvider);
  return _unwrap(await repo.getInquiries(gymId));
});

final gymStaffProvider = FutureProvider.autoDispose
    .family<List<GymStaffMember>, String>((ref, gymId) async {
  final repo = ref.watch(gymRepositoryProvider);
  return _unwrap(await repo.getStaff(gymId));
});

/// Refreshes everything a gym's admin screens show.
void invalidateGymAdmin(WidgetRef ref, String gymId) {
  ref
    ..invalidate(gymOverviewProvider(gymId))
    ..invalidate(gymAdminDetailProvider(gymId))
    ..invalidate(gymCoachesAdminProvider(gymId))
    ..invalidate(gymInquiriesProvider(gymId))
    ..invalidate(gymStaffProvider(gymId))
    ..invalidate(myGymsProvider);
}

// ---- Coach side ----

final myGymAffiliationsProvider =
    FutureProvider.autoDispose<MyGymAffiliations>((ref) async {
  if (!ref.watch(gymAccountProvider)) {
    return const MyGymAffiliations(affiliations: [], invitations: []);
  }
  final repo = ref.watch(gymRepositoryProvider);
  return _unwrap(await repo.getMyAffiliations());
});

final myAiEntitlementProvider =
    FutureProvider.autoDispose<AiEntitlement>((ref) async {
  if (!ref.watch(gymAccountProvider)) return AiEntitlement.none;
  final repo = ref.watch(gymRepositoryProvider);
  return _unwrap(await repo.getMyAiEntitlement());
});
