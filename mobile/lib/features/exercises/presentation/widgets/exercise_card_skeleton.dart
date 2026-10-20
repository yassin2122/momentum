import 'package:flutter/material.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../../core/widgets/loading_skeleton.dart';

/// Shimmer placeholder shaped like [ExerciseCard], shown while the first
/// page loads — telegraphs the real layout rather than a generic spinner.
class ExerciseCardSkeleton extends StatelessWidget {
  const ExerciseCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const HubCard(
      padding: EdgeInsets.all(AppSpacing.xs),
      child: Row(
        children: [
          LoadingSkeleton(width: 60, height: 60, borderRadius: AppRadius.medium),
          SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LoadingSkeleton(width: 160, height: 16),
                SizedBox(height: AppSpacing.xs),
                LoadingSkeleton(width: 110, height: 12),
                SizedBox(height: AppSpacing.xs),
                LoadingSkeleton(width: 70, height: 18, borderRadius: AppRadius.pill),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
