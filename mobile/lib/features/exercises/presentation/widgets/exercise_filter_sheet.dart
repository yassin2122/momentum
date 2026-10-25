import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../domain/entities/exercise_entity.dart';
import '../providers/exercise_list_state.dart';
import 'exercise_facet_chip.dart';
import 'exercise_labels.dart';

/// Opens the full filter sheet. Resolves to the new filters when the user
/// taps "Show results", or null if they dismiss it.
Future<ExerciseLibraryFilters?> showExerciseFilterSheet(
  BuildContext context, {
  required ExerciseLibraryFilters current,
  required ExerciseFilterOptions options,
}) {
  return showModalBottomSheet<ExerciseLibraryFilters>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.hubBackgroundBottom,
    barrierColor: AppColors.achScrim,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.85,
      child: HubBackground(
        glowCenter: const Alignment(0.4, -1),
        child: _FilterSheet(initial: current, options: options),
      ),
    ),
  );
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial, required this.options});

  final ExerciseLibraryFilters initial;
  final ExerciseFilterOptions options;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ExerciseLibraryFilters _draft = widget.initial;

  void _toggleMuscle(String m) {
    final next = {..._draft.muscles};
    if (!next.remove(m)) next.add(m);
    setState(() => _draft = _draft.copyWith(muscles: next));
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.xs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Filter exercises',
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
              if (!_draft.isEmpty)
                HubLink(
                  label: 'Reset',
                  onTap: () =>
                      setState(() => _draft = ExerciseLibraryFilters.none),
                ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close,
                  color: AppColors.hubTextBody,
                  size: AppSizing.iconMd - 2,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            children: [
              _Section(
                title: 'Muscle group',
                hint: 'Pick one or more',
                values: o.primaryMuscles,
                isSelected: _draft.muscles.contains,
                onTap: _toggleMuscle,
              ),
              _Section(
                title: 'Equipment',
                values: o.equipment,
                isSelected: (v) => _draft.equipment == v,
                onTap: (v) => setState(() => _draft = _draft.copyWith(
                      equipment: () => _draft.equipment == v ? null : v,
                    )),
              ),
              _Section(
                title: 'Exercise type',
                values: o.exerciseTypes,
                isSelected: (v) => _draft.exerciseType == v,
                onTap: (v) => setState(() => _draft = _draft.copyWith(
                      exerciseType: () => _draft.exerciseType == v ? null : v,
                    )),
              ),
              _Section(
                title: 'Level',
                values: ExerciseLabels.sortDifficulties(o.difficulties),
                isSelected: (v) => _draft.difficulty == v,
                onTap: (v) => setState(() => _draft = _draft.copyWith(
                      difficulty: () => _draft.difficulty == v ? null : v,
                    )),
              ),
            ],
          ),
        ),
        HubBottomBar(
          child: HubGradientButton(
            label: _draft.isEmpty
                ? 'Show all exercises'
                : 'Show results (${_draft.count} '
                    'filter${_draft.count == 1 ? '' : 's'})',
            height: AppSizing.buttonHeight,
            onPressed: () => Navigator.of(context).pop(_draft),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.values,
    required this.isSelected,
    required this.onTap,
    this.hint,
  });

  final String title;
  final String? hint;
  final List<String> values;
  final bool Function(String) isSelected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HubEyebrow(title),
              if (hint != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Text(
                  hint!,
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.hubTextFaint),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final v in values)
                ExerciseFacetChip(
                  label: ExerciseLabels.title(v),
                  selected: isSelected(v),
                  onTap: () => onTap(v),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
