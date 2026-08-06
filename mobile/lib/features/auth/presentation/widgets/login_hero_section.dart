import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import 'hero_character_glow.dart';
import 'wordmark_lockup.dart';

/// Cinematic hero zone for the login screen — ~42% of viewport height.
///
/// Layout mirrors the React/Tailwind mockup:
/// - Full-bleed dark gradient canvas behind the mascot
/// - [HeroCharacterGlow] centred in the zone
/// - Bottom fade dissolving into the scaffold background
/// - [WordmarkLockup] anchored to the lower third of the hero
class LoginHeroSection extends StatelessWidget {
  const LoginHeroSection({super.key});

  static const _heroGradient = LinearGradient(
    colors: [
      Color(0xFF1A1F2E),
      Color(0xFF0B0E17),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  @override
  Widget build(BuildContext context) {
    final heroHeight = MediaQuery.sizeOf(context).height * 0.42;

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: _heroGradient)),

          const Align(
            alignment: Alignment(0, -0.15),
            child: HeroCharacterGlow(),
          ),

          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  AppColors.bgGradientBottom,
                  AppColors.bgGradientBottom.withValues(alpha: 0.3),
                  AppColors.transparent,
                ],
                stops: const [0.0, 0.35, 1.0],
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: const Center(child: WordmarkLockup())
                .animate()
                .fadeIn(
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                )
                .slideY(
                  begin: 0.08,
                  end: 0,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                ),
          ),
        ],
      ),
    );
  }
}
