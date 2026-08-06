import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/section_title.dart';
import '../providers/exercise_filters_provider.dart';
import '../providers/exercise_list_notifier.dart';
import '../providers/exercise_list_state.dart';
import '../widgets/exercise_card.dart';
import '../widgets/exercise_card_skeleton.dart';

class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_handleScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_scrollController.position.pixels >
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(exerciseListProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(exerciseListProvider);
    final filtersAsync = ref.watch(exerciseFiltersProvider);

    return AppScaffold(
      scrollable: false,
      extendBodyBehindNav: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const SectionTitle(
            title: 'Exercise Library',
            subtitle: '150+ exercises with form guidance',
          ),
          const SizedBox(height: AppSpacing.md),
          AppSearchField(
            hintText: 'Search exercises...',
            onChanged: (value) =>
                ref.read(exerciseListProvider.notifier).updateSearch(value),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 36,
            child: filtersAsync.when(
              data: (filters) => _MuscleFilterRow(
                muscles: filters.primaryMuscles,
                selected: state.selectedMuscle,
                onSelect: (muscle) =>
                    ref.read(exerciseListProvider.notifier).selectMuscle(muscle),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(child: _buildBody(state)),
        ],
      ),
    );
  }

  Widget _buildBody(ExerciseListState state) {
    if (state.isLoading) {
      return ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, __) => const ExerciseCardSkeleton(),
      );
    }

    if (state.error != null && state.items.isEmpty) {
      return Center(
        child: EmptyState(
          icon: LucideIcons.wifiOff,
          title: "Couldn't load exercises",
          message: state.error!.message,
          actionLabel: 'Retry',
          onAction: () => ref.read(exerciseListProvider.notifier).retry(),
        ),
      );
    }

    if (state.isEmpty) {
      final hasActiveQuery =
          state.searchQuery.isNotEmpty || state.selectedMuscle != null;
      return Center(
        child: EmptyState(
          icon: LucideIcons.search,
          title: 'No exercises found',
          message: hasActiveQuery
              ? 'Try a different search term or clear your filters.'
              : 'The exercise library is empty right now.',
          actionLabel: hasActiveQuery ? 'Clear filters' : null,
          onAction: hasActiveQuery
              ? () {
                  ref.read(exerciseListProvider.notifier)
                    ..updateSearch('')
                    ..selectMuscle(null);
                }
              : null,
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      padding: EdgeInsets.zero,
      itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index >= state.items.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
            ),
          );
        }
        return ExerciseCard(exercise: state.items[index]);
      },
    );
  }
}

class _MuscleFilterRow extends StatelessWidget {
  const _MuscleFilterRow({
    required this.muscles,
    required this.selected,
    required this.onSelect,
  });

  final List<String> muscles;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    if (muscles.isEmpty) return const SizedBox.shrink();

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: muscles.length,
      separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
      itemBuilder: (context, index) {
        final muscle = muscles[index];
        return AppFilterChip(
          label: muscle[0].toUpperCase() + muscle.substring(1),
          isSelected: selected == muscle,
          onTap: () => onSelect(muscle),
        );
      },
    );
  }
}
