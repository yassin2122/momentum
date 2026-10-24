import '../../../../core/error/result.dart';
import '../entities/recovery.dart';

abstract interface class RecoveryRepository {
  /// The signed-in athlete's check-ins on or after [since], newest first.
  Future<Result<List<RecoveryCheckin>>> getCheckins(DateTime since);

  /// Saves the check-in for its date, replacing any earlier one that day.
  Future<Result<void>> saveCheckin(RecoveryCheckin checkin);
}
