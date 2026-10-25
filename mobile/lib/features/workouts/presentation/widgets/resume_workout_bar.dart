import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/active_workout.dart';
import 'elapsed_time.dart';

/// Mini bar for a workout that's still running, pinned just above the
/// floating nav bar (like the MiniPlayer in Apple Music). Same frosted
/// glass as the nav bar, so the two read as one floating layer. The whole
/// bar is the Resume target.
class ResumeWorkoutBar extends StatelessWidget {
  const ResumeWorkoutBar({
    required this.workout,
    required this.onResume,
    super.key,
  });

  final ActiveWorkout workout;
  final VoidCallback onResume;

  /// Height of the bar; screens add this to their bottom scroll padding.
  static const double height = 60;

  /// Same width cap as the nav pill so their edges line up.
  static const double maxWidth = 360;

  @override
  Widget build(BuildContext context) {
    final done = workout.exercises
        .expand((e) => e.sets)
        .where((s) => s.completed)
        .length;
    final radius = BorderRadius.circular(AppRadius.pill);
    final muted = AppTypography.numeric(AppTypography.labelMedium)
        .copyWith(color: AppColors.hubTextMuted);

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Semantics(
            button: true,
            label: 'Resume workout, ${workout.title}',
            excludeSemantics: true,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: AppShadows.floating,
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Material(
                    type: MaterialType.transparency,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        onResume();
                      },
                      child: Ink(
                        height: height,
                        decoration: BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(color: AppColors.navGlassRim),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.navGlassTop,
                              AppColors.navGlassBottom,
                            ],
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.xs + 2,
                          0,
                          AppSpacing.xs + 2,
                          0,
                        ),
                        child: Row(
                          children: [
                            const _Orb(),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    workout.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.titleSmall.copyWith(
                                      color: AppColors.hubTextBright,
                                      fontWeight: AppTypography.semiBold,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      ElapsedTime(
                                        since: workout.startedAt,
                                        style: muted,
                                      ),
                                      Flexible(
                                        child: Text(
                                          ' · $done set${done == 1 ? '' : 's'} done',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: muted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            const _ResumePill(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small START-orb gradient circle, so the bar reads as "your workout".
class _Orb extends StatelessWidget {
  const _Orb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.ctaGradientStart,
            AppColors.ctaGradientMid,
            AppColors.ctaGradientEnd,
          ],
        ),
        border: Border.all(color: AppColors.navGlassHighlight),
      ),
      child: const Icon(
        LucideIcons.dumbbell,
        size: AppSizing.iconSm,
        color: AppColors.white,
      ),
    );
  }
}

class _ResumePill extends StatelessWidget {
  const _ResumePill();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm + 2),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            LucideIcons.play,
            size: AppSizing.iconSm - 2,
            color: AppColors.hubBackgroundBottom,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            'Resume',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.hubBackgroundBottom,
              fontWeight: AppTypography.bold,
            ),
          ),
        ],
      ),
    );
  }
}
