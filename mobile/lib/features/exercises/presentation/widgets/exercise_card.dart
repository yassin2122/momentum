import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../../core/widgets/network_photo.dart';
import '../../domain/entities/exercise_entity.dart';
import 'exercise_labels.dart';

/// One row in the Exercise Library: thumbnail, name, muscle · equipment,
/// and a difficulty pill.
class ExerciseCard extends StatelessWidget {
  const ExerciseCard({required this.exercise, this.onTap, super.key});

  final ExerciseEntity exercise;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (exercise.primaryMuscle.isNotEmpty)
        ExerciseLabels.title(exercise.primaryMuscle),
      if (exercise.equipmentLabel case final label?) ExerciseLabels.title(label),
    ].join(' · ');

    return HubCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        children: [
          ExerciseThumbnail(url: exercise.thumbnailUrl, size: 60),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodySmall
                        .copyWith(color: AppColors.hubTextMuted),
                  ),
                ],
                if (exercise.difficulty != null || exercise.isCustom) ...[
                  const SizedBox(height: AppSpacing.xxs + 2),
                  Wrap(
                    spacing: AppSpacing.xxs,
                    runSpacing: AppSpacing.xxs,
                    children: [
                      if (exercise.difficulty case final d?)
                        DifficultyPill(difficulty: d),
                      if (exercise.isCustom)
                        const HubPill(
                          label: 'Custom',
                          fill: AppColors.hubShareOffFill,
                          textColor: AppColors.hubTextBody,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xxs),
          const Icon(
            LucideIcons.chevronRight,
            color: AppColors.hubTextFaint,
            size: AppSizing.iconSm + 2,
          ),
        ],
      ),
    );
  }
}

/// Small colored level pill: green → amber → red as it gets harder.
class DifficultyPill extends StatelessWidget {
  const DifficultyPill({required this.difficulty, super.key});

  final String difficulty;

  @override
  Widget build(BuildContext context) {
    final (fill, text) = switch (difficulty.toLowerCase()) {
      'beginner' => (AppColors.hubShareOnFill, AppColors.hubShareOnText),
      'intermediate' => (AppColors.hubWaitFill, AppColors.hubWaitText),
      'expert' => (AppColors.errorContainer, AppColors.hubDanger),
      _ => (AppColors.hubShareOffFill, AppColors.hubTextBody),
    };
    return HubPill(
      label: ExerciseLabels.title(difficulty),
      fill: fill,
      textColor: text,
    );
  }
}

/// Rounded exercise image with a dumbbell fallback while loading or when
/// the exercise has no image.
class ExerciseThumbnail extends StatelessWidget {
  const ExerciseThumbnail({required this.url, this.size = 60, super.key});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: AppColors.hubIconButton,
      child: Center(
        child: Icon(
          LucideIcons.dumbbell,
          color: AppColors.hubTextFaint,
          size: size * 0.38,
        ),
      ),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: SizedBox.square(
        dimension: size,
        child: u == null || u.isEmpty
            ? fallback
            : NetworkPhoto(
                url: u,
                cacheWidth: (size * 3).round(),
                placeholder: fallback,
              ),
      ),
    );
  }
}
