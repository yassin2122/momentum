import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../sample/achievements_sample_data.dart';
import '../widgets/achievement_badge.dart';
import '../widgets/achievement_detail_sheet.dart';

/// The unlock moment (design/canvas: ach/Unlock): the medallion rises,
/// light sweeps it, rings burst for epic and above, then the rarity,
/// title and actions fade in. Rarer badges take longer (≤ 2.4 s) and the
/// whole sequence is skippable; reduced motion jumps to the end.
class AchievementUnlockScreen extends StatefulWidget {
  const AchievementUnlockScreen({required this.achievementId, super.key});

  final String achievementId;

  @override
  State<AchievementUnlockScreen> createState() =>
      _AchievementUnlockScreenState();
}

class _AchievementUnlockScreenState extends State<AchievementUnlockScreen> {
  /// 0 hidden → 1 badge → 2 light/rings → 3 rarity → 4 text → 5 actions.
  int _phase = 0;
  final List<Timer> _timers = [];
  bool _started = false;

  static const Map<Rarity, List<int>> _timeline = {
    Rarity.common: [80, 600, 800, 1000, 1300],
    Rarity.uncommon: [80, 650, 900, 1100, 1450],
    Rarity.rare: [80, 700, 1000, 1250, 1650],
    Rarity.epic: [80, 750, 1100, 1400, 1850],
    Rarity.legendary: [80, 850, 1300, 1650, 2150],
    Rarity.mythic: [80, 950, 1450, 1850, 2400],
  };

  static const Map<Rarity, int> _riseMs = {
    Rarity.common: 500,
    Rarity.uncommon: 560,
    Rarity.rare: 620,
    Rarity.epic: 680,
    Rarity.legendary: 780,
    Rarity.mythic: 880,
  };

  static const double _badgeSize = 210;

  Achievement? get _achievement => achievementById(widget.achievementId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final a = _achievement;
    if (reduce || a == null) {
      _phase = 5;
      return;
    }
    final times = _timeline[a.rarity]!;
    for (var i = 0; i < times.length; i++) {
      _timers.add(
        Timer(Duration(milliseconds: times[i]), () {
          if (mounted) setState(() => _phase = i + 1);
        }),
      );
    }
  }

  void _skip() {
    for (final t in _timers) {
      t.cancel();
    }
    setState(() => _phase = 5);
  }

