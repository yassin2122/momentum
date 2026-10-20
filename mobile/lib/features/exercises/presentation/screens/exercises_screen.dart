import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../domain/entities/exercise_entity.dart';
import '../providers/exercise_filters_provider.dart';
import '../providers/exercise_list_notifier.dart';
import '../providers/exercise_list_state.dart';
import '../widgets/exercise_card.dart';
import '../widgets/exercise_card_skeleton.dart';
import '../widgets/exercise_detail_sheet.dart';
import '../widgets/exercise_facet_chip.dart';
import '../widgets/exercise_filter_sheet.dart';
import '../widgets/exercise_labels.dart';

/// TRAIN · Exercise Library.
///
/// Layout, top to bottom:
///   * header + search (always visible, search-as-you-type)
///   * quick muscle-group chips and a Filters button (muscle, equipment,
///     type, level) with an active-filter count
///   * removable chips for the active equipment/type/level filters
///   * results, A–Z with letter headers, paginated on scroll
/// Tapping a row opens the detail sheet with images and instructions.
class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  final _scrollController = ScrollController();
  late final TextEditingController _searchController = TextEditingController(
    text: ref.read(exerciseListProvider).searchQuery,
  );

  ExerciseListNotifier get _notifier => ref.read(exerciseListProvider.notifier);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    final p = _scrollController.position;
    if (p.pixels > p.maxScrollExtent - 400) _notifier.loadMore();
  }

  void _clearAll() {
    _searchController.clear();
    FocusScope.of(context).unfocus();
    _notifier.clearAll();
  }

  Future<void> _openFilters(ExerciseFilterOptions options) async {
    FocusScope.of(context).unfocus();
    final result = await showExerciseFilterSheet(
      context,
      current: ref.read(exerciseListProvider).filters,
      options: options,
    );
    if (result != null) _notifier.applyFilters(result);
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.train);

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exerciseListProvider);
    // New search or filters → start reading from the top again.
    ref.listen(
      exerciseListProvider.select((s) => (s.searchQuery, s.filters)),
      (_, __) {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      },
    );
    final options =
        ref.watch(exerciseFiltersProvider).valueOrNull ?? ExerciseFilterOptions.empty;

    return Scaffold(
      backgroundColor: AppColors.hubBackgroundBottom,
      body: HubBackground(
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(onBack: _back),
                    const SizedBox(height: AppSpacing.md),
                    AppSearchField(
                      controller: _searchController,
                      hintText: 'Search by name, e.g. "bench press"',
                      onChanged: _notifier.updateSearch,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
              _QuickFilterRow(
                options: options,
                filters: state.filters,
                onOpenFilters: () => _openFilters(options),
                onAllMuscles: () => _notifier.applyFilters(
                  state.filters.copyWith(muscles: const {}),
                ),
                onToggleMuscle: _notifier.toggleMuscle,
              ),
              _ActiveFilterRow(
                filters: state.filters,
                showClearAll: state.hasActiveFilters,
                onChanged: _notifier.applyFilters,
                onClearAll: _clearAll,
              ),
              Expanded(child: _buildResults(state)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults(ExerciseListState state) {
    const listPadding = EdgeInsets.fromLTRB(
      AppSpacing.sm,
      AppSpacing.xs,
      AppSpacing.sm,
      AppSpacing.xl2,
    );

    if (state.isLoading && state.items.isEmpty) {
      return ListView.separated(
        padding: listPadding,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (_, __) => const ExerciseCardSkeleton(),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return ListView(
        padding: listPadding,
        children: [
          HubMessageCard(
            icon: LucideIcons.wifiOff,
            title: "Couldn't load exercises",
            message: state.error!.message,
            actionLabel: 'Retry',
            onAction: _notifier.retry,
          ),
        ],
      );
    }

    if (state.isEmpty) {
      final q = state.searchQuery.trim();
      return ListView(
        padding: listPadding,
        children: [
          HubMessageCard(
            icon: LucideIcons.search,
            title: 'No exercises found',
            message: state.hasActiveFilters
                ? q.isEmpty
                    ? 'Nothing matches these filters. Try removing one.'
                    : 'Nothing matches "$q" with these filters.'
                : 'The exercise library is empty right now.',
            actionLabel: state.hasActiveFilters ? 'Clear search & filters' : null,
            onAction: state.hasActiveFilters ? _clearAll : null,
          ),
        ],
      );
    }

    final rows = _buildRows(state.items);

    return RefreshIndicator(
      color: AppColors.hubEyebrow,
      backgroundColor: AppColors.hubCardTop,
      onRefresh: _notifier.refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: listPadding,
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: rows.length + 2,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _ResultsSummary(
              loaded: state.items.length,
              hasMore: state.hasMore,
              refreshing: state.isLoading,
            );
          }
          if (index == rows.length + 1) {
            return state.isLoadingMore
                ? const HubLoading()
                : const SizedBox(height: AppSpacing.md);
          }
          return switch (rows[index - 1]) {
            _LetterRow(:final letter) => _LetterHeader(letter: letter),
            _ExerciseRow(:final exercise) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: ExerciseCard(
                  exercise: exercise,
                  onTap: () {
                    FocusScope.of(context).unfocus();
                    showExerciseDetailSheet(context, summary: exercise);
                  },
                ),
              ),
          };
        },
      ),
    );
  }

  /// Interleaves A–Z letter headers into the (server-sorted by name) list.
  static List<_Row> _buildRows(List<ExerciseEntity> items) {
    final rows = <_Row>[];
    String? current;
    for (final e in items) {
      final letter = ExerciseLabels.sectionLetter(e.name);
      if (letter != current) {
        rows.add(_LetterRow(letter));
        current = letter;
      }
      rows.add(_ExerciseRow(e));
    }
    return rows;
  }
}

