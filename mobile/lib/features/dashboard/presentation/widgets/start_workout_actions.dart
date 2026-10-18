import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../workouts/domain/entities/active_workout.dart';
import '../../../workouts/domain/entities/workout_template.dart';
import '../../../workouts/presentation/providers/active_workout_notifier.dart';
import '../../../workouts/presentation/providers/workout_providers.dart';

/// Ways to start a workout from the centre START button. They only call
/// the existing workout notifier.

/// Today's recommended template: the templates take turns, one per day,
/// in the order they're listed (Day 1, Day 2, …), so the plan cycles
/// through all of them. Null when there are none.
WorkoutTemplate? recommendedTemplate(
  List<WorkoutTemplate>? templates, {
  DateTime? now,
}) {
  final list = templates ?? const <WorkoutTemplate>[];
  if (list.isEmpty) return null;
  final day = now ?? DateTime.now();
  final daysSinceEpoch =
      DateTime.utc(day.year, day.month, day.day).millisecondsSinceEpoch ~/
          Duration.millisecondsPerDay;
  return list[daysSinceEpoch % list.length];
}

/// Starts [template] (resumes instead if a workout is already running).
Future<void> startTemplateWorkout(
  BuildContext context,
  WidgetRef ref,
  WorkoutTemplate template,
) async {
  if (ref.read(activeWorkoutProvider).valueOrNull == null) {
    await ref.read(activeWorkoutProvider.notifier).startFromTemplate(template);
  }
  if (context.mounted) context.push(AppRoutes.activeWorkout);
}

/// An empty session (resumes instead if one is already running).
Future<void> startFreeWorkout(BuildContext context, WidgetRef ref) async {
  if (ref.read(activeWorkoutProvider).valueOrNull == null) {
    await ref.read(activeWorkoutProvider.notifier).startEmpty();
  }
  if (context.mounted) context.push(AppRoutes.activeWorkout);
}

/// Bottom sheet for the centre START button: today's recommended workout
/// on top with a big Start, then "or pick another" — the rest of the
/// user's templates — and free workout / new template at the bottom. An
/// in-progress workout replaces the recommendation with Resume.
///
/// Presented as frosted glass: the page behind is blurred and dimmed, and
/// the sheet itself is a translucent blurred panel (same glass recipe as
/// the floating nav bar). Tap outside or swipe down to close.
Future<void> showStartSheet(
  BuildContext context, {
  required VoidCallback onResume,
  required ValueChanged<WorkoutTemplate> onStartTemplate,
  required VoidCallback onFree,
  required VoidCallback onCreateTemplate,
}) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    // The blur layer below draws its own scrim.
    barrierColor: AppColors.transparent,
    transitionDuration: _sheetDuration,
    pageBuilder: (sheet, _, __) {
      // Close first, then act from the caller's (still mounted) context.
      void pick(VoidCallback action) {
        Navigator.of(sheet).pop();
        action();
      }

      return _GlassSheetFrame(
        child: _StartSheet(
          onResume: () => pick(onResume),
          onStartTemplate: (t) => pick(() => onStartTemplate(t)),
          onFree: () => pick(onFree),
          onCreateTemplate: () => pick(onCreateTemplate),
        ),
      );
    },
    transitionBuilder: (routeContext, animation, _, sheet) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return AnimatedBuilder(
        animation: curved,
        child: sheet,
        builder: (context, sheet) {
          final t = curved.value;
          return Stack(
            children: [
              // Blurred, dimmed page behind the sheet; tap to close.
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(routeContext).maybePop(),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: _backdropBlur * t,
                      sigmaY: _backdropBlur * t,
                    ),
                    child: Opacity(
                      opacity: t,
                      child: const ColoredBox(color: AppColors.overlayLight),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionalTranslation(
                  translation: Offset(0, 1 - t),
                  child: sheet,
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Blur of the page behind the START sheet.
const double _backdropBlur = 14;

/// Frosted blur inside the sheet panel itself.
const double _glassBlur = 24;

/// Swipe-down speed (logical px/s) that dismisses the sheet.
const double _dismissVelocity = 300;

const Duration _sheetDuration = Duration(milliseconds: 320);

/// Translucent frosted panel the START sheet sits in.
class _GlassSheetFrame extends StatelessWidget {
  const _GlassSheetFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    const radius =
        BorderRadius.vertical(top: Radius.circular(AppRadius.sheet));
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > _dismissVelocity) {
          Navigator.of(context).maybePop();
        }
      },
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: _glassBlur, sigmaY: _glassBlur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: AppColors.navGlassRim),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.navGlassTop, AppColors.navGlassBottom],
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom,
                ),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StartSheet extends ConsumerWidget {
  const _StartSheet({
    required this.onResume,
    required this.onStartTemplate,
    required this.onFree,
    required this.onCreateTemplate,
  });

  final VoidCallback onResume;
  final ValueChanged<WorkoutTemplate> onStartTemplate;
  final VoidCallback onFree;
  final VoidCallback onCreateTemplate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeWorkoutProvider).valueOrNull;
    final templates = ref.watch(workoutTemplatesProvider);
    final list = templates.valueOrNull ?? const <WorkoutTemplate>[];
    final recommended = recommendedTemplate(list);
    final others = [
      for (final t in list)
        if (t.id != recommended?.id) t,
    ];

    final Widget hero;
    if (active != null) {
      hero = _ResumeHero(workout: active, onResume: onResume);
    } else if (templates.isLoading && list.isEmpty) {
      hero = const _LoadingHero();
    } else if (recommended != null) {
      hero = _RecommendedHero(
        template: recommended,
        dayNumber: list.indexOf(recommended) + 1,
        onStart: () => onStartTemplate(recommended),
      );
    } else {
      hero = _EmptyHero(onCreate: onCreateTemplate, onFree: onFree);
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: AppSpacing.xl + AppSpacing.xxs,
                height: AppSpacing.xxs,
                decoration: BoxDecoration(
                  color: AppColors.achHandle,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            hero,
            if (active == null && others.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Or pick another template',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.hubTextBright,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: others.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.xs),
                  itemBuilder: (context, i) => _TemplateRow(
                    template: others[i],
                    dayNumber: list.indexOf(others[i]) + 1,
                    onTap: () => onStartTemplate(others[i]),
                  ),
                ),
              ),
            ],
            if (active == null && recommended != null) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _SmallAction(
                      icon: LucideIcons.dumbbell,
                      label: 'Free workout',
                      onTap: onFree,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _SmallAction(
                      icon: LucideIcons.plus,
                      label: 'New template',
                      onTap: onCreateTemplate,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

int _setCount(WorkoutTemplate t) =>
    t.exercises.fold<int>(0, (sum, e) => sum + math.max(1, e.defaultSets ?? 1));

/// Big card for today's pick.
class _HeroFrame extends StatelessWidget {
  const _HeroFrame({
    required this.eyebrow,
    required this.title,
    required this.meta,
    required this.button,
    required this.onPressed,
    this.detail,
  });

  final String eyebrow;
  final String title;
  final String meta;
  final String? detail;
  final String button;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.hubHero),
        border: Border.all(color: AppColors.hubCardBorderStrong),
        gradient: const RadialGradient(
          center: Alignment(-0.8, -1),
          radius: 1.4,
          colors: [AppColors.hubHeroGlow, AppColors.hubCardBottom],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.accentProgress,
              fontWeight: AppTypography.semiBold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.hubTextBright,
              fontWeight: AppTypography.extraBold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            meta,
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
          ),
          if (detail != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              detail!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.hubTextMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _GradientButton(label: button, onPressed: onPressed),
        ],
      ),
    );
  }
}

