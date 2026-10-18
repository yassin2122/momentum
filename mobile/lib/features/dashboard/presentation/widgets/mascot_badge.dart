import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// How the mascot looks on the Dashboard.
enum MascotMood {
  /// Default: on track.
  happy('assets/mascot/happy.png'),

  /// Rest day.
  sleepy('assets/mascot/sleepy.png'),

  /// Streak at risk: nothing logged today and it's after 6 pm.
  worried('assets/mascot/worried.png');

  const MascotMood(this.asset);

  /// Placeholder art per mood — swap the files to restyle.
  final String asset;

  static const int _riskHour = 18;

  /// Picks the mood from today's plan and the clock.
  static MascotMood forToday({
    required bool isRestDay,
    required bool workedOutToday,
    DateTime? now,
  }) {
    if (isRestDay) return MascotMood.sleepy;
    final hour = (now ?? DateTime.now()).hour;
    if (!workedOutToday && hour >= _riskHour) return MascotMood.worried;
    return MascotMood.happy;
  }
}

/// Small round mascot portrait (~48 px) for the week/streak card.
class MascotBadge extends StatelessWidget {
  const MascotBadge({required this.mood, this.size = 48, super.key});

  final MascotMood mood;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ring = switch (mood) {
      MascotMood.happy => AppColors.accentProgress,
      MascotMood.sleepy => AppColors.hubTextFaint,
      MascotMood.worried => AppColors.accentAction,
    };
    return Semantics(
      label: 'Mascot, ${mood.name}',
      image: true,
      child: Container(
        width: size,
        height: size,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: 1.5),
          color: AppColors.hubBackgroundBottom,
        ),
        child: ClipOval(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Image.asset(
              mood.asset,
              key: ValueKey(mood),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) =>
                  const ColoredBox(color: AppColors.hubHeroGlow),
            ),
          ),
        ),
      ),
    );
  }
}
