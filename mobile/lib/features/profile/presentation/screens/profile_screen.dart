import 'package:flutter/material.dart';
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
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/domain/entities/user_entity.dart';
import '../../../auth/presentation/providers/auth_state_notifier.dart';
import '../../../connect/presentation/providers/connect_providers.dart';
import '../../../connect/presentation/widgets/coach_sheets.dart';
import '../../../connect/presentation/widgets/pro_join_sheet.dart';
import '../../../progress/presentation/sample/progress_sample_data.dart';

/// PROFILE tab: who you are, totals, personal records and settings.
///
/// Live: name/email, guest state, Captain, sign-out (logic unchanged).
/// Sample (see `progress_sample_data.dart`): totals and personal records.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    UserEntity? user,
  ) async {
    // A guest session can't be signed back into — its data is gone for
    // good — so make the user confirm that one.
    if (user?.isGuest ?? false) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: AppColors.surfaceElevated,
          title: Text('Leave guest mode?', style: AppTypography.headlineSmall),
          content: Text(
            'Your guest workouts can\'t be recovered after you sign out.',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Sign out'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    // The router redirects to login once the session clears.
    await ref.read(authStateProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);
    final user = auth.valueOrNull;
    final isGuest = user?.isGuest ?? true;
    final name = isGuest
        ? 'Guest'
        : (user?.displayName?.isNotEmpty ?? false)
            ? user!.displayName!
            : 'Athlete';
    final captain = isGuest ? null : ref.watch(myCaptainProvider).valueOrNull;
    final settingsKey = GlobalKey();

    return HubPage(
      glowCenter: const Alignment(-0.6, -0.84),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Profile',
                  style: AppTypography.headlineLarge
                      .copyWith(color: AppColors.hubTextBright),
                ),
              ),
              HubSquareIconButton(
                icon: LucideIcons.settings,
                semanticLabel: 'Settings',
                onPressed: () {
                  final target = settingsKey.currentContext;
                  if (target != null) {
                    Scrollable.ensureVisible(
                      target,
                      duration: AppConstants.animMedium,
                      curve: Curves.easeOut,
                    );
                  }
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.xxs),
          child: Row(
            children: [
              HubAvatar(
                name: name,
                size: 76,
                ringColor: AppColors.hubRing,
                glow: true,
              ),
              const SizedBox(width: AppSpacing.md - 2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.hubTextBright,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs - 1),
                    Text(
                      isGuest
                          ? 'Your progress is only saved on this device'
                          : user?.email ?? '',
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.hubTextMuted),
                    ),
                    if (captain != null) ...[
                      const SizedBox(height: AppSpacing.xxs - 1),
                      GestureDetector(
                        onTap: () => context.go(AppRoutes.connect),
                        child: Text.rich(
                          TextSpan(
                            text: 'Coach: ',
                            children: [
                              TextSpan(
                                text: captain.coachName,
                                style: AppTypography.labelLarge
                                    .copyWith(color: AppColors.hubEyebrow),
                              ),
                            ],
                          ),
                          style: AppTypography.labelLarge
                              .copyWith(color: AppColors.hubTextBody),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Expanded(
              child: HubStatTile(
                value: '$sampleWorkoutCount',
                label: 'Workouts',
              ),
            ),
            const SizedBox(width: AppSpacing.sm - 2),
            Expanded(
              child: HubStatTile(
                value: '${sampleHud.bestStreakDays}',
                label: 'Best streak',
                valueColor: AppColors.hubStreak,
              ),
            ),
          ],
        ),
        if (isGuest) ...[
          const SizedBox(height: AppSpacing.sm),
          HubCard(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      LucideIcons.cloud,
                      size: AppSizing.iconSm,
                      color: AppColors.hubEyebrow,
                    ),
                    SizedBox(width: AppSpacing.xs),
                    HubEyebrow('Sync your progress'),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm - 2),
                Text(
                  'Create an account to back up your workouts and access '
                  'them on any device.',
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.hubTextBody),
                ),
                const SizedBox(height: AppSpacing.md),
                // Not wired yet: converting a guest session into a full
                // account (keeping its data) needs its own flow.
                const PrimaryButton(
                  label: 'Create Account',
                  onPressed: null,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        HubCard(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md - 2,
            AppSpacing.sm,
            AppSpacing.md - 2,
            AppSpacing.xxs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HubEyebrow('Personal records'),
              for (var i = 0; i < samplePersonalRecords.length; i++)
                Container(
                  height: AppSpacing.xl + AppSpacing.xxs,
                  decoration: BoxDecoration(
                    border: i == samplePersonalRecords.length - 1
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppColors.divider),
                          ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          samplePersonalRecords[i].$1,
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.hubTextBody),
                        ),
                      ),
                      Text(
                        samplePersonalRecords[i].$2,
                        style: AppTypography.numeric(AppTypography.bodyMedium)
                            .copyWith(
                          color: AppColors.hubTextBright,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        HubCard(
          key: settingsKey,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - 2),
          child: Column(
            children: [
              _SettingsRow(
                icon: LucideIcons.shieldCheck,
                label: 'Privacy & sharing',
                onTap: captain != null && !captain.isPending
                    ? () => showSharingSheet(context, captain)
                    : () => context.go(AppRoutes.connect),
              ),
              if (!isGuest)
                _SettingsRow(
                  icon: LucideIcons.keyRound,
                  label: 'Two-factor authentication',
                  onTap: () => context.push(AppRoutes.twoFactor),
                ),
              if (!isGuest)
                _SettingsRow(
                  icon: LucideIcons.briefcase,
                  label: 'Join Grit as a pro',
                  onTap: () => showProJoinSheet(context),
                ),
              _SettingsRow(
                icon: LucideIcons.bell,
                label: 'Notifications',
                onTap: () => ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Notification settings are coming soon'),
                    ),
                  ),
              ),
              _SettingsRow(
                icon: LucideIcons.logOut,
                label: auth.isLoading ? 'Signing out…' : 'Log out',
                danger: true,
                last: true,
                onTap: auth.isLoading ? null : () => _signOut(context, ref, user),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool danger;
  final bool last;

  static const double _height = 46;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.hubDanger : AppColors.hubTextBright;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: _height,
        decoration: BoxDecoration(
          border: last
              ? null
              : const Border(bottom: BorderSide(color: AppColors.divider)),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppSizing.iconSm + 2, color: color),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                label,
                style: AppTypography.titleSmall.copyWith(
                  color: color,
                  fontWeight: AppTypography.regular,
                ),
              ),
            ),
            if (!danger)
              const Icon(
                LucideIcons.chevronRight,
                size: AppSizing.iconSm,
                color: AppColors.hubTextMuted,
              ),
          ],
        ),
      ),
    );
  }
}