class _RecommendedHero extends StatelessWidget {
  const _RecommendedHero({
    required this.template,
    required this.dayNumber,
    required this.onStart,
  });

  final WorkoutTemplate template;
  final int dayNumber;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final names = template.exercises.map((e) => e.exercise.name).join(' · ');
    return _HeroFrame(
      eyebrow: "TODAY'S WORKOUT · DAY $dayNumber",
      title: template.name,
      meta: '${template.exercises.length} exercises · '
          '${_setCount(template)} sets',
      detail: names.isEmpty ? null : names,
      button: 'Start',
      onPressed: onStart,
    );
  }
}

class _ResumeHero extends StatelessWidget {
  const _ResumeHero({required this.workout, required this.onResume});

  final ActiveWorkout workout;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final minutes = DateTime.now().difference(workout.startedAt).inMinutes;
    final done = workout.exercises
        .expand((e) => e.sets)
        .where((s) => s.completed)
        .length;
    return _HeroFrame(
      eyebrow: 'IN PROGRESS',
      title: workout.title,
      meta: 'Started $minutes min ago · $done sets done',
      button: 'Resume',
      onPressed: onResume,
    );
  }
}

class _LoadingHero extends StatelessWidget {
  const _LoadingHero();

  @override
  Widget build(BuildContext context) {
    return const _HeroFrame(
      eyebrow: "TODAY'S WORKOUT",
      title: 'Loading…',
      meta: 'Fetching your templates',
      button: 'Start',
      onPressed: null,
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.onCreate, required this.onFree});

  final VoidCallback onCreate;
  final VoidCallback onFree;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroFrame(
          eyebrow: 'NO TEMPLATES YET',
          title: 'Make your first template',
          meta: 'Pick your exercises once — then START suggests one '
              'every day.',
          button: 'Create template',
          onPressed: onCreate,
        ),
        const SizedBox(height: AppSpacing.sm),
        _SmallAction(
          icon: LucideIcons.dumbbell,
          label: 'Free workout',
          onTap: onFree,
        ),
      ],
    );
  }
}

class _TemplateRow extends StatelessWidget {
  const _TemplateRow({
    required this.template,
    required this.dayNumber,
    required this.onTap,
  });

  final WorkoutTemplate template;
  final int dayNumber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.hubCard);
    return Material(
      color: AppColors.glassLight,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.hubCardBorder),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: AppSizing.minTouchTarget - AppSpacing.xs,
                height: AppSizing.minTouchTarget - AppSpacing.xs,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.hubIconButton,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(color: AppColors.hubCardBorder),
                ),
                child: Text(
                  'D$dayNumber',
                  style: AppTypography.numeric(AppTypography.labelMedium)
                      .copyWith(
                    color: AppColors.accentProgress,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      template.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.titleSmall.copyWith(
                        color: AppColors.hubTextBright,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                    Text(
                      '${template.exercises.length} exercises · '
                      '${_setCount(template)} sets',
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.hubTextMuted),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.play,
                size: AppSizing.iconSm + 2,
                color: AppColors.hubTextBright,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Material(
      color: AppColors.glassMedium,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.hubCardBorderStrong),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: SizedBox(
          height: AppSizing.minTouchTarget,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: AppSizing.iconSm, color: AppColors.accentProgress),
              const SizedBox(width: AppSpacing.xs),
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: AppColors.hubTextBright,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Orange → coral → teal pill, the app's main button.
class _GradientButton extends StatelessWidget {
  const _GradientButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        height: AppSizing.buttonHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            colors: [
              AppColors.ctaGradientStart,
              AppColors.ctaGradientMid,
              AppColors.ctaGradientEnd,
            ],
          ),
          boxShadow: AppShadows.ctaGlow,
        ),
        child: Material(
          color: AppColors.transparent,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: AppTypography.button.copyWith(letterSpacing: 0.8),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
