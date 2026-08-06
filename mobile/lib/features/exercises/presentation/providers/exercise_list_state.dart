import '../../../../core/error/failure.dart';
import '../../domain/entities/exercise_entity.dart';

/// Immutable state for the Exercise Library list. `items` accumulates
/// across pages (append-on-load-more); `isLoading` covers the initial/
/// search/filter-change fetch, `isLoadingMore` covers pagination only —
/// kept separate so the UI can show a skeleton for the former and a
/// small inline spinner for the latter.
final class ExerciseListState {
  const ExerciseListState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.nextOffset = 0,
    this.error,
    this.searchQuery = '',
    this.selectedMuscle,
    this.selectedEquipment = const [],
    this.selectedExerciseType,
    this.selectedDifficulty,
  });

  final List<ExerciseEntity> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int nextOffset;
  final Failure? error;
  final String searchQuery;
  final String? selectedMuscle;
  final List<String> selectedEquipment;
  final String? selectedExerciseType;
  final String? selectedDifficulty;

  bool get isEmpty => !isLoading && error == null && items.isEmpty;
  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      selectedMuscle != null ||
      selectedEquipment.isNotEmpty ||
      selectedExerciseType != null ||
      selectedDifficulty != null;

  ExerciseListState copyWith({
    List<ExerciseEntity>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? nextOffset,
    Failure? error,
    bool clearError = false,
    String? searchQuery,
    String? selectedMuscle,
    bool clearMuscle = false,
    List<String>? selectedEquipment,
    String? selectedExerciseType,
    bool clearExerciseType = false,
    String? selectedDifficulty,
    bool clearDifficulty = false,
  }) {
    return ExerciseListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextOffset: nextOffset ?? this.nextOffset,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      selectedMuscle: clearMuscle ? null : (selectedMuscle ?? this.selectedMuscle),
      selectedEquipment: selectedEquipment ?? this.selectedEquipment,
      selectedExerciseType: clearExerciseType
          ? null
          : (selectedExerciseType ?? this.selectedExerciseType),
      selectedDifficulty:
          clearDifficulty ? null : (selectedDifficulty ?? this.selectedDifficulty),
    );
  }
}
