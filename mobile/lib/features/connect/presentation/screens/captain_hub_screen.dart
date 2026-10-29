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
import '../../../gyms/presentation/providers/gym_providers.dart';
import '../../domain/entities/connect_entities.dart';
import '../providers/connect_providers.dart';
import '../widgets/coach_sheets.dart';

/// CAPTAIN HUB — the coach's side of CONNECT: profile status, pending
/// requests, invite codes and coached athletes. Everything comes from one
/// `get_captain_hub` call; every action is an RPC through the repository.
///
/// Nothing here is filled with sample numbers: an empty hub says so and
/// points to the two ways to get a first athlete (invite, or be listed).
class CaptainHubScreen extends ConsumerWidget {
  const CaptainHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(authStateProvider).valueOrNull?.isGuest ?? false;
    final hub = ref.watch(captainHubProvider);

    void back() =>
        context.canPop() ? context.pop() : context.go(AppRoutes.connect);

    final List<Widget> body;
    if (isGuest) {
      body = const [
        HubMessageCard(
          icon: LucideIcons.userRound,
          title: 'Coaching needs a full account',
          message: 'Create an account to set up a Coach profile.',
        ),
      ];
    } else {
      body = hub.when(
        loading: () => const [HubLoading()],
        error: (e, _) => [
          HubMessageCard(
            icon: LucideIcons.wifiOff,
            title: "Couldn't load your Coach Hub",
            message: connectErrorMessage(e),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(captainHubProvider),
          ),
        ],
        data: (h) => h == null ? const [_ApplyCard()] : _cards(h),
      );
    }

    return RefreshIndicator(
      color: AppColors.hubEyebrow,
      backgroundColor: AppColors.hubCardTop,
      onRefresh: () => ref.refresh(captainHubProvider.future),
      child: HubPage(
        glowCenter: const Alignment(0.6, -0.85),
        children: [
          Row(
            children: [
              HubBackButton(onPressed: back),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HubEyebrow('Coach'),
                    Text(
                      'Coach Hub',
                      style: AppTypography.headlineLarge
                          .copyWith(color: AppColors.hubTextBright),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final w in body) ...[w, const SizedBox(height: AppSpacing.sm)],
        ],
      ),
    );
  }

  List<Widget> _cards(CaptainHub h) => switch (h.status) {
        CoachStatus.pending => [
            const _StatusCard(
              icon: LucideIcons.shieldCheck,
              title: 'Profile under review',
              message: 'We check every Coach before they can coach. You '
                  'can keep improving your profile in the meantime.',
            ),
            _ProfileCard(hub: h),
          ],
        CoachStatus.suspended => [
            const _StatusCard(
              icon: LucideIcons.lock,
              title: 'Coach profile suspended',
              message: 'You can\'t see athlete data, send feedback or invite '
                  'clients right now. Contact Grit support for details.',
              danger: true,
            ),
          ],
        CoachStatus.approved => [
            _StatsRow(hub: h),
            if (h.requests.isNotEmpty) _RequestsCard(requests: h.requests),
            _ClientsCard(hub: h),
            _InvitesCard(hub: h),
            const _GymsEntry(),
            _ProfileCard(hub: h),
          ],
      };
}

/// Captain Hub → Gyms: the gyms this coach works at and invitations from
/// gyms. Joining a gym never moves clients or data.
class _GymsEntry extends ConsumerWidget {
  const _GymsEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gyms = ref.watch(myGymAffiliationsProvider).valueOrNull;
    final invites = gyms?.invitations.where((i) => !i.isMyRequest).length ?? 0;
    final count = gyms?.affiliations.length ?? 0;
    final subtitle = invites > 0
        ? '$invites gym invitation${invites == 1 ? '' : 's'}'
        : count == 0
            ? 'Join your gym to use its AI tools'
            : count == 1
                ? gyms!.affiliations.first.gymName
                : '$count gyms';

