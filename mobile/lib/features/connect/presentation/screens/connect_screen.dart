import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../auth/presentation/providers/auth_state_notifier.dart';
import '../../domain/entities/connect_entities.dart';
import '../providers/connect_providers.dart';
import '../widgets/coach_sheets.dart';

/// COACH tab root — the athlete's Captain, their latest feedback, the
/// assigned program and what's shared. All live data from the Connect
/// repository; guests see a prompt to create an account.
class ConnectScreen extends ConsumerWidget {
  const ConnectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(authStateProvider).valueOrNull?.isGuest ?? false;
    final captain = ref.watch(myCaptainProvider);

    final List<Widget> body;
    if (isGuest) {
      body = const [
        HubMessageCard(
          icon: LucideIcons.userRound,
          title: 'Coaching needs a full account',
          message: 'Guest mode keeps your training on this device only. A '
              'Coach can coach you once you have an account.',
        ),
      ];
    } else {
      body = captain.when(
        loading: () => const [HubLoading()],
        error: (e, _) => [
          HubMessageCard(
            icon: LucideIcons.wifiOff,
            title: "Couldn't load your Coach",
            message: connectErrorMessage(e),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(myCaptainProvider),
          ),
        ],
        data: (overview) => overview == null
            ? [const _NoCaptainCard()]
            : _captainCards(context, overview),
      );
    }

    return RefreshIndicator(
      color: AppColors.hubEyebrow,
      backgroundColor: AppColors.hubCardTop,
      onRefresh: () => ref.refresh(myCaptainProvider.future),
      child: HubPage(
        glowCenter: const Alignment(-0.6, -0.8),
        children: [
          const SizedBox(height: AppSpacing.xs),
          _Header(onFind: () => context.go(AppRoutes.findCaptain)),
          const SizedBox(height: AppSpacing.sm),
          for (final w in body) ...[w, const SizedBox(height: AppSpacing.sm)],
          if (!isGuest) const _CaptainHubEntry(),
        ],
      ),
    );
  }

  List<Widget> _captainCards(BuildContext context, CaptainOverview o) => [
        _CaptainHeroCard(overview: o),
        _ProgramCard(overview: o),
        _SharingCard(overview: o),
      ];
}

class _Header extends StatelessWidget {
  const _Header({required this.onFind});

  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HubEyebrow('Coach hub'),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  'Your Coach',
                  style: AppTypography.headlineLarge
                      .copyWith(color: AppColors.hubTextBright),
                ),
              ],
            ),
          ),
          HubLink(label: 'Find coaches', onTap: onFind),
        ],
      ),
    );
  }
}

class _NoCaptainCard extends StatelessWidget {
  const _NoCaptainCard();

  @override
  Widget build(BuildContext context) {
    return HubCard(
      hero: true,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            LucideIcons.handshake,
            size: AppSizing.iconLg,
            color: AppColors.hubEyebrow,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'No Coach yet',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.hubTextBright,
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Choose a Coach to guide your training. You decide exactly '
            'what they can see.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: HubGradientButton(
              label: 'Find a Coach',
              onPressed: () => context.go(AppRoutes.findCaptain),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: HubOutlineButton(
              label: 'Have an invite code?',
              onPressed: () => showRedeemInviteSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bottom of the Coach tab: the way into the Captain Hub for users who
/// coach (or want to). A user can be an athlete and a Captain at once.
class _CaptainHubEntry extends ConsumerWidget {
  const _CaptainHubEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // While loading or on error, show the generic entry rather than
    // nothing — the hub screen itself handles the error state.
    final hub = ref.watch(captainHubProvider).valueOrNull;
    final String title;
    final String subtitle;
    if (hub == null) {
      title = 'Are you a coach?';
      subtitle = 'Become a Captain and coach athletes on Grit';
    } else if (hub.status == CoachStatus.pending) {
      title = 'Captain Hub';
      subtitle = 'Your Captain profile is under review';
    } else {
      final n = hub.clients.length;
      final r = hub.requests.length;
      title = 'Captain Hub';
      subtitle = [
        '$n athlete${n == 1 ? '' : 's'}',
        if (r > 0) '$r new request${r == 1 ? '' : 's'}',
      ].join(' · ');
    }

    return HubCard(
      onTap: () => context.go(AppRoutes.captainHub),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(
            LucideIcons.clipboardList,
            size: AppSizing.iconMd,
            color: AppColors.hubEyebrow,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.labelMedium
                      .copyWith(color: AppColors.hubTextMuted),
                ),
              ],
            ),
          ),
          const Icon(
            LucideIcons.chevronRight,
            size: AppSizing.iconSm,
            color: AppColors.hubTextFaint,
          ),
        ],
      ),
    );
  }
}

