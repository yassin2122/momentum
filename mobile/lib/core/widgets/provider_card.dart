import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_sizing.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'hub_ui.dart';

/// One card layout for every provider list in CONNECT — coaches, gyms and
/// health pros — so the three look like one system (Law of Similarity):
///
///   [photo]  Name                         [trailing]
///            [type] [badges…]
///            What they do
///            📍 Where · extra
///            One key fact (fee, offers…)
///
/// The whole card opens the profile; [trailing] is for one secondary
/// action (save) or a status.
class ProviderCard extends StatelessWidget {
  const ProviderCard({
    required this.leading,
    required this.title,
    required this.onTap,
    this.badges = const [],
    this.subtitle,
    this.location,
    this.fact,
    this.trailing,
    super.key,
  });

  /// 56 pt photo or logo.
  final Widget leading;
  final String title;
  final List<Widget> badges;
  final String? subtitle;
  final String? location;
  final String? fact;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        HubCard(
          onTap: onTap,
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            trailing == null ? AppSpacing.md : AppSpacing.xl2 + AppSpacing.xs,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              leading,
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.hubTextBright,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    if (badges.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Wrap(
                        spacing: AppSpacing.xxs,
                        runSpacing: AppSpacing.xxs,
                        children: badges,
                      ),
                    ],
                    if (subtitle != null && subtitle!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
                      ),
                    ],
                    if (location != null && location!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            const Icon(LucideIcons.mapPin,
                                size: AppSizing.iconSm - 2, color: AppColors.hubTextMuted),
                            const SizedBox(width: AppSpacing.xxs),
                            Expanded(
                              child: Text(
                                location!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.labelMedium
                                    .copyWith(color: AppColors.hubTextMuted),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (fact != null && fact!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          fact!,
                          style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextFaint),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (trailing != null)
          Positioned(right: AppSpacing.xxs, top: AppSpacing.xxs, child: trailing!),
      ],
    );
  }
}

/// The type pill on a [ProviderCard] ("Coach", "Gym", "Doctor"…).
class ProviderTypeChip extends StatelessWidget {
  const ProviderTypeChip({required this.label, required this.icon, super.key});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) => HubPill(
        label: label,
        icon: icon,
        fill: AppColors.hubHeroGlow,
        textColor: AppColors.hubChipText,
      );
}

/// Heart button for saving a provider (44 pt target).
class ProviderSaveButton extends StatelessWidget {
  const ProviderSaveButton({
    required this.saved,
    required this.name,
    required this.onPressed,
    super.key,
  });

  final bool saved;
  final String name;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: saved ? 'Remove $name from saved' : 'Save $name',
        onPressed: onPressed,
        icon: Icon(
          LucideIcons.heart,
          size: AppSizing.iconMd,
          color: saved ? AppColors.hubDanger : AppColors.hubTextMuted,
        ),
      );
}

/// Placeholder [ProviderCard]s while a directory loads, so the page keeps
/// its shape instead of showing a spinner.
class ProviderCardSkeleton extends StatelessWidget {
  const ProviderCardSkeleton({
    this.semanticLabel = 'Loading',
    this.count = 3,
    super.key,
  });

  final String semanticLabel;
  final int count;

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.hubIconButton,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
    return Semantics(
      label: semanticLabel,
      child: Column(
        children: [
          for (var i = 0; i < count; i++) ...[
            HubCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.hubIconButton),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(150, 14),
                      const SizedBox(height: AppSpacing.xs),
                      bar(90, 12),
                      const SizedBox(height: AppSpacing.xs),
                      bar(190, 12),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}
