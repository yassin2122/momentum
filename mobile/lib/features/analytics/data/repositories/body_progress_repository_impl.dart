import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/body_progress.dart';
import '../../domain/repositories/body_progress_repository.dart';
import '../datasources/body_progress_remote_datasource.dart';
import '../models/analytics_rows.dart';

class BodyProgressRepositoryImpl implements BodyProgressRepository {
  const BodyProgressRepositoryImpl(this._remote);

  final BodyProgressRemoteDataSource _remote;

  static const _uuid = Uuid();

  Future<Result<T>> _guard<T>(Future<T> Function() call) async {
    try {
      return Result.success(await call());
    } on PostgrestException catch (e) {
      // 23514 = a check constraint (out-of-range value) rejected the row.
      if (e.code == '23514') {
        return const Result.failure(
            ServerFailure('That value looks out of range. Please check it.'));
      }
      return const Result.failure(
          ServerFailure('Something went wrong. Please try again.'));
    } on StorageException {
      return const Result.failure(
          ServerFailure("Couldn't upload the photo. Please try again."));
    } on AuthException {
      return const Result.failure(ServerFailure('Please sign in again.'));
    } catch (_) {
      return const Result.failure(NetworkFailure());
    }
  }

  @override
  Future<Result<BodyProgressData>> load() => _guard(() async {
        final results = await Future.wait([
          _remote.entries(),
          _remote.photos(),
        ]);
        final goalRow = await _remote.goal();
        final photoRows = results[1];
        final urls = await Future.wait(
            [for (final r in photoRows) _remote.signedUrl(r['storage_path'] as String)]);
        return BodyProgressData(
          entries: [for (final r in results[0]) AnalyticsRows.entry(r)],
          goal: AnalyticsRows.goal(goalRow),
          photos: [
            for (var i = 0; i < photoRows.length; i++)
              AnalyticsRows.photo(photoRows[i], url: urls[i]),
          ],
        );
      });

  @override
  Future<Result<void>> addEntry(NewBodyEntry entry) async {
    if (entry.values.isEmpty) {
      return const Result.failure(
          ServerFailure('Enter at least one measurement.'));
    }
    return _guard(() => _remote.insertEntry(AnalyticsRows.entryRow(entry)));
  }

  @override
  Future<Result<void>> deleteEntry(String id) =>
      _guard(() => _remote.deleteEntry(id));

  @override
  Future<Result<void>> saveGoal({
    required double targetWeightKg,
    double? startWeightKg,
    DateTime? targetDate,
  }) =>
      _guard(() => _remote.upsertGoal({
            'target_weight_kg': targetWeightKg,
            'start_weight_kg': startWeightKg,
            'target_date':
                targetDate == null ? null : AnalyticsRows.date(targetDate),
          }));

  @override
  Future<Result<void>> clearGoal() => _guard(_remote.deleteGoal);

  static String contentTypeFor(String ext) => switch (ext.toLowerCase()) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        'heif' => 'image/heif',
        _ => 'image/jpeg',
      };

  @override
  Future<Result<void>> addPhoto({
    required Uint8List bytes,
    required String fileExtension,
    required PhotoPose pose,
    required DateTime takenOn,
  }) =>
      _guard(() async {
        final ext = fileExtension.isEmpty ? 'jpg' : fileExtension.toLowerCase();
        final path = '${_remote.userId}/${_uuid.v4()}.$ext';
        await _remote.uploadPhoto(path, bytes, contentTypeFor(ext));
        try {
          await _remote.insertPhoto({
            'storage_path': path,
            'pose': pose.dbValue,
            'taken_on': AnalyticsRows.date(takenOn),
          });
        } catch (_) {
          // Don't leave an unlisted private file behind.
          try {
            await _remote.removeObject(path);
          } catch (_) {
            // Best effort; the original error is what the user sees.
          }
          rethrow;
        }
      });

  @override
  Future<Result<void>> deletePhoto(ProgressPhoto photo) => _guard(() async {
        // Row first: once it's gone the photo is no longer listed, even if
        // removing the file then fails (it stays private either way).
        await _remote.deletePhotoRow(photo.id);
        try {
          await _remote.removeObject(photo.storagePath);
        } catch (_) {
          // Best effort; an orphaned object stays private to its owner.
        }
      });
}
