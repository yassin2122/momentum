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
import '../../domain/entities/active_workout.dart';
import '../../domain/entities/pending_workout.dart';
import '../../domain/entities/workout_template.dart';
import '../providers/active_workout_notifier.dart';
import '../providers/workout_providers.dart';
import '../widgets/elapsed_time.dart';

/// TRAIN tab, on the same hub canvas as Dashboard and Coach.
///
/// One hero card does the screen's main job: start an empty workout, or
/// resume the one that's running (live timer). Under it: unsynced
/// workouts, the user's templates (tap a row to start it) and the
/// exercise library.
class WorkoutsScreen extends ConsumerWidget {
  const WorkoutsScreen({super.key});

  Future<void> _start(
    BuildContext context,
    WidgetRef ref, {
    WorkoutTemplate? template,
  }) async {
    final notifier = ref.read(activeWorkoutProvider.notifier);
    if (template == null) {
      await notifier.startEmpty();
    } else {
      await notifier.startFromTemplate(template);
    }
    if (context.mounted) context.push(AppRoutes.activeWorkout);
  }

  Future<void> _deleteTemplate(
    BuildContext context,
    WidgetRef ref,
    WorkoutTemplate template,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.achSheet,
        title:
            Text('Delete "${template.name}"?', style: AppTypography.titleLarge),
        content: Text(
          'The template is removed from your list. Workouts you already '
          'logged with it stay in your history.',
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
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final result =
        await ref.read(workoutRepositoryProvider).deleteTemplate(template.id);
    if (!context.mounted) return;
    ref.invalidate(workoutTemplatesProvider);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.isSuccess
          ? 'Deleted "${template.name}".'
          : result.failureOrNull!.message),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).valueOrNull;
    final pending = ref.watch(pendingWorkoutsProvider).valueOrNull ?? const [];
    final templates = ref.watch(workoutTemplatesProvider);
    void newTemplate() => context.push(AppRoutes.createTemplate);

    return HubPage(
      glowCenter: const Alignment(-0.5, -0.9),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xxs,
            AppSpacing.xs,
            AppSpacing.xxs,
            0,
          ),
          child: Text(
            'Train',
            style: AppTypography.headlineLarge
                .copyWith(color: AppColors.hubTextBright),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        active == null
            ? _StartHero(onStart: () => _start(context, ref))
            : _ResumeHero(
                workout: active,
                onResume: () => context.push(AppRoutes.activeWorkout),
              ),
        if (pending.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          _PendingCard(
            pending: pending,
            onRetry: () => ref.read(pendingWorkoutsProvider.notifier).retry(),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: Row(
            children: [
              const Expanded(child: HubEyebrow('Your templates')),
              HubLink(label: '+ New template', onTap: newTemplate),
            ],
          ),
        ),
        if (active != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xxs,
              AppSpacing.xxs,
              AppSpacing.xxs,
              0,
            ),
            child: Text(
              'Finish your current workout to start another.',
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.hubTextMuted),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        ...templates.when(
          loading: () => const [HubLoading()],
          error: (_, __) => [
            HubMessageCard(
              icon: LucideIcons.wifiOff,
              title: "Couldn't load your templates",
              message: 'Check your connection and try again.',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(workoutTemplatesProvider),
            ),
          ],
          data: (list) => list.isEmpty
              ? [
                  HubMessageCard(
                    icon: LucideIcons.clipboardList,
                    title: 'No templates yet',
                    message: 'Build one from your exercises, or save a '
                        'finished workout as a template.',
                    actionLabel: 'New template',
                    onAction: newTemplate,
                  ),
                ]
              : [
                  for (final t in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                      child: _TemplateRow(
                        template: t,
                        enabled: active == null,
                        onStart: () => _start(context, ref, template: t),
                        onDelete: () => _deleteTemplate(context, ref, t),
                      ),
                    ),
                ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: HubEyebrow('Library'),
        ),
        const SizedBox(height: AppSpacing.sm),
        _LibraryRow(onTap: () => context.push(AppRoutes.exercises)),
      ],
    );
  }
}

/// Hero when nothing is running: the one big action on the screen.
class _StartHero extends StatelessWidget {
  const _StartHero({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return HubCard(
      hero: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const HubEyebrow('Quick start'),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Empty workout',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.hubTextBright,
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Add exercises as you go. Save it as a template when you finish.',
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
          ),
          const SizedBox(height: AppSpacing.md),
          HubGradientButton(
            label: 'Start empty workout',
            icon: LucideIcons.play,
            height: AppSizing.minTouchTarget + 4,
            onPressed: onStart,
          ),
        ],
      ),
    );
  }
}

