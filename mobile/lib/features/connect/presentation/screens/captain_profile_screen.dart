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
import '../../domain/entities/connect_entities.dart';
import '../providers/connect_providers.dart';
import '../widgets/coach_sheets.dart';

/// Full-screen coach profile with "CHOOSE AS CAPTAIN" (the
/// `choose_captain` RPC through the existing repository).
class CaptainProfileScreen extends ConsumerStatefulWidget {
  const CaptainProfileScreen({required this.coachId, super.key});

  final String coachId;

  @override
  ConsumerState<CaptainProfileScreen> createState() =>
      _CaptainProfileScreenState();
}

class _CaptainProfileScreenState extends ConsumerState<CaptainProfileScreen> {
  bool _choosing = false;

  Future<void> _choose(String coachName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.achSheet,
        title: Text(
          'Choose $coachName as your Coach?',
          style: AppTypography.headlineSmall
              .copyWith(color: AppColors.hubTextBright),
        ),
        content: Text(
          'They\'ll see your workout logs, personal records and roadmap '
          'progress. Body stats stay private. You can change this any time.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.hubEyebrow),
            child: const Text('Send request'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _choosing = true);
    final result = await ref
        .read(connectRepositoryProvider)
        .chooseCaptain(coachId: widget.coachId);
    if (!mounted) return;
    setState(() => _choosing = false);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    result.when(
      success: (_) {
        ref.invalidate(myCaptainProvider);
        messenger.showSnackBar(
          SnackBar(content: Text('Request sent to $coachName')),
        );
      },
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final coachAsync = ref.watch(coachByIdProvider(widget.coachId));
    final mine = ref.watch(myCaptainProvider).valueOrNull;
    final isGuest = ref.watch(authStateProvider).valueOrNull?.isGuest ?? false;
    final isMine = mine?.relationship.coachId == widget.coachId;
    final hasOther = mine != null && !isMine;

    void back() =>
        context.canPop() ? context.pop() : context.go(AppRoutes.connect);

    final coach = coachAsync.valueOrNull;
    final name = coach?.displayName ?? coach?.username ?? 'Coach';

    final String ctaLabel;
    final VoidCallback? onCta;
    if (isGuest) {
      ctaLabel = 'Create an account to choose';
      onCta = null;
    } else if (isMine) {
      ctaLabel = mine!.isPending ? 'Request sent' : 'Your Coach';
      onCta = null;
    } else if (hasOther) {
      ctaLabel = 'You already have a Coach';
      onCta = null;
    } else if (coach != null && !coach.acceptingAthletes) {
      ctaLabel = 'Waitlist — not accepting';
      onCta = null;
    } else {
      ctaLabel = 'Choose as Coach';
      onCta = coach == null ? null : () => _choose(name);
    }

    return HubPage(
      glowCenter: const Alignment(0, -0.9),
      bottomPadding: AppSpacing.xl4 + AppSpacing.xl,
      bottomBar: HubGradientButton(
        label: ctaLabel,
        height: AppSizing.buttonHeight,
        isLoading: _choosing,
        onPressed: onCta,
      ),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: HubBackButton(onPressed: back),
        ),
        ...coachAsync.when(
          loading: () => const [HubLoading()],
          error: (e, _) => [
            const SizedBox(height: AppSpacing.md),
            HubMessageCard(
              icon: LucideIcons.wifiOff,
              title: "Couldn't load this coach",
              message: connectErrorMessage(e),
              actionLabel: 'Retry',
              onAction: () =>
                  ref.invalidate(coachByIdProvider(widget.coachId)),
            ),
          ],
          data: (c) => c == null
              ? [
                  const SizedBox(height: AppSpacing.md),
                  const HubMessageCard(
                    icon: LucideIcons.userRound,
                    title: 'Coach not available',
                    message: 'This coach isn\'t taking athletes on Grit '
                        'right now.',
                  ),
                ]
              : _content(c, name, isMine ? mine : null),
        ),
      ],
    );
  }

  List<Widget> _content(
    CoachDirectoryEntry c,
    String name,
    CaptainOverview? mine,
  ) {
    final perms = shareScopes(mine?.permissions);
    return [
      Column(
        children: [
          HubAvatar(
            name: name,
            imageUrl: c.avatarUrl,
            size: 92,
            ringColor: AppColors.hubRing,
            glow: true,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name,
                  textAlign: TextAlign.center,
                  style: AppTypography.headlineMedium.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs - 1),
              const Icon(
                LucideIcons.badgeCheck,
                size: AppSizing.iconSm + 2,
                color: AppColors.hubEyebrow,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            c.username != null ? 'Approved coach · @${c.username}' : 'Approved coach',
            style: AppTypography.labelLarge.copyWith(color: AppColors.hubTextBody),
          ),
          if (c.specialties.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm - 2),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: AppSpacing.xxs + 2,
              runSpacing: AppSpacing.xxs + 2,
              children: [
                for (final s in c.specialties) HubPill(label: s),
              ],
            ),
          ],
        ],
      ),
      const SizedBox(height: AppSpacing.md - 2),
      Row(
        children: [
          Expanded(
            child: HubStatTile(
              value: c.experienceYears == null ? '—' : '${c.experienceYears} yrs',
              label: 'Coaching',
            ),
          ),
          const SizedBox(width: AppSpacing.sm - 2),
          Expanded(
            child: HubStatTile(value: '${c.athleteCount}', label: 'Athletes'),
          ),
          const SizedBox(width: AppSpacing.sm - 2),
          const Expanded(child: HubStatTile(value: 'Free', label: 'At launch')),
        ],
      ),
      const SizedBox(height: AppSpacing.md - 2),
      HubCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HubEyebrow('About'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              c.bio?.isNotEmpty ?? false
                  ? c.bio!
                  : c.headline?.isNotEmpty ?? false
                      ? c.headline!
                      : '$name hasn\'t written a bio yet.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.hubTextBody),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md - 2),
      HubCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(child: HubEyebrow('What your Coach can see')),
                if (mine != null)
                  HubLink(
                    label: 'Manage',
                    onTap: () => showSharingSheet(context, mine),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final (label, on) in perms)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        style: AppTypography.bodyMedium
                            .copyWith(color: AppColors.hubTextBright),
                      ),
                    ),
                    Text(
                      on ? 'Shared' : 'Private',
                      style: AppTypography.bodyMedium.copyWith(
                        color: on
                            ? AppColors.hubShareOnText
                            : AppColors.hubTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(color: AppColors.divider, height: AppSpacing.lg),
            Text(
              'Your Coach can add feedback and assign programs. Your '
              'logged workouts stay yours.',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.hubTextMuted),
            ),
          ],
        ),
      ),
    ];
  }
}
