import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'dashboard_painters.dart';

/// Activity rings card — three concentric rings (Move/Exercise/Stand) with
/// a three-row legend. Fits the right slot of the top stats row.
///
/// Rings animate from 0 → target progress on first load (800 ms each,
/// 150 ms stagger outer→inner, easeOutQuart) per spec §15.
///
/// Ring colors and order are non-negotiable per spec §22:
///   outer=Move/red, middle=Exercise/green, inner=Stand/cyan.
class ActivityRingsCard extends StatefulWidget {
  const ActivityRingsCard({
    required this.moveProgress,
    required this.exerciseProgress,
    required this.standProgress,
    required this.moveLabel,
    required this.exerciseLabel,
    required this.standLabel,
    super.key,
  });

  /// 0.0–1.0 fractions for each ring.
  final double moveProgress;
  final double exerciseProgress;
  final double standProgress;

  /// Value strings shown in legend rows (e.g. "620 / 800 kcal").
  final String moveLabel;
  final String exerciseLabel;
  final String standLabel;

  @override
  State<ActivityRingsCard> createState() => _ActivityRingsCardState();
}

class _ActivityRingsCardState extends State<ActivityRingsCard>
    with TickerProviderStateMixin {
  late AnimationController _moveCtrl;
  late AnimationController _exerciseCtrl;
  late AnimationController _standCtrl;

  late Animation<double> _moveAnim;
  late Animation<double> _exerciseAnim;
  late Animation<double> _standAnim;

  static const _ringDuration = Duration(milliseconds: 800);
  static const _stagger = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();

    _moveCtrl = AnimationController(vsync: this, duration: _ringDuration);
    _exerciseCtrl = AnimationController(vsync: this, duration: _ringDuration);
    _standCtrl = AnimationController(vsync: this, duration: _ringDuration);

    _moveAnim = CurvedAnimation(
        parent: _moveCtrl, curve: Curves.easeOutQuart);
    _exerciseAnim = CurvedAnimation(
        parent: _exerciseCtrl, curve: Curves.easeOutQuart);
    _standAnim = CurvedAnimation(
        parent: _standCtrl, curve: Curves.easeOutQuart);

    // Stagger start: outer ring first, inner last.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _moveCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 300) + _stagger, () {
      if (mounted) _exerciseCtrl.forward();
    });
    Future.delayed(const Duration(milliseconds: 300) + _stagger * 2, () {
      if (mounted) _standCtrl.forward();
    });
  }

  @override
  void dispose() {
    _moveCtrl.dispose();
    _exerciseCtrl.dispose();
    _standCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.cardCompact),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Row(
        children: [
          // ── Rings ────────────────────────────────────────────────────
          AnimatedBuilder(
            animation: Listenable.merge(
                [_moveAnim, _exerciseAnim, _standAnim]),
            builder: (_, __) {
              return SizedBox(
                width: 90,
                height: 90,
                child: CustomPaint(
                  painter: ActivityRingsPainter(
                    moveProgress:
                        _moveAnim.value * widget.moveProgress,
                    exerciseProgress:
                        _exerciseAnim.value * widget.exerciseProgress,
                    standProgress:
                        _standAnim.value * widget.standProgress,
                  ),
                ),
              );
            },
          ),

          const SizedBox(width: AppSpacing.xs),

          // ── Legend ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RingLegendRow(
                  color: AppColors.ringMove,
                  label: 'Move',
                  value: widget.moveLabel,
                ),
                const SizedBox(height: 6),
                _RingLegendRow(
                  color: AppColors.ringExercise,
                  label: 'Exercise',
                  value: widget.exerciseLabel,
                ),
                const SizedBox(height: 6),
                _RingLegendRow(
                  color: AppColors.ringStand,
                  label: 'Stand',
                  value: widget.standLabel,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Legend row: colored dot + ring name + value
// ─────────────────────────────────────────────────────────────────────────────

class _RingLegendRow extends StatelessWidget {
  const _RingLegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            fontSize: 11,
            fontWeight: AppTypography.semiBold,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: AppTypography.caption.copyWith(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
