import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Standard filter toggle chip. Used standalone (quick single-facet
/// filters, e.g. Exercise Library's muscle group row) and can be reused
/// inside a bottom sheet for compound filtering later.
///
/// Named `AppFilterChip` rather than `FilterChip` (as originally
/// documented in COMPONENT_LIBRARY.md) because `FilterChip` collides
/// with Flutter Material's own built-in widget of that name — every
/// screen imports `material.dart`, so the collision is real, not
/// theoretical. Update COMPONENT_LIBRARY.md to reflect this rename.
class AppFilterChip extends StatelessWidget {
  const AppFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: AnimatedContainer(
        duration: AppConstants.animInstant,
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryMuted.withValues(alpha: 0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.stroke,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
