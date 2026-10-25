import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/body_progress.dart';

abstract interface class BodyProgressRepository {
  /// The signed-in athlete's entries, goal and photos (with signed URLs).
  Future<Result<BodyProgressData>> load();

  Future<Result<void>> addEntry(NewBodyEntry entry);
  Future<Result<void>> deleteEntry(String id);

  /// Creates or replaces the goal.
  Future<Result<void>> saveGoal({
    required double targetWeightKg,
    double? startWeightKg,
    DateTime? targetDate,
  });
  Future<Result<void>> clearGoal();

  /// Uploads into the athlete's own private folder, then records it.
  Future<Result<void>> addPhoto({
    required Uint8List bytes,
    required String fileExtension,
    required PhotoPose pose,
    required DateTime takenOn,
  });
  Future<Result<void>> deletePhoto(ProgressPhoto photo);
}