    return HubCard(
      onTap: () => context.push(AppRoutes.coachGyms),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const Icon(
            LucideIcons.dumbbell,
            size: AppSizing.iconMd,
            color: AppColors.hubEyebrow,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gyms',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: AppTypography.labelMedium.copyWith(
                    color: invites > 0
                        ? AppColors.hubWaitText
                        : AppColors.hubTextMuted,
                  ),
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

// ---------------------------------------------------------------------------
// No profile yet
// ---------------------------------------------------------------------------

class _ApplyCard extends StatelessWidget {
  const _ApplyCard();

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
            'Coach on Grit',
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.hubTextBright,
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Bring the athletes you already train with an invite code, or '
            'get listed so new athletes can find you. You see only what '
            'each athlete chooses to share.',
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: HubGradientButton(
              label: 'Create Coach profile',
              onPressed: () => context.go(AppRoutes.captainHubProfile),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.message,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return HubCard(
      hero: !danger,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: AppSizing.iconMd,
            color: danger ? AppColors.hubDanger : AppColors.hubEyebrow,
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
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  message,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.hubTextBody),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Approved
// ---------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.hub});

  final CaptainHub hub;

  @override
  Widget build(BuildContext context) {
    final max = hub.profile.maxAthletes;
    return Row(
      children: [
        Expanded(
          child: HubStatTile(
            value: max == null
                ? '${hub.clients.length}'
                : '${hub.clients.length}/$max',
            label: 'Athletes',
          ),
        ),
        const SizedBox(width: AppSpacing.sm - 2),
        Expanded(
          child: HubStatTile(
            value: '${hub.requests.length}',
            label: 'Requests',
          ),
        ),
        const SizedBox(width: AppSpacing.sm - 2),
        Expanded(
          child: HubStatTile(
            value: '${hub.invitesAccepted}',
            label: 'Invites used',
          ),
        ),
      ],
    );
  }
}

class _RequestsCard extends ConsumerStatefulWidget {
  const _RequestsCard({required this.requests});

  final List<HubRequest> requests;

  @override
  ConsumerState<_RequestsCard> createState() => _RequestsCardState();
}

class _RequestsCardState extends ConsumerState<_RequestsCard> {
  final _busy = <String>{};

  Future<void> _respond(HubRequest r, {required bool accept}) async {
    setState(() => _busy.add(r.relationshipId));
    final result = await ref
        .read(connectRepositoryProvider)
        .respondToRequest(r.relationshipId, accept: accept);
    if (!mounted) return;
    setState(() => _busy.remove(r.relationshipId));
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    result.when(
      success: (_) {
        ref.invalidate(captainHubProvider);
        messenger.showSnackBar(SnackBar(
          content: Text(accept
              ? 'You\'re now coaching ${r.name}'
              : 'Request from ${r.name} declined'),
        ));
      },
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return HubCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HubEyebrow('Coaching requests'),
          const SizedBox(height: AppSpacing.xs),
          for (final r in widget.requests)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                children: [
                  HubAvatar(name: r.name, imageUrl: r.avatarUrl),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          r.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.titleSmall
                              .copyWith(color: AppColors.hubTextBright),
                        ),
                        Text(
                          'Requested ${DateFormat('MMM d').format(r.requestedAt.toLocal())}',
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.hubTextMuted),
                        ),
                      ],
                    ),
                  ),
                  if (_busy.contains(r.relationshipId))
                    const SizedBox(
                      width: AppSizing.iconMd,
                      height: AppSizing.iconMd,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.hubEyebrow,
                      ),
                    )
                  else ...[
                    IconButton(
                      tooltip: 'Decline',
                      onPressed: () => _respond(r, accept: false),
                      icon: const Icon(LucideIcons.x,
                          color: AppColors.hubTextMuted),
                    ),
                    IconButton(
                      tooltip: 'Accept',
                      onPressed: () => _respond(r, accept: true),
                      icon: const Icon(LucideIcons.check,
                          color: AppColors.hubShareOnText),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ClientsCard extends StatelessWidget {
  const _ClientsCard({required this.hub});

  final CaptainHub hub;

  static String _activity(HubClient c) {
    if (!c.sharesWorkouts) return 'Workouts kept private';
    final last = c.lastWorkoutAt;
    if (last == null) return 'No workouts logged yet';
    final days = DateTime.now().difference(last.toLocal()).inDays;
    final when = days == 0
        ? 'today'
        : days == 1
            ? 'yesterday'
            : '$days days ago';
    return 'Last workout $when · ${c.workoutsLast7Days ?? 0} this week';
  }

  @override
  Widget build(BuildContext context) {
    return HubCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HubEyebrow('Your athletes'),
          const SizedBox(height: AppSpacing.xs),
          if (hub.clients.isEmpty)
            Text(
              hub.profile.isListed
                  ? 'No athletes yet. Invite someone you already train, or '
                      'wait for requests from the directory.'
                  : 'No athletes yet. Your profile is hidden from the '
                      'directory, so invite codes are the way in.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.hubTextMuted),
            )
          else
            for (final c in hub.clients)
              InkWell(
                onTap: () =>
                    context.go(AppRoutes.captainClientPath(c.relationshipId)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Row(
                    children: [
                      HubAvatar(name: c.name, imageUrl: c.avatarUrl),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.titleSmall
                                  .copyWith(color: AppColors.hubTextBright),
                            ),
                            Text(
                              _activity(c),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
                ),
              ),
        ],
      ),
    );
  }
}

class _InvitesCard extends ConsumerStatefulWidget {
  const _InvitesCard({required this.hub});

  final CaptainHub hub;

  @override
  ConsumerState<_InvitesCard> createState() => _InvitesCardState();
}

class _InvitesCardState extends ConsumerState<_InvitesCard> {
  final _revoking = <String>{};

  Future<void> _revoke(HubInvite invite) async {
    setState(() => _revoking.add(invite.id));
    final result =
        await ref.read(connectRepositoryProvider).revokeInvite(invite.id);
    if (!mounted) return;
    setState(() => _revoking.remove(invite.id));
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    result.when(
      success: (_) {
        ref.invalidate(captainHubProvider);
        messenger.showSnackBar(const SnackBar(content: Text('Invite revoked')));
      },
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invites = widget.hub.invitations;
    return HubCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HubEyebrow('Invite codes'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            invites.isEmpty
                ? 'Already training someone? Send them a code and they '
                    'join as your athlete straight away.'
                : '${invites.length} open · each code works once',
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
          ),
          for (final i in invites)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '•••••-•${i.codeHint}',
                          style: AppTypography.numeric(AppTypography.titleSmall)
                              .copyWith(color: AppColors.hubTextBright),
                        ),
                        Text(
                          [
                            if (i.note != null) i.note!,
                            'expires ${DateFormat('MMM d').format(i.expiresAt.toLocal())}',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.hubTextMuted),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _revoking.contains(i.id) ? null : () => _revoke(i),
                    style: TextButton.styleFrom(
                        foregroundColor: AppColors.hubDanger),
                    child: const Text('Revoke'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: HubGradientButton(
              label: 'Invite a client',
              onPressed: () => showCreateInviteSheet(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.hub});

  final CaptainHub hub;

  @override
  Widget build(BuildContext context) {
    final p = hub.profile;
    final listedLabel = !hub.isApproved
        ? 'Not public yet'
        : p.isListed
            ? 'Listed in directory'
            : 'Hidden from directory';
    return HubCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HubCardHeader(
            title: 'Your Coach profile',
            trailing: 'Edit',
            onTrailingTap: () => context.go(AppRoutes.captainHubProfile),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            p.headline?.isNotEmpty ?? false ? p.headline! : 'No headline yet',
            style: AppTypography.titleMedium.copyWith(
              color: p.headline?.isNotEmpty ?? false
                  ? AppColors.hubTextBright
                  : AppColors.hubTextMuted,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          HubProgressBar(value: p.completedFields / 4),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xxs,
            children: [
              HubPill(
                label: '${p.completedFields}/4 complete',
                fill: AppColors.hubTrack,
                textColor: AppColors.hubTextBody,
              ),
              HubPill(
                label: listedLabel,
                fill: AppColors.hubTrack,
                textColor: AppColors.hubTextBody,
              ),
              if (!p.acceptingAthletes)
                const HubPill(
                  label: 'Not accepting requests',
                  fill: AppColors.hubWaitFill,
                  textColor: AppColors.hubWaitText,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
