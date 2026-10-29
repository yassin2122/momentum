import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../domain/entities/gym_entities.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_ui.dart';
import 'gym_coaches_tab.dart';
import 'gym_inquiries_tab.dart';
import 'gym_listing_tab.dart';
import 'gym_settings_tab.dart';

/// The gym dashboard: a full-screen area with its own tab bar
/// (Overview · Listing · Coaches · Inquiries · Settings). Branches & offers
/// and AI usage are pushed from here. What each teammate sees follows their
/// role; the database enforces the same rules.
class GymAdminScreen extends ConsumerStatefulWidget {
  const GymAdminScreen({required this.gymId, super.key});

  final String gymId;

  @override
  ConsumerState<GymAdminScreen> createState() => _GymAdminScreenState();
}

class _GymAdminScreenState extends ConsumerState<GymAdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final overview = ref.watch(gymOverviewProvider(widget.gymId));
    return overview.when(
      loading: () => const HubPage(children: [
        SizedBox(height: AppSpacing.xl4),
        HubLoading(),
      ]),
      error: (e, _) => HubPage(bottomPadding: AppSpacing.xl2, children: [
        GymTitleBar(title: 'Gym dashboard', onBack: () => context.pop()),
        const SizedBox(height: AppSpacing.md),
        HubMessageCard(
          icon: LucideIcons.circleAlert,
          title: "Couldn't open the dashboard",
          message: gymErrorMessage(e),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(gymOverviewProvider(widget.gymId)),
        ),
      ]),
      data: (o) {
        final role = o.role;
        final labels = [
          'Overview',
          'Listing',
          if (role.canManageCoaches) 'Coaches',
          if (role.canSeeInquiries) 'Inquiries',
          'Settings',
        ];
        final tabs = <(IconData, String, Widget)>[
          (
            LucideIcons.layoutDashboard,
            'Overview',
            GymOverviewTab(
              overview: o,
              onOpenTab: (label) => setState(() => _tab = labels.indexOf(label)),
            ),
          ),
          (LucideIcons.store, 'Listing', GymListingTab(gymId: o.gymId, role: role)),
          if (role.canManageCoaches)
            (LucideIcons.users, 'Coaches', GymCoachesTab(gymId: o.gymId)),
          if (role.canSeeInquiries)
            (LucideIcons.inbox, 'Inquiries', GymInquiriesTab(gymId: o.gymId)),
          (LucideIcons.settings, 'Settings', GymSettingsTab(overview: o)),
        ];
        final index = _tab.clamp(0, tabs.length - 1);
        return Scaffold(
          backgroundColor: AppColors.hubBackgroundBottom,
          body: IndexedStack(
            index: index,
            children: [for (final t in tabs) t.$3],
          ),
          bottomNavigationBar: NavigationBarTheme(
            data: NavigationBarThemeData(
              labelTextStyle: WidgetStateProperty.resolveWith(
                (states) => AppTypography.labelSmall.copyWith(
                  color: states.contains(WidgetState.selected)
                      ? AppColors.hubTextBright
                      : AppColors.hubTextMuted,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
              iconTheme: WidgetStateProperty.resolveWith(
                (states) => IconThemeData(
                  size: AppSizing.iconMd,
                  color: states.contains(WidgetState.selected)
                      ? AppColors.hubTextBright
                      : AppColors.hubTextMuted,
                ),
              ),
            ),
            child: NavigationBar(
              backgroundColor: AppColors.hubCardBottom,
              indicatorColor: AppColors.hubHeroGlow,
              selectedIndex: index,
              onDestinationSelected: (i) {
                HapticFeedback.selectionClick();
                setState(() => _tab = i);
              },
              destinations: [
                for (final t in tabs)
                  NavigationDestination(
                    icon: Icon(t.$1),
                    label: t.$2,
                    tooltip: t.$2,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Overview: listing status, setup checklist, counts and the partnership.
class GymOverviewTab extends ConsumerWidget {
  const GymOverviewTab({required this.overview, required this.onOpenTab, super.key});

  final GymAdminOverview overview;
  /// Switches the dashboard to the tab with this label.
  final ValueChanged<String> onOpenTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final o = overview;
    final done = o.checklist.where((c) => c.$2).length;
    final total = o.checklist.length;
    final partnership = o.partnership;

    return RefreshIndicator(
      color: AppColors.hubEyebrow,
      onRefresh: () async => invalidateGymAdmin(ref, o.gymId),
      child: HubPage(
        bottomPadding: AppSpacing.xl3,
        children: [
          GymTitleBar(
            eyebrow: o.role.label,
            title: o.name,
            onBack: () => context.pop(),
            trailing: o.listingState.isLive
                ? HubSquareIconButton(
                    icon: LucideIcons.externalLink,
                    semanticLabel: 'View public page',
                    onPressed: () => context.push(AppRoutes.gymDetailPath(o.gymId)),
                  )
                : null,
          ),
          const SizedBox(height: AppSpacing.md),
          HubCard(
            hero: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GymLogo(name: o.name, url: o.logoUrl, size: 40),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text('Your listing',
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.hubTextBright,
                            fontWeight: AppTypography.bold,
                          )),
                    ),
                    GymStatusPill(o.listingState.label,
                        tone: listingTone(o.listingState)),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(listingExplainer(o.listingState),
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.hubTextBody)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Text('Setup',
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.hubTextMuted)),
                    const Spacer(),
                    Text('$done of $total',
                        style: AppTypography.labelLarge.copyWith(
                          color: AppColors.hubTextBright,
                          fontWeight: AppTypography.semiBold,
                        )),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                HubProgressBar(value: total == 0 ? 0 : done / total),
              ],
            ),
          ),
          if (done < total) ...[
            const SizedBox(height: AppSpacing.lg),
            GymSection(
              header: 'Finish your page',
              children: [
                for (final (label, ok) in o.checklist)
                  GymRow(
                    leading: Icon(
                      ok ? LucideIcons.circleCheck : LucideIcons.circle,
                      size: AppSizing.iconSm + 2,
                      color: ok ? AppColors.hubShareOnText : AppColors.hubTextFaint,
                    ),
                    title: label,
                    onTap: ok
                        ? null
                        : () => _openForChecklist(context, label),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: HubCard(
                  child: HubStatTile(
                      value: '${o.views30d}', label: 'Page views · 30 days'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HubCard(
                  onTap: o.newInquiries == null ? null : () => onOpenTab('Inquiries'),
                  child: HubStatTile(
                    value: o.newInquiries == null ? '—' : '${o.newInquiries}',
                    label: 'New inquiries',
                    valueColor: (o.newInquiries ?? 0) > 0
                        ? AppColors.hubWaitText
                        : AppColors.hubTextNumber,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: HubCard(
                  child: HubStatTile(value: '${o.coachCount}', label: 'Coaches'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HubCard(
                  child: HubStatTile(
                      value: '${o.pendingInvites}', label: 'Pending invites'),
                ),
              ),
            ],
          ),
          if (o.views14d.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            HubCard(child: _ViewsChart(days: o.views14d)),
          ],
          const SizedBox(height: AppSpacing.lg),
          GymSection(
            header: 'Manage',
            children: [
              if (o.role.canEditOffers)
                GymRow(
                  icon: LucideIcons.mapPinned,
                  title: 'Branches & offers',
                  value: '${o.branchCount} · ${o.offerCount}',
                  onTap: () => context.push(AppRoutes.gymAdminBranchesPath(o.gymId)),
                ),
              if (o.role.canSeePartnership)
                GymRow(
                  icon: LucideIcons.sparkles,
                  title: 'AI tools & usage',
                  value: partnership == null ? 'Not a partner' : partnership.status.label,
                  onTap: () => context.push(AppRoutes.gymAdminAiPath(o.gymId)),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _openForChecklist(BuildContext context, String label) {
    if (label.contains('branch') || label.contains('offer')) {
      context.push(AppRoutes.gymAdminBranchesPath(overview.gymId));
    } else if (label.contains('coach')) {
      onOpenTab(overview.role.canManageCoaches ? 'Coaches' : 'Listing');
    } else {
      onOpenTab('Listing');
    }
  }
}

GymTone listingTone(GymListingState s) => switch (s) {
      GymListingState.published => GymTone.positive,
      GymListingState.pendingReview => GymTone.caution,
      GymListingState.suspended => GymTone.negative,
      _ => GymTone.neutral,
    };

String listingExplainer(GymListingState s) => switch (s) {
      GymListingState.draft =>
        'Only your team can see this page. Finish the setup, then publish it.',
      GymListingState.pendingReview =>
        'Grit is reviewing your page. It appears in Find a gym once approved.',
      GymListingState.published =>
        'Your page is live in Find a gym. Changing the name or contact '
            'details sends it back for a quick review.',
      GymListingState.unpublished =>
        'Your page is hidden. Publish it again whenever you\'re ready.',
      GymListingState.suspended =>
        'Grit has paused this listing. Contact Grit support for details.',
    };

class _ViewsChart extends StatelessWidget {
  const _ViewsChart({required this.days});

  final List<GymDayViews> days;

  @override
  Widget build(BuildContext context) {
    final peak = days.fold<int>(0, (m, d) => d.views > m ? d.views : m);
    final total = days.fold<int>(0, (s, d) => s + d.views);
    return Semantics(
      label: '$total page views in the last ${days.length} days',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HubCardHeader(title: 'Last ${days.length} days', trailing: '$total views'),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 64,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final d in days)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: FractionallySizedBox(
                        heightFactor: peak == 0 ? 0.04 : (d.views / peak).clamp(0.04, 1.0),
                        alignment: Alignment.bottomCenter,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [AppColors.hubBarStart, AppColors.hubBarEnd],
                            ),
                            borderRadius: BorderRadius.circular(AppRadius.small),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
