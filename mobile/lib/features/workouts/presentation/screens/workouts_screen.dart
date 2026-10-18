import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../../core/widgets/profile_button.dart';
import '../../../../core/widgets/section_title.dart';
import '../../domain/entities/active_workout.dart';
import '../../domain/entities/pending_workout.dart';
import '../../domain/entities/workout_template.dart';
import '../providers/active_workout_notifier.dart';
import '../providers/workout_providers.dart';

/// TRAIN home: resume or start a workout, retry unsynced workouts, and
/// start from a template.
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).valueOrNull;
    final pending = ref.watch(pendingWorkoutsProvider).valueOrNull ?? const [];
    final templates = ref.watch(workoutTemplatesProvider);

    return AppScaffold(
      extendBodyBehindNav: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.lg),
          const SectionTitle(
            title: 'Train',
            subtitle: 'Log sets, reps and weight',
            trailing: ProfileButton(),
          ),
          if (active != null)
            _ResumeCard(
              workout: active,
              onResume: () => context.push(AppRoutes.activeWorkout),
            )
          else
            PrimaryButton(
              label: 'Start empty workout',
              onPressed: () => _start(context, ref),
            ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _PendingCard(
              pending: pending,
              onRetry: () =>
                  ref.read(pendingWorkoutsProvider.notifier).retry(),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          Row(
            children: [
              Expanded(
                child: Text('Templates', style: AppTypography.titleLarge),
              ),
              TextButton.icon(
                onPressed: () => context.push(AppRoutes.createTemplate),
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('New template'),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          templates.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child:
                    CircularProgressIndicator(color: AppColors.primaryBright),
              ),
            ),
            error: (error, _) => _Hint(
              text: 'Couldn\'t load templates. $error',
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(workoutTemplatesProvider),
            ),
            data: (list) => list.isEmpty
                ? const _Hint(
                    text: 'No templates yet. Tap "New template" to build '
                        'one, or finish a workout and save it as a template.',
                  )
                : Column(
                    children: [
                      for (final t in list)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _TemplateCard(
                            template: t,
                            enabled: active == null,
                            onStart: () => _start(context, ref, template: t),
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

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.workout, required this.onResume});

  final ActiveWorkout workout;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final minutes = DateTime.now().difference(workout.startedAt).inMinutes;
    final done = workout.exercises
        .expand((e) => e.sets)
        .where((s) => s.completed)
        .length;
    return AppCard(
      color: AppColors.primaryMuted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('WORKOUT IN PROGRESS', style: AppTypography.overline),
          const SizedBox(height: AppSpacing.xxs),
          Text(workout.title, style: AppTypography.headlineSmall),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Started $minutes min ago · ${workout.exercises.length} exercises '
            '· $done sets done',
            style: AppTypography.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          PrimaryButton(label: 'Resume workout', onPressed: onResume),
        ],
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
    return AppCard(
      color: AppColors.warningContainer,
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              '$n finished workout${n == 1 ? '' : 's'} saved on this device, '
              'waiting to sync.',
              style:
                  AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _TemplateCard extends StatelessWidget {
  const _TemplateCard({
    required this.template,
    required this.enabled,
    required this.onStart,
  });

  final WorkoutTemplate template;
  final bool enabled;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final names = template.exercises.map((e) => e.exercise.name).join(', ');
    return AppCard(
      onTap: enabled ? onStart : null,
      child: Row(
        children: [
          const Icon(LucideIcons.clipboardList, color: AppColors.primaryBright),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(template.name, style: AppTypography.titleMedium),
                const SizedBox(height: 2),
                Text(
                  names.isEmpty ? 'No exercises' : names,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption,
                ),
              ],
            ),
          ),
          Icon(
            Icons.play_arrow_rounded,
            color: enabled ? AppColors.textPrimary : AppColors.textDisabled,
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, this.actionLabel, this.onAction});

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text, style: AppTypography.bodyMedium),
          if (actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
