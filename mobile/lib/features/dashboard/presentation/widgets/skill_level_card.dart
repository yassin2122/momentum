import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import 'dashboard_painters.dart';

/// Calisthenics skill / level progression card.
///
/// Contains:
///   • HexagonBadge (violet gradient + outer glow, left)
///   • Skill title ("Calisthenics Level")
///   • Skill name headline ("Muscle Up")
///   • Level badge ("Level 8")
///   • SegmentedXPBar
///   • XP counter row ("350 / 500 XP" + "Next: …" + chevron)
///
/// XP segments light up sequentially left→right on load (600 ms total,
/// ~30 ms per segment) per spec §15.
class SkillLevelCard extends StatefulWidget {
  const SkillLevelCard({
    required this.skillTitle,
    required this.skillName,
    required this.level,
    required this.xpCurrent,
    required this.xpMax,
    required this.nextMilestone,
    super.key,
  });

  final String skillTitle;
  final String skillName;
  final int level;
  final int xpCurrent;
  final int xpMax;
  final String nextMilestone;

  @override
  State<SkillLevelCard> createState() => _SkillLevelCardState();
}

class _SkillLevelCardState extends State<SkillLevelCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _xpCtrl;
  late Animation<double> _xpAnim;

  @override
  void initState() {
    super.initState();
    _xpCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _xpAnim = CurvedAnimation(parent: _xpCtrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _xpCtrl.forward();
    });
  }

  @override
  void dispose() {
    _xpCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: hex badge + text ──────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hexagon badge
              const _HexagonBadge(),

              const SizedBox(width: AppSpacing.sm),

              // Title block
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.skillTitle,
                      style: AppTypography.caption.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.skillName,
                      style: AppTypography.displaySmall.copyWith(
                        fontSize: 28,
                        fontWeight: AppTypography.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _LevelBadge(level: widget.level),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ── Segmented XP bar ─────────────────────────────────────────
          AnimatedBuilder(
            animation: _xpAnim,
            builder: (_, __) {
              final fillFraction =
                  (widget.xpCurrent / widget.xpMax) * _xpAnim.value;
              return _SegmentedXPBar(fillFraction: fillFraction);
            },
          ),

          const SizedBox(height: AppSpacing.xs),

          // ── XP footer row ────────────────────────────────────────────
          Row(
            children: [
              Text(
                '${widget.xpCurrent} / ${widget.xpMax} XP',
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 13,
                  fontWeight: AppTypography.medium,
                  color: AppColors.skillVioletLight,
                ),
              ),
              const Spacer(),
              Text(
                'Next: ${widget.nextMilestone}',
                style: AppTypography.caption.copyWith(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(
                LucideIcons.chevronRight,
                size: 13,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hexagon badge — violet gradient + outer glow + dumbbell icon
// ─────────────────────────────────────────────────────────────────────────────

class _HexagonBadge extends StatelessWidget {
  const _HexagonBadge();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 56,
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Hex paint (glow + fill)
          CustomPaint(
            painter: HexagonPainter(),
            size: Size(56, 64),
          ),
          // Icon on top
          Icon(
            LucideIcons.dumbbell,
            size: 24,
            color: Colors.white,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Level badge — small pill with violet text
// ─────────────────────────────────────────────────────────────────────────────

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});
  final int level;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.skillViolet.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(
            color: AppColors.skillViolet.withValues(alpha: 0.40), width: 1),
      ),
      child: Text(
        'Level $level',
        style: AppTypography.labelSmall.copyWith(
          fontSize: 12,
          fontWeight: AppTypography.bold,
          color: AppColors.skillVioletLight,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Segmented XP bar — 18 discrete rounded-rect segments, filled left→right.
// Segmented (vs. continuous) reads as more "game-like" per spec §13.
// ─────────────────────────────────────────────────────────────────────────────

class _SegmentedXPBar extends StatelessWidget {
  const _SegmentedXPBar({required this.fillFraction});

  final double fillFraction; // 0.0–1.0

  static const int _segments = 18;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      const gap = 3.0;
      const totalGap = gap * (_segments - 1);
      final segWidth = (constraints.maxWidth - totalGap) / _segments;

      return Row(
        children: List.generate(_segments, (i) {
          final threshold = i / _segments;
          final filled = fillFraction > threshold;
          // Partial fill for the transitioning segment
          final partial = (fillFraction - threshold) * _segments;
          final fillWidth = filled
              ? segWidth
              : (partial > 0 && partial < 1)
                  ? segWidth * partial
                  : 0.0;

          return Padding(
            padding: EdgeInsets.only(right: i < _segments - 1 ? gap : 0),
            child: Container(
              width: segWidth,
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.xpTrack,
                borderRadius: BorderRadius.circular(3),
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: fillWidth.clamp(0.0, segWidth),
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.skillViolet,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: fillWidth > 0
                        ? [
                            BoxShadow(
                              color: AppColors.skillViolet
                                  .withValues(alpha: 0.50),
                              blurRadius: 4,
                            )
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          );
        }),
      );
    });
  }
}
