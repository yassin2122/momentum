import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/get_exercises.dart';
import 'exercise_list_state.dart';
import 'exercise_providers.dart';

const _pageSize = 30;
const _searchDebounce = Duration(milliseconds: 300);

/// Drives the Exercise Library list: initial load, search-as-you-type
/// (debounced so fast typing doesn't fire a request per keystroke — the
/// "fast search" principle from DESIGN_SYSTEM.md without hammering the
/// network), single-select muscle filter, and pagination.
class ExerciseListNotifier extends StateNotifier<ExerciseListState> {
  ExerciseListNotifier(this._getExercises) : super(const ExerciseListState()) {
    _fetchFirstPage();
  }

  final GetExercises _getExercises;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchFirstPage() async {
    state = state.copyWith(isLoading: true, clearError: true);

    final result = await _getExercises(
      search: state.searchQuery.isEmpty ? null : state.searchQuery,
      primaryMuscles: state.selectedMuscle == null ? const [] : [state.selectedMuscle!],
      offset: 0,
      limit: _pageSize,
    );

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
        state = state.copyWith(isLoading: false, error: failure);
      },
    );
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);

    final result = await _getExercises(
      search: state.searchQuery.isEmpty ? null : state.searchQuery,
      primaryMuscles: state.selectedMuscle == null ? const [] : [state.selectedMuscle!],
      offset: state.nextOffset,
      limit: _pageSize,
    );

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
      // trailing spinner disappears, no full-screen error for a partial
      // failure the user hasn't necessarily even scrolled to see yet.
      failure: (_) {
        state = state.copyWith(isLoadingMore: false);
      },
    );
  }

  void updateSearch(String query) {
    state = state.copyWith(searchQuery: query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_searchDebounce, _fetchFirstPage);
  }

  void selectMuscle(String? muscle) {
    _debounceTimer?.cancel();
    final isDeselecting = state.selectedMuscle == muscle;
    state = state.copyWith(
      selectedMuscle: isDeselecting ? null : muscle,
      clearMuscle: isDeselecting,
    );
    _fetchFirstPage();
  }

  void retry() => _fetchFirstPage();
}

final exerciseListProvider =
    StateNotifierProvider<ExerciseListNotifier, ExerciseListState>((ref) {
  return ExerciseListNotifier(ref.watch(getExercisesProvider));
});
