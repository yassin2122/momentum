import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../domain/entities/muscle.dart';
import '../../domain/entities/muscle_activity.dart';
import '../../domain/services/muscle_highlight.dart';
import '../providers/muscle_map_providers.dart';
import '../widgets/muscle_detail_sheet.dart';
import '../widgets/muscle_map_view.dart';

/// Full-screen muscle map: front/back body lit by completed workouts in a
/// chosen window; tap a muscle for its history.
class MuscleMapScreen extends ConsumerStatefulWidget {
  const MuscleMapScreen({super.key});

  @override
  ConsumerState<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends ConsumerState<MuscleMapScreen> {
  BodyView _view = BodyView.front;
  Muscle? _selected;

  Future<void> _open(Muscle muscle, MuscleActivityReport report) async {
    setState(() {
      _selected = muscle;
      // Lower back has no drawn region; keep the current side for it.
      if (muscle.views.isNotEmpty && !muscle.views.contains(_view)) {
        _view = muscle.views.first;
      }
    });
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.achSheet,
      barrierColor: AppColors.achScrim,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
      ),
      builder: (_) => MuscleDetailSheet(
        muscle: muscle,
        activity: report.byMuscle[muscle],
        windowDays: report.windowDays,
      ),
    );
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(muscleWindowDaysProvider);
    final report = ref.watch(muscleActivityProvider);
    final data = report.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.hubBackgroundBottom,
      body: HubBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    HubBackButton(onPressed: () => context.pop()),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Muscle activity',
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.hubTextBright,
                          fontWeight: AppTypography.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    for (final v in BodyView.values) ...[
                      _Toggle(
                        label: v == BodyView.front ? 'Front' : 'Back',
                        selected: _view == v,
                        onTap: () => setState(() => _view = v),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    const Spacer(),
                    PopupMenuButton<int>(
                      tooltip: 'Time window',
                      color: AppColors.achSheet,
                      initialValue: days,
                      onSelected: (d) => ref
                          .read(muscleWindowDaysProvider.notifier)
                          .state = d,
                      itemBuilder: (_) => [
                        for (final d in muscleWindowOptions)
                          PopupMenuItem(
                            value: d,
                            child: Text(
                              'Last $d days',
                              style: AppTypography.bodyMedium
                                  .copyWith(color: AppColors.hubTextBright),
                            ),
                          ),
                      ],
                      child: HubPill(
                        label: 'Last $days days',
                        icon: LucideIcons.calendar,
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: AppConstants.animMedium,
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, anim) => FadeTransition(
                            opacity: anim,
                            child: ScaleTransition(
                              scale: Tween(begin: 0.96, end: 1.0).animate(anim),
                              child: child,
                            ),
                          ),
                          child: Padding(
                            key: ValueKey(_view),
                            padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md),
                            child: MuscleMapView(
                              view: _view,
                              intensities: data?.intensities ?? const {},
                              selected: _selected,
                              semanticLabel: _semantics(data),
                              onMuscleTap: data == null
                                  ? null
                                  : (m) {
                                      if (m != null) _open(m, data);
                                    },
                            ),
                          ),
                        ),
                      ),
                      if (report.isLoading)
                        const Positioned(
                            top: 0, right: 0, child: HubLoading()),
                    ],
                  ),
                ),
                if (report.hasError && data == null)
                  HubMessageCard(
                    icon: LucideIcons.wifiOff,
                    title: "Couldn't load your workouts",
                    message: 'Check your connection and try again.',
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(muscleActivityProvider),
                  )
                else
                  _Footer(
                    report: data,
                    onMuscle: data == null ? null : (m) => _open(m, data),
                  ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _semantics(MuscleActivityReport? r) {
    final side = _view == BodyView.front ? 'front' : 'back';
    if (r == null || r.byMuscle.isEmpty) return 'Body map, $side. No activity.';
    final trained = r.byMuscle.keys.map((m) => m.label).join(', ');
    return 'Body map, $side. Trained in the last ${r.windowDays} days: '
        '$trained. Tap a muscle for details.';
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.hubHeroGlow : AppColors.hubIconButton,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected
                ? AppColors.accentProgress
                : AppColors.hubCardBorder,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.xs),
            child: Text(
              label,
              style: AppTypography.labelLarge.copyWith(
                color: selected
                    ? AppColors.hubTextBright
                    : AppColors.hubTextMuted,
                fontWeight: AppTypography.semiBold,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Legend, trained-muscle chips (a non-spatial way to open details) and
/// data notes.
class _Footer extends StatelessWidget {
  const _Footer({required this.report, required this.onMuscle});

  final MuscleActivityReport? report;
  final ValueChanged<Muscle>? onMuscle;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final trained = r == null
        ? const <MuscleActivity>[]
        : (r.byMuscle.values.toList()..sort((a, b) => b.load.compareTo(a.load)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: AppSpacing.xl2,
              height: AppSpacing.xs - 2,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.pill),
                gradient: const LinearGradient(colors: [
                  AppColors.anatomyCyanDeep,
                  AppColors.anatomyCyan,
                ]),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                r == null
                    ? 'Loading your workouts…'
                    : r.workoutCount == 0
                        ? 'No completed workouts in the last ${r.windowDays} days.'
                        : 'Brighter = more sets · ${r.workoutCount} '
                            '${r.workoutCount == 1 ? 'workout' : 'workouts'}. '
                            'Volume, not recovery.',
                style: AppTypography.caption
                    .copyWith(color: AppColors.hubTextMuted),
              ),
            ),
          ],
        ),
        if (trained.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: AppSpacing.xl + AppSpacing.xxs,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: trained.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) => ActionChip(
                backgroundColor: AppColors.hubIconButton,
                side: const BorderSide(color: AppColors.hubCardBorder),
                shape: const StadiumBorder(),
                label: Text(
                  '${trained[i].muscle.label} · ${trained[i].totalSets}',
                  style: AppTypography.labelMedium
                      .copyWith(color: AppColors.hubTextBody),
                ),
                onPressed:
                    onMuscle == null ? null : () => onMuscle!(trained[i].muscle),
              ),
            ),
          ),
        ],
        if (r != null &&
            MuscleHighlight.undrawn(r.intensities).isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Not drawn on the map: '
            '${MuscleHighlight.undrawn(r.intensities).map((m) => m.label).join(', ')}'
            ' — tap its chip above for details.',
            style: AppTypography.caption.copyWith(color: AppColors.hubTextFaint),
          ),
        ],
        if (r != null && r.unmappedExercises.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No muscle data yet for: ${r.unmappedExercises.join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(color: AppColors.hubTextFaint),
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        // Required by the art's CC BY 4.0 licence.
        Text(
          'Anatomy illustration © Ryan Graves, CC BY 4.0',
          style: AppTypography.labelSmall.copyWith(color: AppColors.hubTextFaint),
        ),
      ],
    );
  }
}
