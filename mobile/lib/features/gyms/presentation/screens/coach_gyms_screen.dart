import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../domain/entities/gym_entities.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_ui.dart';

/// Captain Hub → Gyms. A coach sees gym invitations, joins a gym with its
/// code, leaves a gym, and sees the AI allowance their gym's partnership
/// gives them. Joining never moves clients or data to the gym.
class CoachGymsScreen extends ConsumerStatefulWidget {
  const CoachGymsScreen({super.key});

  @override
  ConsumerState<CoachGymsScreen> createState() => _CoachGymsScreenState();
}

class _CoachGymsScreenState extends ConsumerState<CoachGymsScreen> {
  final _busy = <String>{};

  void _refresh() => ref
    ..invalidate(myGymAffiliationsProvider)
    ..invalidate(myAiEntitlementProvider);

  Future<void> _act(String key, Future<Result<void>> Function() call, String done,
      {VoidCallback? onDone}) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    final r = await call();
    if (!mounted) return;
    setState(() => _busy.remove(key));
    r.when(
      success: (_) {
        HapticFeedback.lightImpact();
        onDone == null ? gymToast(context, done) : onDone();
        _refresh();
      },
      failure: (f) => gymToast(context, f.message),
    );
  }

  Future<void> _accept(CoachGymInvitation i) async {
    final ok = await confirmGymAction(
      context,
      title: 'Join ${i.gymName}?',
      message: 'You\'ll be listed as a ${i.role.label.toLowerCase()} on their '
          'page and can use their AI tools if they\'re a Grit partner. Your '
          'clients, programs and data stay yours — the gym can\'t see them.',
      confirmLabel: 'Join',
    );
    if (!ok) return;
    await _act(
      i.id,
      () => ref.read(gymRepositoryProvider).respondToInvitation(i.id, accept: true),
      'You joined ${i.gymName}',
      onDone: () => showGymSuccess(
        context,
        title: 'You joined ${i.gymName}',
        message: 'You\'re now listed on their page. Your clients and their data '
            'stay with you. If the gym is a Grit partner, its AI tools appear '
            'in Coach Hub → Gyms.',
      ),
    );
  }

  Future<void> _leave(CoachGymAffiliation a) async {
    final ok = await confirmGymAction(
      context,
      title: 'Leave ${a.gymName}?',
      message: 'You\'ll be removed from their page and lose their AI tools. '
          'Your clients stay with you.',
      confirmLabel: 'Leave',
      destructive: true,
    );
    if (!ok) return;
    await _act('aff-${a.id}', () => ref.read(gymRepositoryProvider).endAffiliation(a.id),
        'You left ${a.gymName}');
  }

  Future<void> _joinWithCode() async {
    final sent = await showGymSheet<bool>(context, const _JoinCodeSheet());
    if (sent == true && mounted) {
      showGymSuccess(
        context,
        title: 'Request sent',
        message: 'The gym approves your request. You\'ll see it under '
            '"Your gyms" once they do.',
      );
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(myGymAffiliationsProvider);
    final ai = ref.watch(myAiEntitlementProvider).valueOrNull ?? AiEntitlement.none;
    final repo = ref.read(gymRepositoryProvider);

    return HubPage(
      children: [
        GymTitleBar(
          eyebrow: 'Coach Hub',
          title: 'Gyms',
          onBack: () => context.pop(),
          trailing: HubSquareIconButton(
            icon: LucideIcons.keyRound,
            semanticLabel: 'Join with a gym code',
            onPressed: _joinWithCode,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _AiCard(entitlement: ai),
        const SizedBox(height: AppSpacing.lg),
        async.when(
          loading: () => const GymRowsSkeleton(semanticLabel: 'Loading your gyms'),
          error: (e, _) => HubMessageCard(
            icon: LucideIcons.circleAlert,
            title: "Couldn't load your gyms",
            message: gymErrorMessage(e),
            actionLabel: 'Try again',
            onAction: _refresh,
          ),
          data: (data) {
            final invites = data.invitations.where((i) => !i.isMyRequest).toList();
            final requests = data.invitations.where((i) => i.isMyRequest).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (invites.isNotEmpty) ...[
                  for (final i in invites) ...[
                    _InviteCard(
                      invitation: i,
                      busy: _busy.contains(i.id),
                      onAccept: () => _accept(i),
                      onDecline: () => _act(i.id,
                          () => repo.respondToInvitation(i.id, accept: false), 'Declined'),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                ],
                GymSection(
                  header: 'Your gyms',
                  children: data.affiliations.isEmpty
                      ? [
                          GymRow(
                            icon: LucideIcons.keyRound,
                            title: 'Join with a gym code',
                            subtitle: 'Ask your gym for its coach code, or wait for '
                                'their email invitation.',
                            onTap: _joinWithCode,
                          ),
                        ]
                      : [
                          for (final a in data.affiliations)
                            GymRow(
                              leading: GymLogo(name: a.gymName, url: a.logoUrl, size: 36),
                              title: a.gymName,
                              subtitle: '${a.role.label} · since ${gymShortDate(a.startedAt)}',
                              onTap: () => context.push(AppRoutes.gymDetailPath(a.gymId)),
                              trailing: _busy.contains('aff-${a.id}')
                                  ? const SizedBox(
                                      width: AppSizing.iconMd,
                                      height: AppSizing.iconMd,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: AppColors.hubEyebrow),
                                    )
                                  : TextButton(
                                      onPressed: () => _leave(a),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.hubDanger,
                                        minimumSize: const Size(
                                            AppSizing.minTouchTarget, AppSizing.minTouchTarget),
                                      ),
                                      child: const Text('Leave'),
                                    ),
                            ),
                        ],
                ),
                if (requests.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.lg),
                  GymSection(
                    header: 'Waiting for the gym',
                    children: [
                      for (final r in requests)
                        GymRow(
                          leading: GymLogo(name: r.gymName, url: r.logoUrl, size: 36),
                          title: r.gymName,
                          subtitle: 'Sent ${gymRelativeTime(r.createdAt)}',
                          trailing: TextButton(
                            onPressed: _busy.contains(r.id)
                                ? null
                                : () => _act(r.id, () => repo.cancelInvitation(r.id),
                                    'Request withdrawn'),
                            style: TextButton.styleFrom(
                              minimumSize:
                                  const Size(AppSizing.minTouchTarget, AppSizing.minTouchTarget),
                            ),
                            child: const Text('Withdraw'),
                          ),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                const GymNote(
                  'Gyms never see your clients, their workouts or your messages. '
                  'You can leave a gym at any time.',
                  icon: LucideIcons.lock,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({required this.entitlement});

  final AiEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final e = entitlement;
    return HubCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles,
                  size: AppSizing.iconMd, color: AppColors.hubEyebrow),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text('AI coaching tools',
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.hubTextBright,
                      fontWeight: AppTypography.bold,
                    )),
              ),
              const GymStatusPill('Not connected yet'),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            e.eligible
                ? 'Included through ${e.gymName}. The tools aren\'t live in Grit '
                    'yet — your allowance is ready for when they are.'
                : 'AI tools come through a gym that partners with Grit. They '
                    'aren\'t live in Grit yet.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
          ),
          if (e.eligible) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Text('${e.remaining} left this month',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.hubTextBright,
                      fontWeight: AppTypography.semiBold,
                    )),
                const Spacer(),
                if (e.resetsOn != null)
                  Text('Resets ${gymShortDate(e.resetsOn!)}',
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.hubTextMuted)),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            HubProgressBar(
              value: e.myLimit == 0 ? 0 : (e.myUsed / e.myLimit).clamp(0, 1).toDouble(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final f in e.features)
                  HubPill(
                    label: f.label,
                    fill: AppColors.hubIconButton,
                    textColor: AppColors.hubTextMuted,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.invitation,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final CoachGymInvitation invitation;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final i = invitation;
    return HubCard(
      hero: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              GymLogo(name: i.gymName, url: i.logoUrl, size: 44),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const HubEyebrow('Gym invitation'),
                    Text(i.gymName,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.hubTextBright,
                          fontWeight: AppTypography.bold,
                        )),
                    Text(
                      [
                        i.role.label,
                        i.branchNames.isEmpty ? 'All branches' : i.branchNames.join(', '),
                      ].join(' · '),
                      style:
                          AppTypography.labelMedium.copyWith(color: AppColors.hubTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (i.message != null && i.message!.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text('"${i.message!}"',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody)),
            if (i.invitedBy != null)
              Text('— ${i.invitedBy}',
                  style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextMuted)),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text('Expires ${gymShortDate(i.expiresAt)}',
              style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextFaint)),
          const SizedBox(height: AppSpacing.md),
          if (busy)
            const Center(child: HubLoading())
          else
            Row(
              children: [
                Expanded(
                  child: HubOutlineButton(
                    label: 'Decline',
                    height: AppSizing.minTouchTarget,
                    onPressed: onDecline,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: HubGradientButton(
                    label: 'Review & join',
                    height: AppSizing.minTouchTarget,
                    onPressed: onAccept,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _JoinCodeSheet extends ConsumerStatefulWidget {
  const _JoinCodeSheet();

  @override
  ConsumerState<_JoinCodeSheet> createState() => _JoinCodeSheetState();
}

class _JoinCodeSheetState extends ConsumerState<_JoinCodeSheet> {
  final _code = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final code = _code.text.trim().toUpperCase();
    if (code.replaceAll('-', '').length < 8) {
      setState(() => _error = 'Codes look like ABCD-1234');
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    final r = await ref.read(gymRepositoryProvider).requestAffiliation(code);
    if (!mounted) return;
    setState(() => _sending = false);
    r.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (f) => setState(() => _error = f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GymSheetHeader(
          title: 'Join with a gym code',
          subtitle: 'Your gym can create one under Coaches. They approve your '
              'request before you\'re listed.',
        ),
        GymTextField(
          label: 'Gym code',
          controller: _code,
          error: _error,
          hint: 'ABCD-1234',
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 9,
        ),
        const SizedBox(height: AppSpacing.sm),
        HubGradientButton(
          label: 'Send request',
          height: AppSizing.buttonHeight,
          isLoading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
