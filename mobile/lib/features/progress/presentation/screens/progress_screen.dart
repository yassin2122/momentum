import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../sample/progress_sample_data.dart';

/// UNIVERSE tab root — the three phases as real galaxies side by side in
/// one panorama. Swipe between them; Phase 1 opens the Calisthenics
/// universe. Phase data is sample data (see `progress_sample_data.dart`).
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  final _pages = PageController();
  int _index = 0;

  /// Width / height of the panorama art.
  static const double _bandAspect = 1655 / 590;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    _pages.animateToPage(
      i,
      duration: AppConstants.animSlow,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: AppSpacing.xs),
            const _Wordmark(),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final bandHeight = (w * 3) / _bandAspect;
                  return Stack(
                    children: [
                      // The panorama slides with the pages, so the three
                      // galaxies read as one universe.
                      AnimatedBuilder(
                        animation: _pages,
                        builder: (context, child) {
                          final page = _pages.hasClients &&
                                  _pages.position.hasContentDimensions
                              ? _pages.page ?? 0.0
                              : 0.0;
                          return Positioned(
                            left: -page * w,
                            top: 0,
                            width: w * 3,
                            height: bandHeight,
                            child: child!,
                          );
                        },
                        child: _Panorama(width: w * 3, height: bandHeight),
                      ),
                      PageView.builder(
                        controller: _pages,
                        itemCount: samplePhases.length,
                        onPageChanged: (i) => setState(() => _index = i),
                        itemBuilder: (context, i) => _PhasePage(
                          phase: samplePhases[i],
                          bandHeight: bandHeight,
                          onEnter: () => context.go(AppRoutes.universe),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            _PhaseDots(index: _index, onTap: _goTo),
            const SizedBox(height: AppSpacing.xs),
            Text(
              "Swipe to see what's ahead",
              style:
                  AppTypography.labelMedium.copyWith(color: AppColors.phaseTextFaint),
            ),
            const SizedBox(height: kNavClearance - AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              LucideIcons.orbit,
              size: AppSizing.iconSm + 2,
              color: AppColors.phaseSingularity,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'MOMENTUM',
              style: AppTypography.titleMedium.copyWith(
                color: AppColors.phaseSingularity,
                fontWeight: AppTypography.regular,
                letterSpacing: 6,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'BUILD A STRONGER YOU',
          style: AppTypography.overline.copyWith(
            color: AppColors.phaseTextFaint,
            letterSpacing: 3.5,
          ),
        ),
      ],
    );
  }
}

/// The three-galaxy art with edge fades and the dimmed locked side.
class _Panorama extends StatelessWidget {
  const _Panorama({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final third = width / 3;
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            ProgressArt.universeBand,
            fit: BoxFit.cover,
            semanticLabel: 'Three galaxies in one universe: the orange Origin, '
                'the blue Ascension and the Singularity black hole',
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: AppColors.spaceBase),
          ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  AppColors.black,
                  AppColors.transparent,
                  AppColors.transparent,
                  AppColors.black,
                ],
                stops: [0, 0.16, 0.74, 1],
              ),
            ),
          ),
          // Locked phases sit in shadow.
          Positioned(
            left: third * 0.87,
            top: 0,
            bottom: 0,
            right: 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.black.withValues(alpha: 0),
                    AppColors.black.withValues(alpha: 0.45),
                    AppColors.black.withValues(alpha: 0.52),
                  ],
                  stops: const [0, 0.13, 1],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhasePage extends StatelessWidget {
  const _PhasePage({
    required this.phase,
    required this.bandHeight,
    required this.onEnter,
  });

  final GalaxyPhase phase;
  final double bandHeight;
  final VoidCallback onEnter;

  static const double _lockSize = 40;
  static const double _ctaHeight = 38;

  @override
  Widget build(BuildContext context) {
    final pct = (phase.progress * 100).round();
    return Column(
      children: [
        SizedBox(
          height: bandHeight,
          child: Center(
            child: phase.unlocked
                ? Semantics(
                    button: true,
                    label: 'Enter Phase ${phase.number}, ${phase.title}',
                    child: GestureDetector(
                      onTap: onEnter,
                      behavior: HitTestBehavior.opaque,
                      child: SizedBox.square(dimension: bandHeight * 0.7),
                    ),
                  )
                : Container(
                    width: _lockSize,
                    height: _lockSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.phaseLockFill,
                      border: Border.all(color: AppColors.strokeStrong),
                    ),
                    child: const Icon(
                      LucideIcons.lock,
                      size: AppSizing.iconSm - 2,
                      color: AppColors.phaseSingularity,
                    ),
                  ),
          ),
        ),
        Flexible(
          child: SingleChildScrollView(
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl2),
            child: Column(
              children: [
                Container(
                  width: AppSpacing.lg - 2,
                  height: 1,
                  color: phase.color,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  phase.title,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleLarge.copyWith(
                    color: phase.unlocked
                        ? AppColors.phaseButton
                        : AppColors.phaseTextTag,
                    fontWeight: AppTypography.regular,
                    letterSpacing: 5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  phase.tags,
                  textAlign: TextAlign.center,
                  style: AppTypography.overline.copyWith(
                    color: phase.unlocked
                        ? AppColors.phaseTextTag
                        : AppColors.achTextMuted,
                    fontWeight: AppTypography.regular,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  phase.tagline,
                  textAlign: TextAlign.center,
                  style: AppTypography.labelLarge.copyWith(
                    color: phase.unlocked
                        ? AppColors.phaseTextBody
                        : AppColors.phaseTextTag,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (phase.unlocked)
                  Material(
                    color: AppColors.phaseButton,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      onTap: onEnter,
                      child: SizedBox(
                        height: _ctaHeight,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md + 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Enter phase ${phase.number}',
                                style: AppTypography.labelLarge.copyWith(
                                  color: AppColors.phaseInk,
                                  fontWeight: AppTypography.bold,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                '$pct%',
                                style: AppTypography.numeric(
                                  AppTypography.labelLarge,
                                ).copyWith(color: AppColors.achTextFaint),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    height: _ctaHeight,
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      border: Border.all(color: AppColors.hubCardBorderStrong),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          phase.lockedNote,
                          style: AppTypography.labelMedium
                              .copyWith(color: AppColors.phaseTextTag),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PhaseDots extends StatelessWidget {
  const _PhaseDots({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const double _width = 240;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _width,
      height: AppSpacing.lg,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Opacity(
            opacity: 0.6,
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.phaseOrigin.withValues(alpha: 0),
                    AppColors.phaseOrigin,
                    AppColors.phaseAscension,
                    AppColors.phaseSingularity,
                    AppColors.phaseSingularity.withValues(alpha: 0),
                  ],
                  stops: const [0, 0.25, 0.5, 0.75, 1],
                ),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < samplePhases.length; i++)
                Semantics(
                  button: true,
                  selected: i == index,
                  label: 'Phase ${samplePhases[i].number}, '
                      '${samplePhases[i].title}',
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox.square(
                      dimension: AppSpacing.lg,
                      child: Center(
                        child: AnimatedContainer(
                          duration: AppConstants.pageTransition,
                          curve: Curves.easeOut,
                          width: i == index ? 10 : 6,
                          height: i == index ? 10 : 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: samplePhases[i].color,
                            boxShadow: i == index
                                ? [
                                    BoxShadow(
                                      color: samplePhases[i]
                                          .color
                                          .withValues(alpha: 0.7),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
