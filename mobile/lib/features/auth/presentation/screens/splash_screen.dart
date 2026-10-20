import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Flips to true once the splash intro has played. The router keeps the
/// user on the splash route until then, so the screen is actually seen
/// even when the auth session resolves instantly.
final splashCompleteProvider = StateProvider<bool>((ref) => false);

/// Splash screen (app_design/splash screen.png).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  static const Duration introDuration = Duration(milliseconds: 2200);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: SplashScreen.introDuration,
  )..forward().whenComplete(() {
      if (mounted) ref.read(splashCompleteProvider.notifier).state = true;
    });

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.splashBackground,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                Expanded(
                  child: Image.asset(
                    'assets/images/splash_mascot.png',
                    fit: BoxFit.contain,
                  )
                      .animate()
                      .fadeIn(duration: AppConstants.animSlow)
                      .scale(
                        begin: const Offset(0.96, 0.96),
                        end: const Offset(1, 1),
                        duration: AppConstants.animShimmer,
                        curve: Curves.easeOutCubic,
                      ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.xl,
                  ),
                  child: _buildCopy()
                      .animate()
                      .fadeIn(delay: 200.ms, duration: AppConstants.animSlow),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCopy() {
    final tagline = AppTypography.labelLarge.copyWith(
      color: AppColors.authTextHint,
      letterSpacing: 4,
    );
    return Column(
      children: [
        FittedBox(
          child: Text(
            'GRIT',
            style: AppTypography.displayLarge.copyWith(
              color: AppColors.white,
              fontSize: 52,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          child: Text.rich(
            TextSpan(
              style: tagline,
              children: [
                const TextSpan(text: 'TRAIN · PROGRESS · '),
                TextSpan(
                  text: 'BECOME',
                  style: tagline.copyWith(color: AppColors.authSky),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          'Your training companion.\nSmall in size. Strong in purpose.',
          textAlign: TextAlign.center,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.authTextSoft,
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        SizedBox(
          width: 200,
          child: AnimatedBuilder(
            animation: _progress,
            builder: (context, _) => ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: Curves.easeInOut.transform(_progress.value),
                minHeight: 3,
                backgroundColor: AppColors.authProgressTrack,
                color: AppColors.authSky,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Loading your journey...',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.authTextFaint,
          ),
        ),
      ],
    );
  }
}
