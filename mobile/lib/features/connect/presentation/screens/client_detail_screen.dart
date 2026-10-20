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
import '../../domain/entities/connect_entities.dart';
import '../providers/connect_providers.dart';
import '../widgets/coach_sheets.dart';

/// Captain → one coached athlete: their recent workouts (only if they share
/// workouts), the feedback thread, and "End coaching".
///
/// Read-only on the athlete's training: the Captain can comment on a
/// workout, never change it.
class ClientDetailScreen extends ConsumerWidget {
  const ClientDetailScreen({required this.relationshipId, super.key});

  final String relationshipId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(captainHubProvider);

    void back() =>
        context.canPop() ? context.pop() : context.go(AppRoutes.captainHub);

    final List<Widget> body = hub.when(
      loading: () => const [HubLoading()],
      error: (e, _) => [
        HubMessageCard(
          icon: LucideIcons.wifiOff,
          title: "Couldn't load this athlete",
          message: connectErrorMessage(e),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(captainHubProvider),
        ),
      ],
      data: (h) {
        final client = h?.clientByRelationship(relationshipId);
        if (client == null) {
          return const [
            HubMessageCard(
              icon: LucideIcons.userRound,
              title: 'Not coaching this athlete',
              message: 'The coaching relationship has ended, or this '
                  'athlete was never your client.',
            ),
          ];
        }
        return [
          _Header(client: client),
          _WorkoutsCard(client: client),
          _FeedbackCard(client: client),
          _EndCoachingButton(client: client),
        ];
      },
    );

