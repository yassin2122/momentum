import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Streak stat card — flame icon gradient + streak number count-up +
/// "Day streak" label + motivational subtext.
///
/// Fits the left slot of the top stats row (beside ActivityRingsCard).
/// Card grammar: `cardSurface` fill + `cardBorder` hairline + 20 px radius
/// per spec §12.
///
/// Animations per spec §15:
///   • Flame: subtle scale pulse 1.0→1.08→1.0, 1 500 ms loop.
///   • Number: count-up from 0 to [streakDays] on first load, 600 ms.
class StreakCard extends StatefulWidget {
  const StreakCard({
    required this.streakDays,
    this.subtext = 'Keep going!',
    super.key,
  });

  final int streakDays;

  /// Motivational micro-copy. Changes based on streak length per spec §22.
  final String subtext;

  @override
  State<StreakCard> createState() => _StreakCardState();
}

class _StreakCardState extends State<StreakCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _countCtrl;
  late Animation<double> _countAnim;

  @override
  void initState() {
    super.initState();
    _countCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _countAnim = CurvedAnimation(
      parent: _countCtrl,
      curve: Curves.easeOutExpo,
    );
    // Start counting after the stagger delay gives the card time to enter.
    Future.delayed(const Duration(milliseconds: 350), () {
      if (mounted) _countCtrl.forward();
    });
  }

  @override
  void dispose() {
    _countCtrl.dispose();
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Flame icon (pulsing) ─────────────────────────────────────
          _FlameIcon()
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scaleXY(
                begin: 1.0,
                end: 1.08,
                duration: const Duration(milliseconds: 1500),
                curve: Curves.easeInOutSine,
              ),

          const SizedBox(height: AppSpacing.xs),

          // ── Streak number (count-up) ─────────────────────────────────
          AnimatedBuilder(
            animation: _countAnim,
            builder: (_, __) {
              final val =
                  (_countAnim.value * widget.streakDays).round();
              return Text(
                '$val',
                style: AppTypography.headlineMedium.copyWith(
                  fontSize: 22,
                  fontWeight: AppTypography.bold,
                  color: AppColors.streakFlameStart,
                  letterSpacing: -0.3,
                ),
              );
            },
          ),

          // ── "Day streak" label ───────────────────────────────────────
          Text(
            'Day streak',
            style: AppTypography.caption.copyWith(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),

          const SizedBox(height: AppSpacing.xxs),

          // ── Subtext ──────────────────────────────────────────────────
          Text(
            widget.subtext,
            style: AppTypography.caption.copyWith(
              fontSize: 12,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Flame icon — gradient ShaderMask over the filled flame lucide icon.
// Filled, not outlined, per spec §10: "a filled flame reads as lit/active."
// ─────────────────────────────────────────────────────────────────────────────

class _FlameIcon extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (bounds) {
        return const LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [AppColors.streakFlameStart, AppColors.streakFlameEnd],
        ).createShader(bounds);
      },
      blendMode: BlendMode.srcIn,
      child: const Icon(Icons.local_fire_department_rounded, size: 32),
    );
  }
}
