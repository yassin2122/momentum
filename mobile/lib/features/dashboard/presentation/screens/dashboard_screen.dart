import 'dart:math' as math;

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
import '../../../../core/widgets/hub_ui.dart';
import '../../../auth/presentation/providers/auth_state_notifier.dart';
import '../../../muscle_map/domain/entities/muscle.dart';
import '../../../muscle_map/domain/services/muscle_mapping.dart';
import '../../../muscle_map/presentation/providers/muscle_map_providers.dart';
import '../../../muscle_map/presentation/widgets/muscle_map_view.dart';
import '../../../workouts/domain/entities/active_workout.dart';
import '../../../workouts/domain/entities/workout_template.dart';
import '../../../workouts/presentation/providers/active_workout_notifier.dart';
import '../../../workouts/presentation/providers/workout_providers.dart';
import '../../../workouts/presentation/widgets/resume_workout_bar.dart';
import '../../domain/entities/discipline_score.dart';
import '../../domain/entities/streak_status.dart';
import '../providers/dashboard_providers.dart';

/// DASHBOARD tab: avatar, mascot, greeting and the Streak / Grit
/// cards on top, then "Your Plan" — the user's own workout templates as
/// big swipeable cards, each lighting the muscles its exercises work.
/// "View" previews a template and starts it through the existing workout
/// notifier; "Manage" (and the last card) opens the Train tab.
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final _pages = PageController(viewportFraction: 0.84);
  int _page = 0;

  /// Coming back to the app on a new day counts as an open.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => ref.invalidate(streakProvider),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _pages.dispose();
    super.dispose();
  }

  void _showDiscipline(DisciplineScore score) {
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      useSafeArea: true,
      backgroundColor: AppColors.achSheet,
      barrierColor: AppColors.achScrim,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => _DisciplineSheet(score: score),
    );
  }

  void _manageTemplates() => context.go(AppRoutes.train);

  void _createTemplate() => context.push(AppRoutes.createTemplate);

  /// Fixed height for the swipeable plan cards; the page scrolls.
  static const double _carouselHeight = 420;

  Future<void> _start(WorkoutTemplate template) async {
    await ref.read(activeWorkoutProvider.notifier).startFromTemplate(template);
    if (mounted) context.push(AppRoutes.activeWorkout);
  }

  void _preview(WorkoutTemplate template, {required bool canStart}) {
    showModalBottomSheet<void>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.achSheet,
      barrierColor: AppColors.achScrim,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (sheet) => _TemplatePreviewSheet(
        template: template,
        canStart: canStart,
        onStart: () {
          Navigator.of(sheet).pop();
          _start(template);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).valueOrNull;
    final name = (user?.isGuest ?? true)
        ? 'Guest'
        : (user?.displayName?.isNotEmpty ?? false)
            ? user!.displayName!.split(' ').first
            : 'Athlete';
    final active = ref.watch(activeWorkoutProvider).valueOrNull;
    final templates = ref.watch(workoutTemplatesProvider);
    final streak = ref.watch(streakProvider).valueOrNull;
    final discipline = ref.watch(disciplineProvider).valueOrNull;

    // One fetch of muscle links for every exercise on the row of cards.
    final cardExerciseIds = <String>[
      ...?active?.exercises.map((e) => e.exercise.id),
      for (final t in templates.valueOrNull ?? const <WorkoutTemplate>[])
        ...t.exercises.map((e) => e.exercise.id),
    ];
    final links = ref
            .watch(exerciseMuscleLinksProvider(exerciseIdsKey(cardExerciseIds)))
            .valueOrNull ??
        const <String, List<MuscleLink>>{};
    Map<Muscle, double> musclesOf(Iterable<String> ids) =>
        involvementIntensities(MuscleMapping.templateInvolvement(ids, links));

    // One card per template, then an "add / change" card. An in-progress
    // workout leads the row so it is never lost.
    final cards = <Widget>[];
    if (active != null) {
      cards.add(_ResumeCard(
        workout: active,
        muscles: musclesOf(active.exercises.map((e) => e.exercise.id)),
        onResume: () => context.push(AppRoutes.activeWorkout),
      ));
    }
    templates.when(
      loading: () => cards.add(const _LoadingCard()),
      error: (e, _) => cards.add(_MessageCard(
        icon: LucideIcons.wifiOff,
        title: "Couldn't load your templates",
        body: 'Check your connection and try again.',
        action: 'Retry',
        onAction: () => ref.invalidate(workoutTemplatesProvider),
      )),
      data: (list) {
        for (var i = 0; i < list.length; i++) {
          cards.add(_PlanCard(
            template: list[i],
            index: i,
            count: list.length,
            muscles: musclesOf(list[i].exercises.map((e) => e.exercise.id)),
            onView: () => _preview(list[i], canStart: active == null),
          ));
        }
        cards.add(list.isEmpty
            ? _MessageCard(
                icon: LucideIcons.dumbbell,
                title: 'No templates yet',
                body: 'Pick your exercises once and they show up here, '
                    'ready to swipe to.',
                action: 'Create template',
                onAction: _createTemplate,
              )
            : _MessageCard(
                icon: LucideIcons.plus,
                title: 'Create a template',
                body: 'Build a new workout from your exercises, or manage '
                    'the ones you have in Train.',
                action: 'Create template',
                onAction: _createTemplate,
              ));
      },
    );
    final page = math.min(_page, cards.length - 1);

    return Scaffold(
      backgroundColor: AppColors.hubBackgroundBottom,
      body: HubBackground(
        glowCenter: const Alignment(0.4, -0.84),
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: kNavClearance +
                      (active == null
                          ? 0
                          : ResumeWorkoutBar.height + AppSpacing.sm),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                      0,
                    ),
                    child: _TopSection(
                      name: name,
                      streak: streak,
                      discipline: discipline,
                      onDiscipline: discipline == null
                          ? null
                          : () => _showDiscipline(discipline),
                      onStats: () => context.push(AppRoutes.analytics),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            'Your Plan',
                            style: AppTypography.headlineLarge
                                .copyWith(color: AppColors.hubTextBright),
                          ),
                        ),
                        _HeaderAction(
                          icon: LucideIcons.plus,
                          label: 'New',
                          semanticLabel: 'Create a template',
                          color: AppColors.accentProgress,
                          onTap: _createTemplate,
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        _HeaderAction(
                          icon: LucideIcons.arrowRight,
                          label: 'Manage',
                          semanticLabel: 'Manage templates',
                          color: AppColors.hubTextMuted,
                          iconAfter: true,
                          onTap: _manageTemplates,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    height: _carouselHeight,
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: cards.length,
                      padEnds: false,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) => Padding(
                        padding: EdgeInsets.only(
                          left: i == 0 ? AppSpacing.md : AppSpacing.xs,
                          right: i == cards.length - 1 ? AppSpacing.md : 0,
                        ),
                        child: cards[i],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (cards.length > 1)
                    _PageDots(count: cards.length, index: page),
                ],
              ),
            ),
            // Pinned just above the floating nav bar. The shell extends its
            // body behind the bar, so bottom padding here is the bar's height.
            Positioned(
              left: 0,
              right: 0,
              bottom: MediaQuery.paddingOf(context).bottom + AppSpacing.xs,
              child: AnimatedSwitcher(
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : AppConstants.animMedium,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, 0.4),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                ),
                child: active == null
                    ? const SizedBox.shrink()
                    : ResumeWorkoutBar(
                        workout: active,
                        onResume: () => context.push(AppRoutes.activeWorkout),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 18) return 'Good afternoon';
  return 'Good evening';
}

