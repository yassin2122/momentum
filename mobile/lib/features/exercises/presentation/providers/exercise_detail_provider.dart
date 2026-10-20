import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/exercise_entity.dart';
import 'exercise_providers.dart';

/// Full exercise row (with instructions) for the detail sheet. The list
/// query deliberately skips instructions, so the sheet fetches them on
/// open. A [Failure] is thrown so the sheet can show its user-safe message.
final exerciseDetailProvider =
    FutureProvider.autoDispose.family<ExerciseEntity, String>((ref, id) async {
  final result = await ref.watch(getExerciseByIdProvider).call(id);
  return result.when(
    success: (exercise) => exercise,
    failure: (failure) => throw failure,
  );
});
