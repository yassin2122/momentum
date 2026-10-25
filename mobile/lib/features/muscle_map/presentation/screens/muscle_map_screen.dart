import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/motion.dart';
import '../../../analytics/presentation/widgets/analytics_chrome.dart';
import '../../domain/entities/muscle.dart';
import '../../domain/entities/muscle_activity.dart';
import '../../domain/services/muscle_highlight.dart';
import '../providers/muscle_map_providers.dart';
import '../widgets/muscle_detail_sheet.dart';
import '../widgets/muscle_map_view.dart';

/// Full-screen muscle hologram: front/back body lit by completed workouts
/// in a chosen window; tap a muscle (or its chip) for its history.
///
/// Same graphite canvas and header as the other Analytics screens, with
/// the hologram's own electric-cyan accent. The body scans in on open,
/// flips with the Front/Back control or a horizontal swipe, and the time
/// window is a segmented control at the top like Distribution's.
class MuscleMapScreen extends ConsumerStatefulWidget {
  const MuscleMapScreen({super.key});

  @override
  ConsumerState<MuscleMapScreen> createState() => _MuscleMapScreenState();
}

class _MuscleMapScreenState extends ConsumerState<MuscleMapScreen> {
  BodyView _view = BodyView.front;
  Muscle? _selected;

  /// Horizontal fling speed (logical px/s) that flips the body.
  static const double _flipVelocity = 300;

  Future<void> _open(Muscle muscle, MuscleActivityReport report) async {
    setState(() {
      _selected = muscle;
      // Lower back has no drawn region; keep the current side for it.
      if (muscle.views.isNotEmpty && !muscle.views.contains(_view)) {
        _view = muscle.views.first;
      }
    });
    await showModalBottomSheet<void>(
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
      builder: (_) => MuscleDetailSheet(
        muscle: muscle,
        activity: report.byMuscle[muscle],
        windowDays: report.windowDays,
      ),
    );
    if (mounted) setState(() => _selected = null);
  }

  void _setView(BodyView v) {
    if (v == _view) return;
    setState(() => _view = v);
  }

  void _flip() {
    HapticFeedback.selectionClick();
    _setView(_view == BodyView.front ? BodyView.back : BodyView.front);
  }

