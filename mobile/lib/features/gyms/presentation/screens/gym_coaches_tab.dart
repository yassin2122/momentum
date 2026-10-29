import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../domain/entities/gym_entities.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_ui.dart';

/// Coaches: the gym adds its own coaches — by the email on their Grit coach
/// account, or by sharing a short-lived gym code they enter themselves.
/// There's no Grit coach directory here. A coach always accepts first, and
/// their clients and data stay theirs.
class GymCoachesTab extends ConsumerStatefulWidget {
  const GymCoachesTab({required this.gymId, super.key});

  final String gymId;

  @override
  ConsumerState<GymCoachesTab> createState() => _GymCoachesTabState();
}

class _GymCoachesTabState extends ConsumerState<GymCoachesTab> {
  final _busy = <String>{};

  Future<void> _act(String key, Future<Result<void>> Function() call, String done) async {
    if (_busy.contains(key)) return;
    setState(() => _busy.add(key));
    final r = await call();
    if (!mounted) return;
    setState(() => _busy.remove(key));
    r.when(
      success: (_) {
        gymToast(context, done);
        invalidateGymAdmin(ref, widget.gymId);
      },
      failure: (f) => gymToast(context, f.message),
    );
  }

  Future<void> _invite(List<GymBranch> branches) async {
    final sent = await showGymSheet<bool>(
      context,
      _InviteSheet(gymId: widget.gymId, branches: branches),
    );
    if (sent == true && mounted) {
      gymToast(context, 'Invitation sent. It appears in their Coach Hub.');
      invalidateGymAdmin(ref, widget.gymId);
    }
  }

  Future<void> _newCode(bool replacing) async {
    if (replacing) {
      final ok = await confirmGymAction(
        context,
        title: 'Make a new code?',
        message: 'The current code stops working. Requests already sent stay open.',
        confirmLabel: 'New code',
      );
      if (!ok) return;
    }
    if (!mounted) return;
    setState(() => _busy.add('code'));
    final r = await ref.read(gymRepositoryProvider).rotateCoachCode(widget.gymId);
    if (!mounted) return;
    setState(() => _busy.remove('code'));
    r.when(
      success: (code) {
        invalidateGymAdmin(ref, widget.gymId);
        showGymSheet<void>(
          context,
          GymCodeSheet(
            title: 'Gym code for coaches',
            code: code,
            explainer: 'Share this with your coaches. They enter it in '
                'Coach Hub → Gyms, then you approve their request here. '
                'Only you see the full code, and only now.',
          ),
        );
      },
      failure: (f) => gymToast(context, f.message),
    );
  }

