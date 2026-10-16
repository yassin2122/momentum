import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../domain/entities/exercise_entity.dart';
import '../../../../core/theme/app_sizing.dart';

/// List row for one exercise. Browse mode only — picker mode (per
/// COMPONENT_LIBRARY.md, for future Workout Session use) is intentionally
/// not built this sprint.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({required this.exercise, this.onTap, super.key});

  final ExerciseEntity exercise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          _Thumbnail(exercise: exercise),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  style: AppTypography.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  [
                    _capitalize(exercise.primaryMuscle),
                    if (exercise.equipmentLabel case final label?) label,
                  ].join(' · '),
                  style: AppTypography.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            color: AppColors.textTertiary,
            size: AppSizing.iconSm,
          ),
        ],
      ),
    );
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';
}

/// Lazy-loaded thumbnail with a muscle-icon fallback. GIF loading itself
/// (via cached_network_image) is future work once real gif_url assets
/// exist in the seed data — the fallback path is what actually renders
/// today, since the starter seed has no image URLs (no fake/broken links
/// per the no-fake-data rule).
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.exercise});

  final ExerciseEntity exercise;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      alignment: Alignment.center,
      child: const Icon(
        Icons.fitness_center,
        color: AppColors.textTertiary,
        size: AppSizing.iconMd,
      ),
    );
  }
}
