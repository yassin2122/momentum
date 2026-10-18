import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/discipline_score.dart';
import '../../domain/entities/streak_status.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_datasource.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  const DashboardRepositoryImpl(this._remote);

  final DashboardRemoteDataSource _remote;

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
  Future<Result<StreakStatus>> recordAppOpen(DateTime localDate) => _guard(
      () async => StreakStatus.fromJson(await _remote.recordAppOpen(localDate)));

  @override
  Future<Result<DisciplineScore>> getDisciplineScore(DateTime localDate) =>
      _guard(() async => DisciplineScore.fromJson(
          await _remote.disciplineScore(localDate)));
}
