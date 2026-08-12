import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/section_title.dart';
import '../../../../core/theme/app_sizing.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      extendBodyBehindNav: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const SectionTitle(
            title: 'Profile',
            subtitle: 'Your account and preferences',
          ),
          const SizedBox(height: AppSpacing.xl),
          AppCard(
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceElevated,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    color: AppColors.textSecondary,
                    size: AppSizing.iconMd,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Guest', style: AppTypography.titleMedium),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Your progress is only saved on this device',
                        style: AppTypography.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            color: AppColors.surfaceElevated,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.cloud,
                        size: AppSizing.iconSm, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.xxs),
                    Text('SYNC YOUR PROGRESS', style: AppTypography.caption),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Create an account to back up your workouts and access '
                  'them on any device.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                // Placeholder-data screen — not wired to Auth this
                // sprint, per scope.
                const PrimaryButton(
                  label: 'Create Account',
                  onPressed: null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
