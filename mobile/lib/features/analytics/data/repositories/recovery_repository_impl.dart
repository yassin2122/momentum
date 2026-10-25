import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/recovery.dart';
import '../../domain/repositories/recovery_repository.dart';
import '../datasources/recovery_remote_datasource.dart';
import '../models/analytics_rows.dart';

class RecoveryRepositoryImpl implements RecoveryRepository {
  const RecoveryRepositoryImpl(this._remote);

  final RecoveryRemoteDataSource _remote;

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Result.success(await call());
    } on PostgrestException {
      return const Result.failure(
          ServerFailure('Something went wrong. Please try again.'));
    } on AuthException {
      return const Result.failure(ServerFailure('Please sign in again.'));
    } catch (_) {
      return const Result.failure(NetworkFailure());
    }
  }

  @override
  Future<Result<List<RecoveryCheckin>>> getCheckins(DateTime since) =>
      _guard(() async => [
            for (final r in await _remote.checkins(AnalyticsRows.date(since)))
              if (AnalyticsRows.checkin(r) case final c?) c,
          ]);

  @override
  Future<Result<void>> saveCheckin(RecoveryCheckin checkin) =>
      _guard(() => _remote.upsert(AnalyticsRows.checkinRow(checkin)));
}