/// The top of the Dashboard: avatar with the bell and stats buttons, the
/// mascot floating between them, the greeting and headline, then the
/// Streak and Grit cards. Streak is the server's app-open streak;
/// Grit is the discipline score (tap for how it's worked out). Both
/// show a dash until loaded (or offline / signed out) rather than a
/// made-up number.
class _TopSection extends StatelessWidget {
  const _TopSection({
    required this.name,
    required this.streak,
    required this.discipline,
    required this.onDiscipline,
    required this.onStats,
  });

  final String name;
  final StreakStatus? streak;
  final DisciplineScore? discipline;
  final VoidCallback? onDiscipline;
  final VoidCallback onStats;

  static const double _avatarSize = 52;
  static const double _mascotSize = 150;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: _mascotSize - AppSpacing.lg,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0,
                top: AppSpacing.xs,
                child: HubAvatar(
                  name: name,
                  size: _avatarSize,
                  ringColor: AppColors.accentProgress,
                  glow: true,
                ),
              ),
              const Positioned(
                right: AppSizing.minTouchTarget + AppSpacing.sm,
                top: -AppSpacing.sm,
                width: _mascotSize,
                height: _mascotSize,
                child: _Mascot(),
              ),
              Positioned(
                right: 0,
                top: 0,
                child: Column(
                  children: [
                    HubSquareIconButton(
                      icon: LucideIcons.bell,
                      semanticLabel: 'Notifications',
                      showDot: true,
                      onPressed: () => ScaffoldMessenger.of(context)
                        ..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(content: Text('No new notifications')),
                        ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    HubSquareIconButton(
                      icon: LucideIcons.trendingUp,
                      semanticLabel: 'Analytics',
                      onPressed: onStats,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Text(
          '${_greeting()}, $name',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.hubTextBody),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Keep your streak alive.',
          style: AppTypography.headlineLarge.copyWith(
            color: AppColors.hubTextBright,
            fontWeight: AppTypography.bold,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _StreakCard(streak: streak)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _GritCard(score: discipline, onTap: onDiscipline),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The Dashboard mascot, its dark backdrop faded into the page.
class _Mascot extends StatelessWidget {
  const _Mascot();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: (rect) => const RadialGradient(
          radius: 0.55,
          colors: [AppColors.white, AppColors.white, AppColors.transparent],
          stops: [0, 0.7, 1],
        ).createShader(rect),
        child: Image.asset(
          'assets/images/hub/dash-mascot.jpg',
          fit: BoxFit.contain,
          semanticLabel: 'Grit mascot',
          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

/// Shared look for the two stat cards.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.eyebrow,
    required this.child,
    this.onTap,
    this.semanticLabel,
  });

  final String eyebrow;
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.hubHero);
    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      excludeSemantics: semanticLabel != null,
      child: Material(
        color: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.hubCardBorderStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.hubCardTop, AppColors.hubCardBottom],
            ),
          ),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md - 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HubEyebrow(eyebrow),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  const _StreakCard({required this.streak});

  final StreakStatus? streak;

  @override
  Widget build(BuildContext context) {
    final s = streak;
    return _StatCard(
      eyebrow: 'STREAK',
      semanticLabel: s == null
          ? 'Streak loading'
          : '${s.current} day streak. Best ${s.longest} days.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (rect) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.streakFlameStart,
                    AppColors.streakFlameEnd,
                  ],
                ).createShader(rect),
                child: const Icon(
                  LucideIcons.flame,
                  size: AppSizing.iconLg,
                  color: AppColors.white,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  s == null ? '–' : '${s.current}',
                  maxLines: 1,
                  style: AppTypography.numeric(AppTypography.displaySmall)
                      .copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.bold,
                    height: 1,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Text(
                s?.current == 1 ? 'DAY' : 'DAYS',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.accentAction,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: AppSpacing.xs),
          Text(
            s == null ? 'Best: –' : 'Best: ${s.longest} days',
            style: AppTypography.labelMedium
                .copyWith(color: AppColors.hubTextMuted),
          ),
        ],
      ),
    );
  }
}

