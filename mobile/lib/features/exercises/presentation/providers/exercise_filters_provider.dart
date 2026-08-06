import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/exercise_entity.dart';
import 'exercise_providers.dart';

/// Real distinct facet values for the filter row — fetched once per app
/// session. A muscle group never appears in the UI with zero possible
/// matches, per API_CONTRACT.md's design intent.
final exerciseFiltersProvider = FutureProvider<ExerciseFilterOptions>((ref) async {
  final result = await ref.watch(getExerciseFiltersProvider).call();
  return result.when(
    success: (filters) => filters,
    // A failed facet fetch shouldn't block browsing — fall back to no
    // quick-filter chips rather than erroring the whole screen.
    failure: (_) => ExerciseFilterOptions.empty,
  );
});
