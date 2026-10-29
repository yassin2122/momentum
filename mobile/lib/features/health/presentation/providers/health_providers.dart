import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../../../core/network/supabase_client_provider.dart';
import '../../../gyms/presentation/providers/gym_providers.dart' show gymAccountProvider;
import '../../data/datasources/health_remote_datasource.dart';
import '../../data/repositories/health_repository_impl.dart';
import '../../domain/entities/health_entities.dart';
import '../../domain/repositories/health_repository.dart';

final healthRemoteDataSourceProvider = Provider<HealthRemoteDataSource>(
  (ref) => HealthRemoteDataSource(ref.watch(supabaseClientProvider)),
);

final healthRepositoryProvider = Provider<HealthRepository>(
  (ref) => HealthRepositoryImpl(ref.watch(healthRemoteDataSourceProvider)),
);

T _unwrap<T>(Result<T> result) => result.when(
      success: (value) => value,
      failure: (failure) => throw failure,
    );

String healthErrorMessage(Object error) =>
    error is Failure ? error.message : 'Something went wrong. Try again.';

/// Search + filters for Find a health pro.
typedef HealthQuery = ({
  String search,
  HealthKind? kind,
  String? specialty,
  HealthServiceMode? mode,
  bool verifiedOnly,
});

final healthDirectoryProvider = FutureProvider.autoDispose
    .family<List<HealthDirectoryEntry>, HealthQuery>((ref, q) async {
  final repo = ref.watch(healthRepositoryProvider);
  return _unwrap(await repo.getDirectory(
    search: q.search,
    kind: q.kind,
    specialty: q.specialty,
    mode: q.mode,
    verifiedOnly: q.verifiedOnly,
  ));
});

final healthProviderDetailProvider = FutureProvider.autoDispose
    .family<HealthProviderDetail, String>((ref, listingId) async {
  final repo = ref.watch(healthRepositoryProvider);
  return _unwrap(await repo.getProvider(listingId));
});

final savedProvidersProvider =
    FutureProvider.autoDispose<List<HealthDirectoryEntry>>((ref) async {
  if (!ref.watch(gymAccountProvider)) return const [];
  final repo = ref.watch(healthRepositoryProvider);
  return _unwrap(await repo.getSaved());
});

/// The signed-in user's own provider profiles (empty for most people).
final myHealthProfilesProvider =
    FutureProvider.autoDispose<List<MyHealthProfile>>((ref) async {
  if (!ref.watch(gymAccountProvider)) return const [];
  final repo = ref.watch(healthRepositoryProvider);
  return _unwrap(await repo.getMine());
});
