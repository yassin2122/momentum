import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizing.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'hub_ui.dart';

/// Placeholder root for a shell tab that isn't built yet (Coach,
/// Universe). Same hub canvas as the live tabs, so switching to it
/// doesn't flash a different background.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.hubBackgroundBottom,
      body: HubBackground(
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              kNavClearance,
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: AppSizing.minTouchTarget + AppSpacing.md,
                    height: AppSizing.minTouchTarget + AppSpacing.md,
                    decoration: BoxDecoration(
                      color: AppColors.hubCardTop,
                      borderRadius: BorderRadius.circular(AppRadius.hubCard),
                      border: Border.all(color: AppColors.hubCardBorder),
                    ),
                    child: Icon(
                      icon,
                      size: AppSizing.iconMd,
                      color: AppColors.accentProgress,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  HubEyebrow(eyebrow),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    title,
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.hubTextBright,
                      fontWeight: AppTypography.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.hubTextFaint,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
