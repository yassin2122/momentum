import '../../../../core/error/result.dart';
import '../entities/discipline_score.dart';
import '../entities/streak_status.dart';

abstract interface class DashboardRepository {
  /// Marks [localDate] (the device's calendar day) as active and returns
  /// the streak after it. Safe to call on every open/resume.
  Future<Result<StreakStatus>> recordAppOpen(DateTime localDate);

  Future<Result<DisciplineScore>> getDisciplineScore(DateTime localDate);
}
