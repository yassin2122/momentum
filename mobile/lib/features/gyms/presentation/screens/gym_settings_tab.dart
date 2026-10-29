import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../auth/presentation/providers/auth_state_notifier.dart';
import '../../domain/entities/gym_entities.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_ui.dart';
import 'gym_coaches_tab.dart' show GymCodeSheet;

/// Settings: Grit partnership and the gym's team (who can do what).
class GymSettingsTab extends ConsumerStatefulWidget {
  const GymSettingsTab({required this.overview, super.key});

  final GymAdminOverview overview;

  @override
  ConsumerState<GymSettingsTab> createState() => _GymSettingsTabState();
}

class _GymSettingsTabState extends ConsumerState<GymSettingsTab> {
  bool _busy = false;

  GymAdminOverview get o => widget.overview;

  Future<void> _requestPartnership() async {
    final ok = await confirmGymAction(
      context,
      title: 'Request a Grit partnership?',
      message: 'Grit will contact you to agree the AI tools and monthly '
          'allowance for your coaches. Nothing is charged in the app.',
      confirmLabel: 'Send request',
    );
    if (!ok) return;
    setState(() => _busy = true);
    final r = await ref.read(gymRepositoryProvider).requestPartnership(o.gymId);
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (_) {
        gymToast(context, 'Request sent. Grit will be in touch.');
        invalidateGymAdmin(ref, o.gymId);
      },
      failure: (f) => gymToast(context, f.message),
    );
  }

  Future<void> _addTeammate() async {
    final role = await showGymSheet<GymStaffRole>(
      context,
      const _RolePickerSheet(
        title: 'Add a teammate',
        subtitle: 'Pick their role. You\'ll get a code to give them; they enter '
            'it in Profile → Your gyms.',
      ),
    );
    if (role == null || !mounted) return;
    setState(() => _busy = true);
    final r = await ref.read(gymRepositoryProvider).createStaffInvite(o.gymId, role);
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (code) => showGymSheet<void>(
        context,
        GymCodeSheet(
          title: 'Team code · ${role.label}',
          code: code,
          explainer: 'Works once. Give it to your teammate — they enter it in '
              'Profile → Your gyms → Join a gym team.',
        ),
      ),
      failure: (f) => gymToast(context, f.message),
    );
  }

  Future<void> _editMember(GymStaffMember m) async {
    final role = await showGymSheet<Object>(
      context,
      _RolePickerSheet(
        title: m.name,
        subtitle: 'Change their role or remove them from the team.',
        current: m.role,
        allowRemove: true,
      ),
    );
    if (role == null || !mounted) return;
    final repo = ref.read(gymRepositoryProvider);
    if (role == _RolePickerSheet.remove) {
      final ok = await confirmGymAction(
        context,
        title: 'Remove ${m.name}?',
        message: 'They lose access to this gym\'s dashboard.',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!ok || !mounted) return;
      setState(() => _busy = true);
      final r = await repo.removeStaff(o.gymId, m.userId);
      if (!mounted) return;
      setState(() => _busy = false);
      r.when(
        success: (_) => invalidateGymAdmin(ref, o.gymId),
        failure: (f) => gymToast(context, f.message),
      );
      return;
    }
    if (role is! GymStaffRole || role == m.role) return;
    setState(() => _busy = true);
    final r = await repo.setStaffRole(o.gymId, m.userId, role);
    if (!mounted) return;
    setState(() => _busy = false);
    r.when(
      success: (_) => invalidateGymAdmin(ref, o.gymId),
      failure: (f) => gymToast(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final staff = ref.watch(gymStaffProvider(o.gymId));
    final me = ref.watch(authStateProvider).valueOrNull?.id;
    final p = o.partnership;
    final canTeam = o.role.canManageTeam;

    return HubPage(
      bottomPadding: AppSpacing.xl3,
      children: [
        GymTitleBar(
          title: 'Settings',
          trailing: _busy
              ? const SizedBox(
                  width: AppSizing.iconMd,
                  height: AppSizing.iconMd,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.hubEyebrow),
                )
              : null,
        ),
        const SizedBox(height: AppSpacing.md),
        if (o.role.canSeePartnership) ...[
          GymSection(
            header: 'Grit partnership',
            footer: p == null
                ? 'Partner gyms give their coaches AI tools through Grit. Grit '
                    'reviews each request and sets the allowance with you.'
                : 'Allowance and AI tools are set by Grit as part of your '
                    'partnership agreement.',
            children: [
              if (p == null)
                GymRow(
                  icon: LucideIcons.handshake,
                  title: 'Become a Grit partner',
                  onTap: _busy ? null : _requestPartnership,
                )
              else ...[
                GymRow(
                  icon: LucideIcons.handshake,
                  title: 'Status',
                  showChevron: false,
                  trailing: GymStatusPill(
                    p.status.label,
                    tone: switch (p.status) {
                      GymPartnershipStatus.active => GymTone.positive,
                      GymPartnershipStatus.pendingReview => GymTone.caution,
                      GymPartnershipStatus.suspended => GymTone.negative,
                      _ => GymTone.neutral,
                    },
                  ),
                ),
                if (p.endsOn != null)
                  GymRow(
                    title: 'Renews or ends',
                    value: gymShortDate(p.endsOn!),
                    showChevron: false,
                  ),
                if (!p.isActive &&
                    p.status != GymPartnershipStatus.pendingReview)
                  GymRow(
                    title: 'Request again',
                    onTap: _busy ? null : _requestPartnership,
                  ),
              ],
              GymRow(
                icon: LucideIcons.sparkles,
                title: 'AI tools & usage',
                onTap: () => context.push(AppRoutes.gymAdminAiPath(o.gymId)),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        staff.when(
          loading: () => const HubLoading(),
          error: (e, _) => HubMessageCard(
            icon: LucideIcons.circleAlert,
            title: "Couldn't load your team",
            message: gymErrorMessage(e),
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(gymStaffProvider(o.gymId)),
          ),
          data: (members) => GymSection(
            header: 'Team',
            trailing: canTeam
                ? HubLink(label: 'Add', onTap: _busy ? null : _addTeammate)
                : null,
            footer: canTeam
                ? 'Owners manage the team. Managers handle the page, branches, '
                    'coaches and inquiries; marketing edits the page and offers; '
                    'front desk answers inquiries.'
                : 'Only the owner can change the team.',
            children: [
              for (final m in members)
                GymRow(
                  leading: HubAvatar(name: m.name, imageUrl: m.avatarUrl, size: 36),
                  title: m.userId == me ? '${m.name} (you)' : m.name,
                  subtitle: m.role.description,
                  value: m.role.label,
                  onTap: canTeam && m.role != GymStaffRole.owner && m.userId != me
                      ? () => _editMember(m)
                      : null,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RolePickerSheet extends StatefulWidget {
  const _RolePickerSheet({
    required this.title,
    required this.subtitle,
    this.current,
    this.allowRemove = false,
  });

  /// Popped when the user picks "Remove from team".
  static const remove = 'remove';

  final String title;
  final String subtitle;
  final GymStaffRole? current;
  final bool allowRemove;

  @override
  State<_RolePickerSheet> createState() => _RolePickerSheetState();
}

class _RolePickerSheetState extends State<_RolePickerSheet> {
  late GymStaffRole _role = widget.current ?? GymStaffRole.frontDesk;

  @override
  Widget build(BuildContext context) {
    // A gym has a single owner; ownership isn't transferable from the app.
    final roles = GymStaffRole.values.where((r) => r != GymStaffRole.owner);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GymSheetHeader(title: widget.title, subtitle: widget.subtitle),
        GymSection(
          children: [
            for (final r in roles)
              GymRow(
                title: r.label,
                subtitle: r.description,
                showChevron: false,
                trailing: Icon(
                  _role == r ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: AppSizing.iconSm + 2,
                  color: _role == r ? AppColors.hubEyebrow : AppColors.hubTextFaint,
                ),
                onTap: () => setState(() => _role = r),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        HubGradientButton(
          label: widget.current == null ? 'Create team code' : 'Save role',
          height: AppSizing.buttonHeight,
          onPressed: () => Navigator.of(context).pop(_role),
        ),
        if (widget.allowRemove) ...[
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            onPressed: () => Navigator.of(context).pop(_RolePickerSheet.remove),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.hubDanger,
              minimumSize: const Size.fromHeight(AppSizing.minTouchTarget),
            ),
            child: Text('Remove from team',
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.hubDanger,
                  fontWeight: AppTypography.semiBold,
                )),
          ),
        ],
      ],
    );
  }
}