  @override
  Widget build(BuildContext context) {
    final days = ref.watch(muscleWindowDaysProvider);
    final report = ref.watch(muscleActivityProvider);
    final data = report.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.analyticsBgBottom,
      body: DecoratedBox(
        decoration: BoxDecoration(
          // The analytics canvas recipe, lit from behind the body.
          gradient: RadialGradient(
            center: const Alignment(0, -0.2),
            radius: 1.1,
            colors: [
              Color.alphaBlend(
                AppColors.anatomyCyan.withValues(alpha: 0.08),
                AppColors.analyticsBgTop,
              ),
              AppColors.analyticsBgBottom,
            ],
            stops: const [0, 0.75],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.xs),
                const Entrance(
                  child: AnalyticsHeader(
                    eyebrow: 'Front & back · tap any muscle',
                    title: 'Hologram',
                    accent: AppColors.anatomyCyan,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Entrance(
                  index: 1,
                  child: AnalyticsSegmented<int>(
                    options: muscleWindowOptions,
                    selected: days,
                    labelOf: (d) => '${d}d',
                    accent: AppColors.anatomyCyan,
                    onChanged: (d) =>
                        ref.read(muscleWindowDaysProvider.notifier).state = d,
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: GestureDetector(
                          // Swipe sideways to turn the body around.
                          onHorizontalDragEnd: (d) {
                            if ((d.primaryVelocity ?? 0).abs() >
                                _flipVelocity) {
                              _flip();
                            }
                          },
                          child: AnimatedSwitcher(
                            duration: reduceMotionOf(context)
                                ? Duration.zero
                                : AppConstants.animMedium,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, anim) => FadeTransition(
                              opacity: anim,
                              child: ScaleTransition(
                                scale:
                                    Tween(begin: 0.96, end: 1.0).animate(anim),
                                child: child,
                              ),
                            ),
                            child: Padding(
                              key: ValueKey(_view),
                              padding: const EdgeInsets.symmetric(
                                  vertical: AppSpacing.md),
                              child: MuscleMapView(
                                view: _view,
                                scanIn: true,
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
                      ),
                      if (report.isLoading)
                        const Positioned(
                          top: AppSpacing.sm,
                          right: 0,
                          child: SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.anatomyCyan,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Lower on screen, within thumb reach.
                Center(
                  child: SizedBox(
                    width: 200,
                    child: AnalyticsSegmented<BodyView>(
                      options: BodyView.values,
                      selected: _view,
                      labelOf: (v) => v == BodyView.front ? 'Front' : 'Back',
                      accent: AppColors.anatomyCyan,
                      onChanged: _setView,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                AnalyticsSwap(
                  child: report.hasError && data == null
                      ? AnalyticsErrorPanel(
                          key: const ValueKey('error'),
                          message: 'Check your connection and try again.',
                          onRetry: () => ref.invalidate(muscleActivityProvider),
                        )
                      : _Footer(
                          key: const ValueKey('footer'),
                          report: data,
                          onMuscle: data == null ? null : (m) => _open(m, data),
                        ),
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

/// Legend, trained-muscle chips (a non-spatial way to open details) and
/// data notes.
class _Footer extends StatelessWidget {
  const _Footer({required this.report, required this.onMuscle, super.key});

  final MuscleActivityReport? report;
  final ValueChanged<Muscle>? onMuscle;

  @override
  Widget build(BuildContext context) {
    final r = report;
    final trained = r == null
        ? const <MuscleActivity>[]
        : (r.byMuscle.values.toList()
          ..sort((a, b) => b.load.compareTo(a.load)));
    final note = AppTypography.caption.copyWith(color: AppColors.silverDim);
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
                style: note,
              ),
            ),
          ],
        ),
        if (trained.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: _chipHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: trained.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) => _MuscleChip(
                activity: trained[i],
                onTap: onMuscle == null
                    ? null
                    : () => onMuscle!(trained[i].muscle),
              ),
            ),
          ),
        ],
        if (r != null && MuscleHighlight.undrawn(r.intensities).isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Not drawn on the map: '
            '${MuscleHighlight.undrawn(r.intensities).map((m) => m.label).join(', ')}'
            ' — tap its chip above for details.',
            style: note,
          ),
        ],
        if (r != null && r.unmappedExercises.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            'No muscle data yet for: ${r.unmappedExercises.join(', ')}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: note,
          ),
        ],
        const SizedBox(height: AppSpacing.xs),
        // Required by the art's CC BY 4.0 licence.
        Text(
          'Anatomy illustration © Ryan Graves, CC BY 4.0',
          style: AppTypography.labelSmall.copyWith(color: AppColors.silverDim),
        ),
      ],
    );
  }
}

/// Chip row height (keeps chips comfortably tappable).
const double _chipHeight = 36;

/// Graphite chip for a trained muscle, with a cyan dot tying it to the map.
class _MuscleChip extends StatelessWidget {
  const _MuscleChip({required this.activity, required this.onTap});

  final MuscleActivity activity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadius.pill);
    return Semantics(
      button: true,
      label: '${activity.muscle.label}, ${activity.totalSets} sets',
      excludeSemantics: true,
      child: PressScale(
        scale: 0.95,
        builder: (context, onHighlight) => Material(
          color: AppColors.analyticsPanelBottom,
          shape: RoundedRectangleBorder(
            borderRadius: r,
            side: const BorderSide(color: AppColors.analyticsPanelBorder),
          ),
          child: InkWell(
            borderRadius: r,
            onTap: onTap,
            onHighlightChanged: onHighlight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.anatomyCyan,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs + 2),
                  Text(
                    '${activity.muscle.label} · ${activity.totalSets}',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.silver),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