    return HubPage(
      glowCenter: const Alignment(-0.5, -0.9),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: HubBackButton(onPressed: back),
        ),
        const SizedBox(height: AppSpacing.sm),
        for (final w in body) ...[w, const SizedBox(height: AppSpacing.sm)],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.client});

  final HubClient client;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        HubAvatar(
          name: client.name,
          imageUrl: client.avatarUrl,
          size: 60,
          ringColor: AppColors.hubRing,
        ),
        const SizedBox(width: AppSpacing.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                client.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.hubTextBright,
                  fontWeight: AppTypography.bold,
                ),
              ),
              if (client.username != null)
                Text(
                  '@${client.username}',
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.hubTextBody),
                ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                'Coaching since '
                '${DateFormat('MMM d, y').format(client.startedAt.toLocal())}'
                '${client.fromInvite ? ' · joined by invite' : ''}',
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.hubTextMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WorkoutsCard extends ConsumerWidget {
  const _WorkoutsCard({required this.client});

  final HubClient client;

  static String _duration(int? seconds) {
    if (seconds == null || seconds <= 0) return '';
    final m = (seconds / 60).round();
    return m >= 60 ? '${m ~/ 60}h ${m % 60}m' : '${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!client.sharesWorkouts) {
      return HubCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HubEyebrow('Recent workouts'),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${client.name} keeps workout logs private. They can turn '
              'sharing on from their Coach tab.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.hubTextMuted),
            ),
          ],
        ),
      );
    }

    final workouts = ref.watch(clientWorkoutsProvider(client.athleteId));
    final nf = NumberFormat.decimalPattern();
    return HubCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HubEyebrow('Recent workouts'),
          const SizedBox(height: AppSpacing.xs),
          ...workouts.when<List<Widget>>(
            loading: () => const [HubLoading()],
            error: (e, _) => [
              Text(
                connectErrorMessage(e),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.hubDanger),
              ),
            ],
            data: (list) => list.isEmpty
                ? [
                    Text(
                      'No completed workouts yet.',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.hubTextMuted),
                    ),
                  ]
                : [
                    for (final w in list)
                      InkWell(
                        onTap: () => showCoachFeedbackSheet(
                          context,
                          relationshipId: client.relationshipId,
                          athleteName: client.name,
                          workoutLogId: w.workoutLogId,
                          workoutLabel:
                              'the ${DateFormat('MMM d').format(w.startedAt.toLocal())} workout',
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      DateFormat('EEE, MMM d')
                                          .format(w.startedAt.toLocal()),
                                      style: AppTypography.titleSmall.copyWith(
                                          color: AppColors.hubTextBright),
                                    ),
                                    Text(
                                      [
                                        if (_duration(w.durationSeconds)
                                            .isNotEmpty)
                                          _duration(w.durationSeconds),
                                        '${w.workingSets} working sets',
                                        if (w.volumeKg > 0)
                                          '${nf.format(w.volumeKg.round())} kg',
                                      ].join(' · '),
                                      style: AppTypography.numeric(
                                              AppTypography.labelMedium)
                                          .copyWith(
                                              color: AppColors.hubTextBody),
                                    ),
                                    if (w.exerciseNames.isNotEmpty)
                                      Text(
                                        w.exerciseNames.join(', '),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: AppTypography.labelMedium
                                            .copyWith(
                                                color: AppColors.hubTextMuted),
                                      ),
                                  ],
                                ),
                              ),
                              const Icon(
                                LucideIcons.messageSquare,
                                size: AppSizing.iconSm,
                                color: AppColors.hubTextFaint,
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'Tap a workout to leave feedback on it.',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.hubTextFaint),
                    ),
                  ],
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends ConsumerWidget {
  const _FeedbackCard({required this.client});

  final HubClient client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedback = ref.watch(relationshipFeedbackProvider(client.relationshipId));
    return HubCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HubEyebrow('Feedback & check-ins'),
          const SizedBox(height: AppSpacing.xs),
          ...feedback.when<List<Widget>>(
            loading: () => const [HubLoading()],
            error: (e, _) => [
              Text(
                connectErrorMessage(e),
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.hubDanger),
              ),
            ],
            data: (list) => list.isEmpty
                ? [
                    Text(
                      'Nothing yet. Your notes and ${client.name}\'s '
                      'check-ins show up here.',
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.hubTextMuted),
                    ),
                  ]
                : [
                    for (final f in list.take(10))
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${f.authorId == client.athleteId ? client.name : 'You'}'
                              ' · ${DateFormat('MMM d').format(f.createdAt.toLocal())}'
                              '${f.workoutLogId != null ? ' · on a workout' : ''}',
                              style: AppTypography.labelMedium
                                  .copyWith(color: AppColors.hubTextMuted),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              f.body,
                              style: AppTypography.bodyMedium.copyWith(
                                color: f.authorId == client.athleteId
                                    ? AppColors.hubTextBright
                                    : AppColors.hubTextBody,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: HubGradientButton(
              label: 'Write feedback',
              onPressed: () => showCoachFeedbackSheet(
                context,
                relationshipId: client.relationshipId,
                athleteName: client.name,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EndCoachingButton extends ConsumerStatefulWidget {
  const _EndCoachingButton({required this.client});

  final HubClient client;

  @override
  ConsumerState<_EndCoachingButton> createState() => _EndCoachingButtonState();
}

class _EndCoachingButtonState extends ConsumerState<_EndCoachingButton> {
  bool _ending = false;

  Future<void> _end() async {
    final name = widget.client.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.achSheet,
        title: Text(
          'Stop coaching $name?',
          style: AppTypography.headlineSmall
              .copyWith(color: AppColors.hubTextBright),
        ),
        content: Text(
          'You\'ll lose access to their training data straight away. Their '
          'workout history stays with them, and past feedback is kept.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.hubDanger),
            child: const Text('End coaching'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _ending = true);
    final result = await ref
        .read(connectRepositoryProvider)
        .endCoaching(widget.client.relationshipId);
    if (!mounted) return;
    setState(() => _ending = false);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    result.when(
      success: (_) {
        ref.invalidate(captainHubProvider);
        messenger.showSnackBar(
          SnackBar(content: Text('You\'re no longer coaching $name')),
        );
        context.go(AppRoutes.captainHub);
      },
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: _ending ? null : _end,
        style: TextButton.styleFrom(foregroundColor: AppColors.hubDanger),
        child: Text(_ending ? 'Ending…' : 'End coaching'),
      ),
    );
  }
}