  Future<void> _remove(GymCoachAffiliation c) async {
    final ok = await confirmGymAction(
      context,
      title: 'Remove ${c.name}?',
      message: 'They stop appearing on your page and lose access to your '
          'gym\'s AI tools. Their clients and data stay with them.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    await _act('aff-${c.id}',
        () => ref.read(gymRepositoryProvider).endAffiliation(c.id), 'Removed');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(gymCoachesAdminProvider(widget.gymId));
    final branches =
        ref.watch(gymAdminDetailProvider(widget.gymId)).valueOrNull?.branches ?? const [];
    String branchNames(List<String> ids) {
      if (ids.isEmpty) return 'All branches';
      return branches.where((b) => ids.contains(b.id)).map((b) => b.name).join(', ');
    }

    return async.when(
      loading: () => const HubPage(children: [
        SizedBox(height: AppSpacing.xl4),
        HubLoading(),
      ]),
      error: (e, _) => HubPage(bottomPadding: AppSpacing.xl3, children: [
        const GymTitleBar(title: 'Coaches'),
        const SizedBox(height: AppSpacing.md),
        HubMessageCard(
          icon: LucideIcons.circleAlert,
          title: "Couldn't load coaches",
          message: gymErrorMessage(e),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(gymCoachesAdminProvider(widget.gymId)),
        ),
      ]),
      data: (data) {
        final pending =
            data.invitations.where((i) => i.status == GymInviteStatus.pending).toList();
        final requests = pending.where((i) => i.kind == GymInviteKind.coachRequest).toList();
        final sent = pending.where((i) => i.kind == GymInviteKind.gymInvite).toList();
        final history =
            data.invitations.where((i) => i.status != GymInviteStatus.pending).take(10).toList();
        final repo = ref.read(gymRepositoryProvider);

        return HubPage(
          bottomPadding: AppSpacing.xl3,
          children: [
            GymTitleBar(
              title: 'Coaches',
              trailing: HubSquareIconButton(
                icon: LucideIcons.userPlus,
                semanticLabel: 'Invite a coach',
                onPressed: () => _invite(branches),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            HubCard(
              hero: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Add your gym\'s coaches',
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.hubTextBright,
                        fontWeight: AppTypography.bold,
                      )),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    'Coaches use Grit free with their clients. They accept your '
                    'invitation first, and their clients and data stay theirs.',
                    style:
                        AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  HubGradientButton(
                    label: 'Invite by email',
                    icon: LucideIcons.mail,
                    height: AppSizing.buttonHeight,
                    onPressed: () => _invite(branches),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  HubOutlineButton(
                    label: data.hasActiveCode ? 'Make a new gym code' : 'Create a gym code',
                    height: AppSizing.buttonHeight,
                    onPressed:
                        _busy.contains('code') ? null : () => _newCode(data.hasActiveCode),
                  ),
                  if (data.hasActiveCode) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Center(
                      child: Text(
                        'Current code ends in ${data.codeHint} · '
                        'works until ${gymShortDate(data.codeExpiresAt!)}',
                        style: AppTypography.labelMedium
                            .copyWith(color: AppColors.hubTextMuted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (requests.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              GymSection(
                header: 'Asked to join',
                footer: 'These coaches entered your gym code.',
                children: [
                  for (final i in requests)
                    _InvitationRow(
                      invitation: i,
                      busy: _busy.contains(i.id),
                      actions: [
                        _SmallButton(
                          label: 'Decline',
                          onTap: () => _act(i.id,
                              () => repo.respondToInvitation(i.id, accept: false), 'Declined'),
                        ),
                        _SmallButton(
                          label: 'Approve',
                          primary: true,
                          onTap: () => _act(
                              i.id,
                              () => repo.respondToInvitation(i.id, accept: true),
                              '${i.name} joined your gym'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            GymSection(
              header: 'Coaches',
              trailing: Text('${data.coaches.length}',
                  style:
                      AppTypography.labelMedium.copyWith(color: AppColors.hubTextFaint)),
              children: data.coaches.isEmpty
                  ? const [
                      GymRow(
                        title: 'No coaches yet',
                        subtitle: 'Invited coaches show up here once they accept.',
                        showChevron: false,
                      ),
                    ]
                  : [
                      for (final c in data.coaches)
                        GymRow(
                          leading: HubAvatar(name: c.name, imageUrl: c.avatarUrl, size: 36),
                          title: c.name,
                          subtitle:
                              '${c.role.label} · ${branchNames(c.branchIds)} · since ${gymShortDate(c.startedAt)}',
                          trailing: _busy.contains('aff-${c.id}')
                              ? const _Spinner()
                              : IconButton(
                                  tooltip: 'Remove ${c.name}',
                                  icon: const Icon(LucideIcons.userMinus,
                                      size: AppSizing.iconSm + 2,
                                      color: AppColors.hubTextMuted),
                                  onPressed: () => _remove(c),
                                ),
                        ),
                    ],
            ),
            if (sent.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              GymSection(
                header: 'Invitations sent',
                footer: 'Invitations expire after 14 days.',
                children: [
                  for (final i in sent)
                    _InvitationRow(
                      invitation: i,
                      busy: _busy.contains(i.id),
                      actions: [
                        _SmallButton(
                          label: 'Cancel',
                          onTap: () => _act(i.id, () => repo.cancelInvitation(i.id),
                              'Invitation cancelled'),
                        ),
                      ],
                    ),
                ],
              ),
            ],
            if (history.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              GymSection(
                header: 'Recent',
                children: [
                  for (final i in history)
                    GymRow(
                      leading: HubAvatar(name: i.name, imageUrl: i.avatarUrl, size: 32),
                      title: i.name,
                      subtitle: i.kind == GymInviteKind.coachRequest
                          ? 'Asked with gym code'
                          : 'Invited by email',
                      trailing: GymStatusPill(i.status.label, tone: _inviteTone(i.status)),
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

GymTone _inviteTone(GymInviteStatus s) => switch (s) {
      GymInviteStatus.accepted => GymTone.positive,
      GymInviteStatus.pending => GymTone.caution,
      GymInviteStatus.declined => GymTone.negative,
      _ => GymTone.neutral,
    };

class _InvitationRow extends StatelessWidget {
  const _InvitationRow({
    required this.invitation,
    required this.actions,
    required this.busy,
  });

  final GymCoachInvitation invitation;
  final List<Widget> actions;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final i = invitation;
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HubAvatar(name: i.name, imageUrl: i.avatarUrl, size: 36),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.name,
                        style:
                            AppTypography.bodyLarge.copyWith(color: AppColors.hubTextBright)),
                    Text(
                      '${i.role.label} · ${gymRelativeTime(i.createdAt)} · '
                      'expires ${gymShortDate(i.expiresAt)}',
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.hubTextMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          busy
              ? const Align(alignment: Alignment.centerRight, child: _Spinner())
              : Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    for (var k = 0; k < actions.length; k++) ...[
                      if (k > 0) const SizedBox(width: AppSpacing.xs),
                      actions[k],
                    ],
                  ],
                ),
        ],
      ),
    );
  }
}

class _SmallButton extends StatelessWidget {
  const _SmallButton({required this.label, required this.onTap, this.primary = false});

  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 112,
      child: primary
          ? HubGradientButton(label: label, onPressed: onTap, height: AppSizing.minTouchTarget)
          : HubOutlineButton(label: label, onPressed: onTap, height: AppSizing.minTouchTarget),
    );
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        width: AppSizing.iconMd,
        height: AppSizing.iconMd,
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.hubEyebrow),
      );
}

/// Shows a one-time code (coach code or staff code) with a copy button.
class GymCodeSheet extends StatelessWidget {
  const GymCodeSheet({
    required this.title,
    required this.code,
    required this.explainer,
    super.key,
  });

  final String title;
  final GymCode code;
  final String explainer;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GymSheetHeader(title: title, subtitle: explainer),
        Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: AppColors.authInputFill,
            borderRadius: BorderRadius.circular(AppRadius.hubCard),
            border: Border.all(color: AppColors.hubRing),
          ),
          child: Column(
            children: [
              SelectableText(
                code.code,
                style: AppTypography.headlineLarge.copyWith(
                  color: AppColors.hubTextBright,
                  letterSpacing: 4,
                  fontWeight: AppTypography.extraBold,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text('Works until ${gymShortDate(code.expiresAt)}',
                  style:
                      AppTypography.labelMedium.copyWith(color: AppColors.hubTextMuted)),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        HubGradientButton(
          label: 'Copy code',
          icon: LucideIcons.copy,
          height: AppSizing.buttonHeight,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: code.code));
            HapticFeedback.lightImpact();
            gymToast(context, 'Code copied');
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}

class _InviteSheet extends ConsumerStatefulWidget {
  const _InviteSheet({required this.gymId, required this.branches});

  final String gymId;
  final List<GymBranch> branches;

  @override
  ConsumerState<_InviteSheet> createState() => _InviteSheetState();
}

class _InviteSheetState extends ConsumerState<_InviteSheet> {
  final _email = TextEditingController();
  final _message = TextEditingController();
  GymCoachRole _role = GymCoachRole.coach;
  final _branchIds = <String>{};
  String? _emailError;
  bool _sending = false;

  @override
  void dispose() {
    _email.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final email = _email.text.trim();
    setState(() => _emailError =
        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ? null : 'Enter their email');
    if (_emailError != null) return;
    setState(() => _sending = true);
    final r = await ref.read(gymRepositoryProvider).inviteCoach(
          gymId: widget.gymId,
          email: email,
          role: _role,
          branchIds: _branchIds.toList(),
          message: _message.text.trim().isEmpty ? null : _message.text.trim(),
        );
    if (!mounted) return;
    setState(() => _sending = false);
    r.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (f) => setState(() => _emailError = f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GymSheetHeader(
          title: 'Invite a coach',
          subtitle: 'Use the email on their Grit coach account. They\'ll see the '
              'invitation in Coach Hub and choose whether to accept.',
        ),
        GymTextField(
          label: 'Coach\'s email',
          controller: _email,
          error: _emailError,
          autofocus: true,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          maxLength: 120,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Role',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.hubTextBody,
              fontWeight: AppTypography.semiBold,
            )),
        const SizedBox(height: AppSpacing.xs),
        GymSegmented<GymCoachRole>(
          options: [for (final r in GymCoachRole.values) (r, r.label)],
          value: _role,
          onChanged: (r) => setState(() => _role = r),
        ),
        if (widget.branches.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          Text('Branches',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.hubTextBody,
                fontWeight: AppTypography.semiBold,
              )),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              GymChoiceChip(
                label: 'All branches',
                selected: _branchIds.isEmpty,
                onTap: () => setState(_branchIds.clear),
              ),
              for (final b in widget.branches)
                GymChoiceChip(
                  label: b.name,
                  selected: _branchIds.contains(b.id),
                  onTap: () => setState(() => _branchIds.contains(b.id)
                      ? _branchIds.remove(b.id)
                      : _branchIds.add(b.id)),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        GymTextField(
          label: 'Message',
          controller: _message,
          optional: true,
          maxLines: 3,
          minLines: 2,
          maxLength: 300,
        ),
        const SizedBox(height: AppSpacing.sm),
        HubGradientButton(
          label: 'Send invitation',
          height: AppSizing.buttonHeight,
          isLoading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
