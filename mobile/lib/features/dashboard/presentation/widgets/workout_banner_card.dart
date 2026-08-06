import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../auth/presentation/widgets/gradient_pill_button.dart';
import 'dashboard_painters.dart';

/// Next-workout banner card — the primary-task card on the dashboard.
///
/// Contains:
///   • Eyebrow ("Next Workout") + chevron affordance
///   • Hero headline ("Push Day")
///   • Meta row (exercise count + estimated duration)
///   • GradientPillButton "Start" (reused from auth — pixel-identical
///     gradient per spec §22)
///   • MuscleHeatmapIllustration (right side)
///
/// Heatmap glow pulses on a 2 000 ms loop per spec §15.
/// Card tap produces scale 0.98 spring feedback.
class WorkoutBannerCard extends StatefulWidget {
  const WorkoutBannerCard({
    required this.workoutName,
    required this.exerciseCount,
    required this.estimatedMinutes,
    this.onTap,
    this.onStart,
    super.key,
  });

  final String workoutName;
  final int exerciseCount;
  final int estimatedMinutes;
  final VoidCallback? onTap;
  final VoidCallback? onStart;

  @override
  State<WorkoutBannerCard> createState() => _WorkoutBannerCardState();
}

class _WorkoutBannerCardState extends State<WorkoutBannerCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _scaleCtrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
      lowerBound: 0.98,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _scaleCtrl;
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _scaleCtrl.reverse(),
      onTapUp: (_) {
        _scaleCtrl.forward();
        widget.onTap?.call();
      },
      onTapCancel: () => _scaleCtrl.forward(),
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppRadius.cardLarge),
            border: Border.all(color: AppColors.cardBorder, width: 1),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.cardLarge),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left content column ──────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      AppSpacing.md,
                      AppSpacing.sm,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Eyebrow + chevron
                        Row(
                          children: [
                            Text(
                              'Next Workout',
                              style: AppTypography.caption.copyWith(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              LucideIcons.chevronRight,
                              size: 14,
                              color: AppColors.textTertiary,
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.xxs),

                        // Workout name headline
                        Text(
                          widget.workoutName,
                          style: AppTypography.displaySmall.copyWith(
                            fontSize: 28,
                            fontWeight: AppTypography.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: AppSpacing.xxs),

                        // Meta row
                        Row(
                          children: [
                            const Icon(
                              LucideIcons.dumbbell,
                              size: 13,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.exerciseCount} Exercises  •  '
                              '~${widget.estimatedMinutes} min',
                              style: AppTypography.caption.copyWith(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: AppSpacing.md),

                        // Start button (gradient pill — same as login CTA)
                        SizedBox(
                          height: 44,
                          child: GradientPillButton(
                            label: 'Start',
                            onPressed: widget.onStart ?? () {},
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Right: muscle heatmap ────────────────────────────────
                SizedBox(
                  width: 110,
                  child: _HeatmapPanel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Muscle heatmap panel — looping glow pulse + CustomPaint
// ─────────────────────────────────────────────────────────────────────────────

class _HeatmapPanel extends StatefulWidget {
  @override
  State<_HeatmapPanel> createState() => _HeatmapPanelState();
}

class _HeatmapPanelState extends State<_HeatmapPanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _glowAnim = CurvedAnimation(
      parent: _glowCtrl,
      curve: Curves.easeInOutSine,
    );
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, __) {
        // Clamp glow: 0.55 → 1.0
        final opacity = 0.55 + _glowAnim.value * 0.45;
        return CustomPaint(
          painter: MuscleHeatmapPainter(glowOpacity: opacity),
          size: Size.infinite,
        );
      },
    );
  }
}
