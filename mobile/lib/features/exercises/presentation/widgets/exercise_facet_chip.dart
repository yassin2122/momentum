import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Selectable pill for filter values, styled to match the hub screens.
/// Optional [onRemove] shows a trailing ✕ (used for the active-filter row).
class ExerciseFacetChip extends StatelessWidget {
  const ExerciseFacetChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.showRemove = false,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool showRemove;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    final fg = selected ? AppColors.hubChipText : AppColors.hubTextBody;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: AppColors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: AnimatedContainer(
            duration: AppConstants.animFast,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected ? AppColors.hubHeroGlow : AppColors.hubIconButton,
              borderRadius: radius,
              border: Border.all(
                color: selected
                    ? AppColors.hubAvatarRing
                    : AppColors.hubCardBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: fg,
                    fontWeight: selected
                        ? AppTypography.semiBold
                        : AppTypography.medium,
                  ),
                ),
                if (showRemove) ...[
                  const SizedBox(width: AppSpacing.xxs),
                  Icon(Icons.close, size: AppSizing.iconSm - 2, color: fg),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
