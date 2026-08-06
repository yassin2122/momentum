import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/section_title.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      extendBodyBehindNav: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const SectionTitle(
            title: 'Statistics',
            subtitle: 'Your strength and volume over time',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.trendingUp,
                        size: AppSizing.iconSm,
                        color: AppColors.textTertiary),
                    const SizedBox(width: AppSpacing.xxs),
                    Text('VOLUME TREND', style: AppTypography.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  height: 140,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceElevated,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Text(
                    'Chart coming soon',
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.award,
                        size: AppSizing.iconSm,
                        color: AppColors.textTertiary),
                    const SizedBox(width: AppSpacing.xxs),
                    Text('PERSONAL RECORDS', style: AppTypography.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text('No records yet', style: AppTypography.titleMedium),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Log your first workout to start setting PRs.',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