class _CaptainHeroCard extends StatelessWidget {
  const _CaptainHeroCard({required this.overview});

  final CaptainOverview overview;

  @override
  Widget build(BuildContext context) {
    final coach = overview.coach;
    final rel = overview.relationship;
    final specialties = coach?.specialties ?? const <String>[];
    final subtitle = coach?.headline?.isNotEmpty ?? false
        ? coach!.headline!
        : specialties.isNotEmpty
            ? specialties.join(' · ')
            : 'Calisthenics coach';
    final since = overview.isPending
        ? 'Request sent ${DateFormat('MMM d').format(rel.requestedAt.toLocal())}'
            ' · waiting for them to accept'
        : 'Your Coach since '
            '${DateFormat('MMMM y').format((rel.startedAt ?? rel.requestedAt).toLocal())}';

    return HubCard(
      hero: true,
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      child: Column(
        children: [
          Row(
            children: [
              HubAvatar(
                name: overview.coachName,
                imageUrl: coach?.avatarUrl,
                size: 60,
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            overview.coachName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleLarge.copyWith(
                              color: AppColors.hubTextBright,
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs + 2),
                        const Icon(
                          LucideIcons.badgeCheck,
                          size: AppSizing.iconSm,
                          color: AppColors.hubEyebrow,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs - 1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.hubTextBody),
                    ),
                    const SizedBox(height: AppSpacing.xxs - 1),
                    Text(
                      since,
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.hubTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: HubOutlineButton(
                  label: 'View profile',
                  onPressed: () => context
                      .push(AppRoutes.captainProfilePath(rel.coachId)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: HubGradientButton(
                  label: 'Send check-in',
                  onPressed: overview.isActive
                      ? () => showCheckInSheet(context, overview)
                      : null,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgramCard extends ConsumerStatefulWidget {
  const _ProgramCard({required this.overview});

  final CaptainOverview overview;

  @override
  ConsumerState<_ProgramCard> createState() => _ProgramCardState();
}

class _ProgramCardState extends ConsumerState<_ProgramCard> {
  bool _starting = false;

  Future<void> _start(ProgramAssignment a) async {
    setState(() => _starting = true);
    final result =
        await ref.read(connectRepositoryProvider).startAssignedProgram(a.id);
    if (!mounted) return;
    setState(() => _starting = false);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    result.when(
      success: (_) {
        ref.invalidate(myCaptainProvider);
        messenger.showSnackBar(
          const SnackBar(content: Text('Program started')),
        );
      },
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.overview.currentAssignment;
    if (a == null) {
      return HubCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HubEyebrow('Assigned program'),
            const SizedBox(height: AppSpacing.sm - 2),
            Text(
              'Nothing assigned yet.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.hubTextMuted),
            ),
          ],
        ),
      );
    }

    final inProgress = a.status == AssignmentStatus.inProgress;
    final start = a.startDate.toLocal();
    final weeks = DateTime.now().difference(start).inDays ~/ 7 + 1;
    return HubCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HubEyebrow('Assigned program'),
          const SizedBox(height: AppSpacing.sm - 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text(
                  inProgress ? 'Program in progress' : 'New program assigned',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
              Text(
                inProgress && weeks > 0
                    ? 'Week $weeks'
                    : 'Starts ${DateFormat('MMM d').format(start)}',
                style: AppTypography.numeric(AppTypography.labelLarge)
                    .copyWith(color: AppColors.hubTextBody),
              ),
            ],
          ),
          if (a.instructions?.isNotEmpty ?? false) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  LucideIcons.messageSquare,
                  size: AppSizing.iconSm - 2,
                  color: AppColors.hubTextBody,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    a.instructions!,
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.hubTextBody),
                  ),
                ),
              ],
            ),
          ],
          if (!inProgress) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: HubGradientButton(
                label: 'Start program',
                isLoading: _starting,
                onPressed: () => _start(a),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SharingCard extends StatelessWidget {
  const _SharingCard({required this.overview});

  final CaptainOverview overview;

  @override
  Widget build(BuildContext context) {
    final scopes = shareScopes(overview.permissions);
    return HubCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HubCardHeader(
            title: 'Shared with your Coach',
            trailing: 'Manage',
            onTrailingTap: () => showSharingSheet(context, overview),
          ),
          const SizedBox(height: AppSpacing.sm - 2),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final (label, on) in scopes)
                HubPill(
                  label: on ? label : '$label private',
                  icon: on ? LucideIcons.check : LucideIcons.lock,
                  fill: on ? AppColors.hubShareOnFill : AppColors.hubShareOffFill,
                  textColor:
                      on ? AppColors.hubShareOnText : AppColors.hubTextMuted,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
