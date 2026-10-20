import '../../../../core/error/failure.dart';
import '../../domain/entities/exercise_entity.dart';

/// The filters a user has applied in the Exercise Library. Muscles are
/// multi-select (PostgREST `in` filter); equipment, type and difficulty are
/// single-select — every exercise has exactly one of each, so picking two
/// would always return nothing.
final class ExerciseLibraryFilters {
  const ExerciseLibraryFilters({
    this.muscles = const {},
    this.equipment,
    this.exerciseType,
    this.difficulty,
  });

  final Set<String> muscles;
  final String? equipment;
  final String? exerciseType;
  final String? difficulty;

  static const none = ExerciseLibraryFilters();

  /// Number of active filter values (shown on the Filters button badge).
  int get count =>
      muscles.length +
      (equipment == null ? 0 : 1) +
      (exerciseType == null ? 0 : 1) +
      (difficulty == null ? 0 : 1);

  bool get isEmpty => count == 0;

  /// Pass a function to set a single-select value; `() => null` clears it.
  ExerciseLibraryFilters copyWith({
    Set<String>? muscles,
    String? Function()? equipment,
    String? Function()? exerciseType,
    String? Function()? difficulty,
  }) {
    return ExerciseLibraryFilters(
      muscles: muscles ?? this.muscles,
      equipment: equipment == null ? this.equipment : equipment(),
      exerciseType: exerciseType == null ? this.exerciseType : exerciseType(),
      difficulty: difficulty == null ? this.difficulty : difficulty(),
    );
  }
}

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
    this.filters = ExerciseLibraryFilters.none,
  });

  final List<ExerciseEntity> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int nextOffset;
  final Failure? error;
  final String searchQuery;
  final ExerciseLibraryFilters filters;

  bool get isEmpty => !isLoading && error == null && items.isEmpty;
  bool get hasActiveFilters => searchQuery.trim().isNotEmpty || !filters.isEmpty;

  ExerciseListState copyWith({
    List<ExerciseEntity>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? nextOffset,
    Failure? error,
    bool clearError = false,
    String? searchQuery,
    ExerciseLibraryFilters? filters,
  }) {
    return ExerciseListState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      nextOffset: nextOffset ?? this.nextOffset,
      error: clearError ? null : (error ?? this.error),
      searchQuery: searchQuery ?? this.searchQuery,
      filters: filters ?? this.filters,
    );
  }
}
