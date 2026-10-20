import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/exercise_entity.dart';
import '../../domain/usecases/get_exercises.dart';
import 'exercise_list_state.dart';
import 'exercise_providers.dart';

const _pageSize = 30;
const _searchDebounce = Duration(milliseconds: 300);

/// Drives the Exercise Library list: initial load, search-as-you-type
/// (debounced so fast typing doesn't fire a request per keystroke),
/// multi-facet filters, and pagination.
///
/// Every fetch carries a request id so a slow, stale response (e.g. from
/// an earlier keystroke) can never overwrite the results of a newer one.
class ExerciseListNotifier extends StateNotifier<ExerciseListState> {
  ExerciseListNotifier(this._getExercises) : super(const ExerciseListState()) {
    _fetchFirstPage();
  }

  final GetExercises _getExercises;
  Timer? _debounceTimer;
  int _requestId = 0;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<Result<ExercisePage>> _fetch(int offset) {
    final query = state.searchQuery.trim();
    final f = state.filters;
    return _getExercises(
      search: query.isEmpty ? null : query,
      primaryMuscles: f.muscles.toList(),
      equipment: f.equipment == null ? const [] : [f.equipment!],
      exerciseType: f.exerciseType,
      difficulty: f.difficulty,
      offset: offset,
      limit: _pageSize,
    );
  }

  Future<void> _fetchFirstPage() async {
    final id = ++_requestId;
    state = state.copyWith(isLoading: true, isLoadingMore: false, clearError: true);

    final result = await _fetch(0);
    if (!mounted || id != _requestId) return;

    result.when(
      success: (page) {
        state = state.copyWith(
          items: page.items,
          isLoading: false,
          hasMore: page.hasMore,
          nextOffset: page.nextOffset,
          clearError: true,
        );
      },
      failure: (failure) {
        state = state.copyWith(
          items: const [],
          isLoading: false,
          error: failure,
        );
      },
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    final id = _requestId;
    state = state.copyWith(isLoadingMore: true);

    final result = await _fetch(state.nextOffset);
    // A new search/filter started while this page was in flight.
    if (!mounted || id != _requestId) return;

    result.when(
      success: (page) {
        state = state.copyWith(
          items: [...state.items, ...page.items],
          isLoadingMore: false,
          hasMore: page.hasMore,
          nextOffset: page.nextOffset,
        );
      },
      // A failed "load more" keeps existing results visible — only the
      // trailing spinner disappears.
      failure: (_) {
        state = state.copyWith(isLoadingMore: false);
      },
    );
  }

  void updateSearch(String query) {
    if (query == state.searchQuery) return;
    state = state.copyWith(searchQuery: query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_searchDebounce, _fetchFirstPage);
  }

  /// Quick-chip toggle for a single muscle group.
  void toggleMuscle(String muscle) {
    final muscles = {...state.filters.muscles};
    if (!muscles.remove(muscle)) muscles.add(muscle);
    applyFilters(state.filters.copyWith(muscles: muscles));
  }

  /// Replaces every facet filter at once (used by the filter sheet and the
  /// removable active-filter chips).
  void applyFilters(ExerciseLibraryFilters filters) {
    _debounceTimer?.cancel();
    state = state.copyWith(filters: filters);
    _fetchFirstPage();
  }

  /// Clears search and all filters.
  void clearAll() {
    _debounceTimer?.cancel();
    state = state.copyWith(searchQuery: '', filters: ExerciseLibraryFilters.none);
    _fetchFirstPage();
  }

  void retry() => _fetchFirstPage();

  Future<void> refresh() => _fetchFirstPage();
}

final exerciseListProvider =
    StateNotifierProvider<ExerciseListNotifier, ExerciseListState>((ref) {
  return ExerciseListNotifier(ref.watch(getExercisesProvider));
});