/// Hero while a workout is running: live timer and progress, Resume.
class _ResumeHero extends StatelessWidget {
  const _ResumeHero({required this.workout, required this.onResume});

  final ActiveWorkout workout;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final sets = workout.exercises.expand((e) => e.sets);
    final done = sets.where((s) => s.completed).length;
    final total = sets.length;
    final exercises = workout.exercises.length;
    return HubCard(
      hero: true,
      onTap: onResume,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const _LiveDot(),
              const SizedBox(width: AppSpacing.xs),
              const Expanded(child: HubEyebrow('In progress')),
              ElapsedTime(since: workout.startedAt),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            workout.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.hubTextBright,
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            '$exercises exercise${exercises == 1 ? '' : 's'} · '
            '$done of $total sets done',
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
          ),
          if (total > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            HubProgressBar(value: done / total),
          ],
          const SizedBox(height: AppSpacing.md),
          HubGradientButton(
            label: 'Resume workout',
            icon: LucideIcons.play,
            height: AppSizing.minTouchTarget + 4,
            onPressed: onResume,
          ),
        ],
      ),
    );
  }
}

/// Static "live" marker. Not animated: the ticking timer already shows
/// the workout is running.
class _LiveDot extends StatelessWidget {
  const _LiveDot();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 8,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.startOrbMid,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _PendingCard extends StatelessWidget {
  const _PendingCard({required this.pending, required this.onRetry});

  final List<PendingWorkout> pending;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final n = pending.length;
    return HubCard(
      child: Row(
        children: [
          const Icon(
            LucideIcons.cloudOff,
            size: AppSizing.iconSm + 2,
            color: AppColors.warning,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$n finished workout${n == 1 ? '' : 's'} saved on this device, '
              'waiting to sync.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.hubTextBody),
            ),
          ),
          HubLink(label: 'Retry', onTap: onRetry),
        ],
      ),
    );
  }
}

/// Rounded square icon tile that leads each list row.
class _RowIcon extends StatelessWidget {
  const _RowIcon(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppSizing.minTouchTarget,
      height: AppSizing.minTouchTarget,
      decoration: BoxDecoration(
        color: AppColors.hubIconButton,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.hubCardBorder),
      ),
      child:
          Icon(icon, size: AppSizing.iconSm + 2, color: AppColors.hubEyebrow),
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.enabled,
    required this.onStart,
    required this.onDelete,
  });

  final WorkoutTemplate template;
  final bool enabled;
  final VoidCallback onStart;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final count = template.exercises.length;
    final names = template.exercises.map((e) => e.exercise.name).join(', ');
    final summary = count == 0
        ? 'No exercises'
        : '$count exercise${count == 1 ? '' : 's'} · $names';
    return HubCard(
      onTap: enabled ? onStart : null,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.xxs,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          const _RowIcon(LucideIcons.clipboardList),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  template.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.hubTextMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          // Visual cue only; the whole row is the Start target.
          ExcludeSemantics(
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: enabled ? AppColors.hubHeroGlow : AppColors.hubTrack,
              ),
              child: Icon(
                LucideIcons.play,
                size: AppSizing.iconSm,
                color: enabled ? AppColors.hubChipText : AppColors.hubTextFaint,
              ),
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'More options for ${template.name}',
            color: AppColors.achSheet,
            icon: const Icon(
              LucideIcons.ellipsisVertical,
              size: AppSizing.iconSm + 2,
              color: AppColors.hubTextMuted,
            ),
            onSelected: (_) => onDelete(),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    const Icon(LucideIcons.trash2,
                        size: AppSizing.iconSm, color: AppColors.error),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Delete template',
                      style: AppTypography.bodyLarge
                          .copyWith(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Entry point to the searchable Exercise Library.
class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return HubCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          const _RowIcon(LucideIcons.dumbbell),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Exercise library',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Search by muscle, equipment and level',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySmall
                      .copyWith(color: AppColors.hubTextMuted),
                ),
              ],
            ),
          ),
          const Icon(
            LucideIcons.chevronRight,
            size: AppSizing.iconSm + 2,
            color: AppColors.hubTextMuted,
          ),
        ],
      ),
    );
  }
}