  void _close() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.achievements);

  @override
  void dispose() {
    for (final t in _timers) {
      t.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = _achievement;
    if (a == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
      return const Scaffold(backgroundColor: AppColors.achBackground);
    }
    final palette = a.rarity.palette;
    final rise = Duration(milliseconds: _riseMs[a.rarity]!);
    final epicPlus = a.rarity.index >= Rarity.epic.index;
    final mythic = a.rarity == Rarity.mythic;

    return Scaffold(
      backgroundColor: AppColors.achBackground,
      body: Stack(
        children: [
          // Rarity-tinted backdrop glow.
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: _phase >= 1 ? 1 : 0,
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOut,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.2),
                    radius: 0.85,
                    colors: [
                      palette.glow.withValues(alpha: 0.32),
                      palette.glow.withValues(alpha: mythic ? 0.1 : 0),
                      palette.glow.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: AppSpacing.sm + 2,
                      top: AppSpacing.xxs,
                    ),
                    child: AnimatedOpacity(
                      opacity: _phase >= 5 ? 0 : 1,
                      duration: const Duration(milliseconds: 200),
                      child: IgnorePointer(
                        ignoring: _phase >= 5,
                        child: OutlinedButton(
                          onPressed: _skip,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.phaseTextBody,
                            backgroundColor: AppColors.achSheet,
                            side: const BorderSide(color: AppColors.hudBorder),
                            shape: const StadiumBorder(),
                          ),
                          child: Text(
                            'Skip',
                            style: AppTypography.labelLarge.copyWith(
                              color: AppColors.phaseTextBody,
                              fontWeight: AppTypography.semiBold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: _badgeSize,
                  height: _badgeSize * 1.1,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (epicPlus && _phase >= 2)
                        _BurstRing(
                          color: palette.accent,
                          duration: const Duration(milliseconds: 1100),
                        ),
                      if (mythic && _phase >= 2)
                        _BurstRing(
                          color: palette.edgeMid,
                          duration: const Duration(milliseconds: 1500),
                          delay: const Duration(milliseconds: 250),
                        ),
                      AnimatedSlide(
                        offset: Offset(0, _phase >= 1 ? 0 : 0.2),
                        duration: rise,
                        curve: const Cubic(0.16, 1, 0.3, 1),
                        child: AnimatedScale(
                          scale: _phase >= 1 ? 1 : 0.86,
                          duration: rise,
                          curve: const Cubic(0.16, 1, 0.3, 1),
                          child: AnimatedOpacity(
                            opacity: _phase >= 1 ? 1 : 0,
                            duration: Duration(
                              milliseconds: (rise.inMilliseconds * 0.6).round(),
                            ),
                            child: AchievementBadge(
                              achievement: a,
                              size: _badgeSize,
                              animated: _phase >= 2,
                              forceEarned: true,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg + 4),
                _FadeUp(
                  visible: _phase >= 3,
                  offset: 8,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RarityHex(color: palette.label),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        a.rarity.label,
                        style: AppTypography.titleSmall.copyWith(
                          color: palette.label,
                          fontWeight: AppTypography.semiBold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                _FadeUp(
                  visible: _phase >= 4,
                  offset: 10,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Column(
                      children: [
                        Text(
                          'Achievement unlocked',
                          style: AppTypography.labelLarge
                              .copyWith(color: AppColors.achTextMuted),
                        ),
                        const SizedBox(height: AppSpacing.xxs + 2),
                        Text(
                          a.title,
                          textAlign: TextAlign.center,
                          style: AppTypography.displaySmall
                              .copyWith(color: AppColors.achText),
                        ),
                        const SizedBox(height: AppSpacing.sm - 2),
                        Text(
                          a.description,
                          textAlign: TextAlign.center,
                          style: AppTypography.titleSmall.copyWith(
                            color: AppColors.phaseTextBody,
                            fontWeight: AppTypography.regular,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                _FadeUp(
                  visible: _phase >= 5,
                  offset: 12,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md + 4,
                      0,
                      AppSpacing.md + 4,
                      AppSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: AppSizing.buttonHeight,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.phaseButton,
                              foregroundColor: AppColors.phaseInk,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.medium + 2,
                                ),
                              ),
                            ),
                            onPressed: _phase >= 5
                                ? () => showAchievementDetail(context, a)
                                : null,
                            child: Text(
                              'View achievement',
                              style: AppTypography.button.copyWith(
                                color: AppColors.phaseInk,
                                fontWeight: AppTypography.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm - 2),
                        SizedBox(
                          height: AppSizing.buttonHeight - 4,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.achText,
                              side: const BorderSide(
                                color: AppColors.hubCardBorderStrong,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AppRadius.medium + 2,
                                ),
                              ),
                            ),
                            onPressed: _phase >= 5 ? _close : null,
                            child: Text(
                              'Continue',
                              style: AppTypography.titleSmall.copyWith(
                                color: AppColors.achText,
                                fontWeight: AppTypography.semiBold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _FadeUp extends StatelessWidget {
  const _FadeUp({
    required this.visible,
    required this.offset,
    required this.child,
  });

  final bool visible;

  /// Logical pixels to rise from.
  final double offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: visible ? 1 : 0),
      duration: AppConstants.animSlow,
      curve: Curves.easeOut,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, (1 - v) * offset),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// One expanding, fading ring behind the medallion.
class _BurstRing extends StatelessWidget {
  const _BurstRing({
    required this.color,
    required this.duration,
    this.delay = Duration.zero,
  });

  final Color color;
  final Duration duration;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    final total = duration + delay;
    final startAt = delay.inMilliseconds / total.inMilliseconds;
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: total,
        builder: (context, raw, _) {
          final t = raw <= startAt ? 0.0 : (raw - startAt) / (1 - startAt);
          final eased = const Cubic(0.2, 0.7, 0.2, 1).transform(t);
          return Opacity(
            opacity: raw <= startAt ? 0 : (0.75 * (1 - eased)).clamp(0.0, 1.0),
            child: Transform.scale(
              scale: 0.85 + (1.9 - 0.85) * eased,
              child: Container(
                width: _AchievementUnlockScreenState._badgeSize,
                height: _AchievementUnlockScreenState._badgeSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.5),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