class _GritCard extends StatelessWidget {
  const _GritCard({required this.score, required this.onTap});

  final DisciplineScore? score;
  final VoidCallback? onTap;

  String get _caption {
    final v = score?.score;
    if (v == null) return 'Shows up after your first day.';
    if (v >= 80) return 'Train today to keep your grit.';
    if (v >= 50) return 'A session today pushes this up.';
    return 'Show up today to rebuild it.';
  }

  @override
  Widget build(BuildContext context) {
    final v = score?.score;
    return _StatCard(
      eyebrow: 'GRIT',
      onTap: onTap,
      semanticLabel: v == null ? 'Grit loading' : 'Grit $v percent. $_caption',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: HubProgressBar(
                  value: (v ?? 0) / 100,
                  height: AppSpacing.xs + 2,
                  colors: const [
                    AppColors.hubBarStart,
                    AppColors.accentProgress,
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text.rich(
                TextSpan(
                  text: v == null ? '–' : '$v',
                  children: [
                    TextSpan(
                      text: '%',
                      style: AppTypography.titleSmall
                          .copyWith(color: AppColors.hubTextBody),
                    ),
                  ],
                ),
                style: AppTypography.numeric(AppTypography.headlineMedium)
                    .copyWith(
                  color: AppColors.hubTextBright,
                  fontWeight: AppTypography.bold,
                ),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _caption,
            maxLines: 2,
            style: AppTypography.labelMedium
                .copyWith(color: AppColors.hubTextMuted),
          ),
        ],
      ),
    );
  }
}