sealed class _Row {
  const _Row();
}

final class _LetterRow extends _Row {
  const _LetterRow(this.letter);
  final String letter;
}

final class _ExerciseRow extends _Row {
  const _ExerciseRow(this.exercise);
  final ExerciseEntity exercise;
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HubBackButton(onPressed: onBack),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HubEyebrow('Train · Library'),
              Text(
                'Exercise Library',
                style: AppTypography.headlineMedium.copyWith(
                  color: AppColors.hubTextBright,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Filters button + horizontally scrolling muscle chips.
class _QuickFilterRow extends StatelessWidget {
  const _QuickFilterRow({
    required this.options,
    required this.filters,
    required this.onOpenFilters,
    required this.onAllMuscles,
    required this.onToggleMuscle,
  });

  final ExerciseFilterOptions options;
  final ExerciseLibraryFilters filters;
  final VoidCallback onOpenFilters;
  final VoidCallback onAllMuscles;
  final ValueChanged<String> onToggleMuscle;

  @override
  Widget build(BuildContext context) {
    final muscles = options.primaryMuscles;
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        children: [
          _FiltersButton(count: filters.count, onTap: onOpenFilters),
          if (muscles.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.xs),
            ExerciseFacetChip(
              label: 'All muscles',
              selected: filters.muscles.isEmpty,
              onTap: onAllMuscles,
            ),
            for (final m in muscles) ...[
              const SizedBox(width: AppSpacing.xs),
              ExerciseFacetChip(
                label: ExerciseLabels.title(m),
                selected: filters.muscles.contains(m),
                onTap: () => onToggleMuscle(m),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _FiltersButton extends StatelessWidget {
  const _FiltersButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    final active = count > 0;
    return Semantics(
      button: true,
      label: active ? 'Filters, $count active' : 'Filters',
      child: Material(
        color: AppColors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                colors: [AppColors.authCtaStart, AppColors.authCtaEnd],
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.tune_rounded,
                  size: AppSizing.iconSm,
                  color: AppColors.hubTextBright,
                ),
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  'Filters',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
                if (active) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  Container(
                    constraints: const BoxConstraints(minWidth: 18),
                    height: 18,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.accentAction,
                      borderRadius: radius,
                    ),
                    child: Text(
                      '$count',
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.hubTextBright,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Removable chips for the sheet-only filters, plus "Clear all".
class _ActiveFilterRow extends StatelessWidget {
  const _ActiveFilterRow({
    required this.filters,
    required this.showClearAll,
    required this.onChanged,
    required this.onClearAll,
  });

  final ExerciseLibraryFilters filters;
  final bool showClearAll;
  final ValueChanged<ExerciseLibraryFilters> onChanged;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (filters.equipment case final v?)
        ExerciseFacetChip(
          label: ExerciseLabels.title(v),
          selected: true,
          showRemove: true,
          onTap: () => onChanged(filters.copyWith(equipment: () => null)),
        ),
      if (filters.exerciseType case final v?)
        ExerciseFacetChip(
          label: ExerciseLabels.title(v),
          selected: true,
          showRemove: true,
          onTap: () => onChanged(filters.copyWith(exerciseType: () => null)),
        ),
      if (filters.difficulty case final v?)
        ExerciseFacetChip(
          label: ExerciseLabels.title(v),
          selected: true,
          showRemove: true,
          onTap: () => onChanged(filters.copyWith(difficulty: () => null)),
        ),
    ];

    return AnimatedSize(
      duration: AppConstants.animFast,
      alignment: Alignment.topCenter,
      child: chips.isEmpty && !showClearAll
          ? const SizedBox(width: double.infinity, height: AppSpacing.xs)
          : Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xs,
                AppSpacing.sm,
                0,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: chips,
                    ),
                  ),
                  if (showClearAll)
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xxs),
                      child: HubLink(label: 'Clear all', onTap: onClearAll),
                    ),
                ],
              ),
            ),
    );
  }
}

class _ResultsSummary extends StatelessWidget {
  const _ResultsSummary({
    required this.loaded,
    required this.hasMore,
    required this.refreshing,
  });

  final int loaded;
  final bool hasMore;
  final bool refreshing;

  @override
  Widget build(BuildContext context) {
    final count = hasMore ? '$loaded+' : '$loaded';
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.xxs,
        bottom: AppSpacing.xs,
        left: AppSpacing.xxs,
      ),
      child: Row(
        children: [
          Text(
            '$count exercise${loaded == 1 && !hasMore ? '' : 's'} · A–Z',
            style: AppTypography.labelMedium
                .copyWith(color: AppColors.hubTextMuted),
          ),
          if (refreshing) ...[
            const SizedBox(width: AppSpacing.xs),
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                color: AppColors.hubEyebrow,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LetterHeader extends StatelessWidget {
  const _LetterHeader({required this.letter});

  final String letter;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xxs,
        AppSpacing.sm,
        AppSpacing.xxs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Text(
            letter,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.hubEyebrow,
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Expanded(
            child: Divider(height: 1, color: AppColors.hubCardBorder),
          ),
        ],
      ),
    );
  }
}
