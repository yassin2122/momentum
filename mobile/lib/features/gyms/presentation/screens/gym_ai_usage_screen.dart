import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../domain/entities/gym_entities.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_ui.dart';

/// AI tools & usage for a gym. Allowances come from the gym's Grit
/// partnership and are enforced on the server. No AI tool is connected in
/// this version, so every feature is labelled "Not connected yet" and
/// usage stays at zero until one ships.
class GymAiUsageScreen extends ConsumerWidget {
  const GymAiUsageScreen({required this.gymId, super.key});

  final String gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(gymOverviewProvider(gymId));
    final coaches = ref.watch(gymCoachesAdminProvider(gymId)).valueOrNull?.coaches ?? const [];

    return overview.when(
      loading: () => const HubPage(children: [
        SizedBox(height: AppSpacing.xl4),
        HubLoading(),
      ]),
      error: (e, _) => HubPage(bottomPadding: AppSpacing.xl2, children: [
        GymTitleBar(title: 'AI tools & usage', onBack: () => context.pop()),
        const SizedBox(height: AppSpacing.md),
        HubMessageCard(
          icon: LucideIcons.circleAlert,
          title: "Couldn't load AI usage",
          message: gymErrorMessage(e),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(gymOverviewProvider(gymId)),
        ),
      ]),
      data: (o) {
        final p = o.partnership;
        final active = p?.isActive ?? false;
        return HubPage(
          bottomPadding: AppSpacing.xl2,
          children: [
            GymTitleBar(
              eyebrow: o.name,
              title: 'AI tools & usage',
              onBack: () => context.pop(),
            ),
            const SizedBox(height: AppSpacing.md),
            const GymNote(
              'AI tools aren\'t connected in this version of Grit yet. Your '
              'allowance and coach limits are ready; usage starts counting '
              'when the first tool goes live.',
              icon: LucideIcons.flaskConical,
            ),
            const SizedBox(height: AppSpacing.md),
            HubCard(
              hero: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text('This month',
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.hubTextBright,
                              fontWeight: AppTypography.bold,
                            )),
                      ),
                      GymStatusPill(
                        p == null ? 'Not a partner' : p.status.label,
                        tone: active ? GymTone.positive : GymTone.neutral,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (p == null)
                    Text(
                      'AI tools come with a Grit partnership. Request one from '
                      'Settings → Grit partnership.',
                      style:
                          AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
                    )
                  else ...[
                    Text.rich(
                      TextSpan(children: [
                        TextSpan(
                          text: '${p.usedThisMonth}',
                          style: AppTypography.headlineLarge.copyWith(
                            color: AppColors.hubTextNumber,
                            fontWeight: AppTypography.extraBold,
                          ),
                        ),
                        TextSpan(
                          text: '  of ${p.monthlyAllowance} AI actions',
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.hubTextMuted),
                        ),
                      ]),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    HubProgressBar(value: p.usedFraction),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      p.perCoachCap == null
                          ? 'Shared by all your coaches · resets on the 1st'
                          : 'Up to ${p.perCoachCap} per coach · resets on the 1st',
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.hubTextMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            GymSection(
              header: 'AI tools',
              footer: 'Which tools are included is part of your partnership. '
                  'Grit sets them; coaches see the same list.',
              children: [
                for (final f in GymAiFeature.values)
                  GymRow(
                    icon: LucideIcons.sparkles,
                    title: f.label,
                    subtitle: f.description,
                    showChevron: false,
                    trailing: GymStatusPill(
                      !f.available
                          ? 'Not connected yet'
                          : (p?.features.contains(f) ?? false)
                              ? 'Included'
                              : 'Not included',
                      tone: !f.available
                          ? GymTone.neutral
                          : (p?.features.contains(f) ?? false)
                              ? GymTone.positive
                              : GymTone.neutral,
                    ),
                  ),
              ],
            ),
            if (p != null) ...[
              const SizedBox(height: AppSpacing.lg),
              GymSection(
                header: 'By coach',
                children: coaches.isEmpty
                    ? const [
                        GymRow(
                          title: 'No coaches yet',
                          subtitle: 'Coaches who join your gym share the allowance.',
                          showChevron: false,
                        ),
                      ]
                    : [
                        for (final c in coaches)
                          GymRow(
                            leading: HubAvatar(name: c.name, imageUrl: c.avatarUrl, size: 32),
                            title: c.name,
                            value: p.perCoachCap == null
                                ? '${c.aiUsedThisMonth} used'
                                : '${c.aiUsedThisMonth} of ${p.perCoachCap}',
                            showChevron: false,
                          ),
                      ],
              ),
            ],
          ],
        );
      },
    );
  }
}