/// Small text + icon link in the "Your Plan" row.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.color,
    required this.onTap,
    this.iconAfter = false,
  });

  final IconData icon;
  final String label;
  final String semanticLabel;
  final Color color;
  final VoidCallback onTap;
  final bool iconAfter;

  @override
  Widget build(BuildContext context) {
    final iconWidget = Icon(icon, size: AppSizing.iconSm + 2, color: color);
    final text = Text(
      label,
      style: AppTypography.titleSmall.copyWith(color: color),
    );
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.small),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xs),
          child: Row(
            children: iconAfter
                ? [text, const SizedBox(width: AppSpacing.xxs), iconWidget]
                : [iconWidget, const SizedBox(width: AppSpacing.xxs), text],
          ),
        ),
      ),
    );
  }
}

/// How the discipline score was worked out, in plain numbers.
class _DisciplineSheet extends StatelessWidget {
  const _DisciplineSheet({required this.score});

  final DisciplineScore score;

  @override
  Widget build(BuildContext context) {
    final planned = score.plannedWorkouts;
    final rows = <(String, String)>[
      (
        'Days you opened Grit',
        '${score.activeDays} of ${score.windowDays}',
      ),
      (
        'Workouts done vs. plan',
        planned == null
            ? 'No plan yet'
            : '${score.completedWorkouts} of ${planned.toStringAsFixed(1)}',
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
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
          Text(
            'Discipline ${score.score}',
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.hubTextBright,
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            'Last ${score.windowDays} days',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.hubTextMuted),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final (label, value) in rows)
            Container(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.divider)),
              ),
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
                    value,
                    style: AppTypography.numeric(AppTypography.labelLarge)
                        .copyWith(color: AppColors.accentProgress),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            planned == null
                ? 'Your score is the share of days you showed up. Add a '
                    'template to plan your week and workouts will count too.'
                : 'Half your score is showing up, half is training to plan. '
                    'Each template counts as one session a week.',
            style:
                AppTypography.bodySmall.copyWith(color: AppColors.hubTextMuted),
          ),
        ],
      ),
    );
  }
}

// Shared frame for every card in the row: big rounded card, art at the
/// top, dark fade, content and a full-width pill button at the bottom.
class _CardFrame extends StatelessWidget {
  const _CardFrame({
    required this.glow,
    required this.chip,
    required this.title,
    required this.meta,
    required this.buttonLabel,
    required this.onButton,
    this.extra,
    this.art,
    this.onTap,
  });

