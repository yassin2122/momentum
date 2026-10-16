import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../domain/entities/active_workout.dart';
import '../../domain/entities/logged_set.dart';
import '../../domain/entities/workout_enums.dart';
import 'set_row.dart';

enum ExerciseAction { replace, moveUp, moveDown, remove }

/// One exercise in the active workout: header (name, kg/lb toggle, menu),
/// its sets, and "Add set".
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({
    super.key,
    required this.entry,
    required this.isFirst,
    required this.isLast,
    required this.onAction,
    required this.onUnitChanged,
    required this.onAddSet,
    required this.onSetChanged,
    required this.onSetTypeChanged,
    required this.onToggleCompleted,
    required this.onRemoveSet,
  });

  final LoggedExercise entry;
  final bool isFirst;
  final bool isLast;
  final ValueChanged<ExerciseAction> onAction;
  final ValueChanged<WeightUnit> onUnitChanged;
  final VoidCallback onAddSet;
  final void Function(String setId, LoggedSet Function(LoggedSet) update)
      onSetChanged;
  final void Function(String setId, SetType type) onSetTypeChanged;
  final ValueChanged<String> onToggleCompleted;
  final ValueChanged<String> onRemoveSet;

  @override
  Widget build(BuildContext context) {
    final type = entry.exercise.trackingType;
    var working = 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.exercise.name, style: AppTypography.titleLarge),
                    const SizedBox(height: 2),
                    Text(
                      [
                        type.label,
                        if (entry.exercise.equipment != null)
                          entry.exercise.equipment!,
                        if (entry.exercise.isCustom) 'Custom',
                      ].join(' · '),
                      style: AppTypography.caption,
                    ),
                  ],
                ),
              ),
              if (type.hasLoadInput) ...[
                for (final unit in WeightUnit.values)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xxs),
                    child: AppFilterChip(
                      label: unit.dbValue,
                      isSelected: entry.unit == unit,
                      onTap: () => onUnitChanged(unit),
                    ),
                  ),
              ],
              PopupMenuButton<ExerciseAction>(
                tooltip: 'Exercise options',
                color: AppColors.surfaceElevated,
                icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                onSelected: onAction,
                itemBuilder: (context) => [
                  _item(ExerciseAction.replace, 'Replace exercise'),
                  if (!isFirst) _item(ExerciseAction.moveUp, 'Move up'),
                  if (!isLast) _item(ExerciseAction.moveDown, 'Move down'),
                  _item(ExerciseAction.remove, 'Remove from workout',
                      color: AppColors.error),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _ColumnHeaders(type: type, unit: entry.unit),
          const SizedBox(height: AppSpacing.xxs),
          for (var i = 0; i < entry.sets.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
              child: SetRow(
                key: ValueKey(entry.sets[i].id),
                set: entry.sets[i],
                workingNumber: entry.sets[i].setType == SetType.working
                    ? ++working
                    : working,
                trackingType: type,
                unit: entry.unit,
                previous: i < entry.previousSets.length
                    ? entry.previousSets[i]
                    : null,
                onChanged: (update) => onSetChanged(entry.sets[i].id, update),
                onSetTypeChanged: (t) => onSetTypeChanged(entry.sets[i].id, t),
                onToggleCompleted: () => onToggleCompleted(entry.sets[i].id),
                onRemove: () => onRemoveSet(entry.sets[i].id),
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onAddSet,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add set'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryBright,
                textStyle: AppTypography.labelLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<ExerciseAction> _item(
    ExerciseAction action,
    String label, {
    Color color = AppColors.textPrimary,
  }) =>
      PopupMenuItem(
        value: action,
        child: Text(label, style: AppTypography.bodyLarge.copyWith(color: color)),
      );
}

class _ColumnHeaders extends StatelessWidget {
  const _ColumnHeaders({required this.type, required this.unit});

  final TrackingType type;
  final WeightUnit unit;

  @override
  Widget build(BuildContext context) {
    final style = AppTypography.overline;
    return Row(
      children: [
        SizedBox(
          width: SetRow.badgeWidth,
          child: Text('SET', style: style, textAlign: TextAlign.center),
        ),
        const SizedBox(width: AppSpacing.xs),
        if (type.hasLoadInput) ...[
          Expanded(
            child: Text(
              '${type.loadLabel} (${unit.dbValue})'.toUpperCase(),
              style: style,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
        Expanded(
          child: Text(
            type == TrackingType.duration ? 'SECONDS' : 'REPS',
            style: style,
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(width: SetRow.checkWidth),
      ],
    );
  }
}