  final Color glow;
  final String chip;
  final String title;
  final String meta;
  final String buttonLabel;
  final VoidCallback? onButton;
  final Widget? extra;
  final Widget? art;
  final VoidCallback? onTap;

  static const double _buttonHeight = 54;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.xl + AppSpacing.xxs);
    return Material(
      color: AppColors.hubCardBottom,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.hubCardBorderStrong),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Coloured light from the top, like a lit gym.
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.2, -0.9),
                  radius: 1.1,
                  colors: [
                    glow.withValues(alpha: 0.45),
                    AppColors.hubHeroMid,
                    AppColors.hubCardBottom,
                  ],
                  stops: const [0, 0.55, 1],
                ),
              ),
            ),
            if (art != null) art!,
            // Fade so the text reads over the art.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.transparent,
                    AppColors.transparent,
                    AppColors.hubCardBottom,
                  ],
                  stops: [0, 0.45, 0.8],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg - 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xxs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(AppRadius.small),
                    ),
                    child: Text(
                      chip,
                      style: AppTypography.labelLarge.copyWith(
                        color: AppColors.white,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    title.toUpperCase(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.displayMedium.copyWith(
                      color: AppColors.white,
                      fontWeight: AppTypography.extraBold,
                      height: 1.02,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    meta,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.hubTextBody,
                      fontWeight: AppTypography.regular,
                    ),
                  ),
                  if (extra != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    extra!,
                  ],
                  const SizedBox(height: AppSpacing.lg - 2),
                  _GradientPill(
                    label: buttonLabel,
                    height: _buttonHeight,
                    onPressed: onButton,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app's primary pill (same look as the auth GradientPillButton):
/// orange → coral → teal gradient with a soft two-tone glow.
class _GradientPill extends StatelessWidget {
  const _GradientPill({
    required this.label,
    required this.height,
    required this.onPressed,
  });

  final String label;
  final double height;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Opacity(
      opacity: onPressed == null ? 0.5 : 1,
      child: Container(
        height: height,
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

/// The muscle "hologram" filling the top of a card: the body map lit for
/// the muscles the card's exercises work (primary bright, secondary
/// dimmer), zoomed in on them so they read up close, on whichever side
/// shows them best. Whole body, unlit, until the muscle data arrives.
class _CardArt extends StatelessWidget {
  const _CardArt({required this.muscles});

  final Map<Muscle, double> muscles;

  /// Back when the back carries more of the work (a pull day), else front.
  static BodyView _side(Map<Muscle, double> muscles) {
    var front = 0.0;
    var back = 0.0;
    for (final e in muscles.entries) {
      if (e.key.views.contains(BodyView.front)) front += e.value;
      if (e.key.views.contains(BodyView.back)) back += e.value;
    }
    return back > front ? BodyView.back : BodyView.front;
  }

  @override
  Widget build(BuildContext context) {
    final names = [for (final m in muscles.keys) m.label].join(', ');
    return Positioned(
      left: AppSpacing.xs,
      right: AppSpacing.xs,
      top: AppSpacing.xl,
      bottom: AppSpacing.xl4 * 2 - AppSpacing.md,
      child: IgnorePointer(
        child: MuscleMapView(
          view: _side(muscles),
          intensities: muscles,
          zoomToHighlight: true,
          semanticLabel: muscles.isEmpty ? null : 'Works $names',
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.template,
    required this.index,
    required this.count,
    required this.muscles,
    required this.onView,
  });

  final WorkoutTemplate template;
  final int index;
  final int count;
  final Map<Muscle, double> muscles;
  final VoidCallback onView;

  /// Each card gets its own light so neighbours read as different days.
  static const _glows = [
    AppColors.accentProgress,
    AppColors.hubRing,
    AppColors.skillViolet,
    AppColors.heroGlow,
  ];

  @override
  Widget build(BuildContext context) {
    final exercises = template.exercises.length;
    final sets = template.exercises
        .fold<int>(0, (sum, e) => sum + math.max(1, e.defaultSets ?? 1));
    return Semantics(
      label: '${template.name}, $exercises exercises, $sets sets. '
          'Workout ${index + 1} of $count.',
      child: _CardFrame(
        glow: _glows[index % _glows.length],
        chip: 'Day ${index + 1}',
        title: template.name,
        meta: '$exercises exercises · $sets sets',
        art: _CardArt(muscles: muscles),
        buttonLabel: 'View',
        onButton: onView,
        onTap: onView,
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({
    required this.workout,
    required this.muscles,
    required this.onResume,
  });

  final ActiveWorkout workout;
  final Map<Muscle, double> muscles;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final sets =
        workout.exercises.expand((e) => e.sets).where((s) => s.completed);
    final minutes = DateTime.now().difference(workout.startedAt).inMinutes;
    return _CardFrame(
      glow: AppColors.accentProgress,
      chip: 'In progress',
      title: workout.title,
      meta: '$minutes min · ${workout.exercises.length} exercises · '
          '${sets.length} sets done',
      art: _CardArt(muscles: muscles),
      buttonLabel: 'Resume',
      onButton: onResume,
      onTap: onResume,
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return _CardFrame(
      glow: AppColors.hubRing,
      chip: 'Templates',
      title: title,
      meta: body,
      art: Positioned.fill(
        bottom: AppSpacing.xl4 * 2,
        child: Center(
          child: Icon(
            icon,
            size: AppSizing.iconLg * 2.5,
            color: AppColors.white.withValues(alpha: 0.18),
          ),
        ),
      ),
      buttonLabel: action,
      onButton: onAction,
      onTap: onAction,
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _CardFrame(
      glow: AppColors.hubRing,
      chip: 'Your Plan',
      title: 'Loading…',
      meta: 'Fetching your templates',
      buttonLabel: 'View',
      onButton: null,
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppConstants.animMedium,
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs / 2),
            width: i == index ? AppSpacing.md + 2 : AppSpacing.xs - 2,
            height: AppSpacing.xs - 2,
            decoration: BoxDecoration(
              color: i == index
                  ? AppColors.hubTextBright
                  : AppColors.hubTextFaint.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
      ],
    );
  }
}

/// Bottom sheet listing a template's exercises with a Start button.
class _TemplatePreviewSheet extends StatelessWidget {
  const _TemplatePreviewSheet({
    required this.template,
    required this.canStart,
    required this.onStart,
  });

  final WorkoutTemplate template;

  /// False while another workout is in progress.
  final bool canStart;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final items = template.exercises;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.8,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
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
            Text(
              template.name,
              style: AppTypography.headlineMedium.copyWith(
                color: AppColors.hubTextBright,
                fontWeight: AppTypography.bold,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              '${items.length} exercises',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.hubTextMuted),
            ),
            const SizedBox(height: AppSpacing.md),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, i) {
                  final sets = math.max(1, items[i].defaultSets ?? 1);
                  return Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Row(
                      children: [
                        SizedBox(
                          width: AppSpacing.lg,
                          child: Text(
                            '${i + 1}',
                            style:
                                AppTypography.numeric(AppTypography.labelLarge)
                                    .copyWith(color: AppColors.accentProgress),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            items[i].exercise.name,
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.hubTextBright),
                          ),
                        ),
                        Text(
                          '$sets ${sets == 1 ? 'set' : 'sets'}',
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.hubTextMuted),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            if (!canStart) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Finish or resume your current workout first.',
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.hubTextMuted),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              height: AppSizing.buttonHeight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentAction,
                  foregroundColor: AppColors.white,
                  disabledBackgroundColor:
                      AppColors.white.withValues(alpha: 0.12),
                  shape: const StadiumBorder(),
                ),
                onPressed: canStart ? onStart : null,
                child: Text(
                  'Start workout',
                  style: AppTypography.button.copyWith(
                    color: AppColors.white,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
