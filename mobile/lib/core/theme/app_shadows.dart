import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Centralized shadow definitions. Per the design system, hard drop
/// shadows are avoided — these are soft, wide, and low-opacity, used
/// sparingly (floating nav bar, sticky CTAs) rather than on every card.
abstract final class AppShadows {
  /// For elements that float above scrolling content — the bottom
  /// navigation bar, sticky action bars.
  static List<BoxShadow> floating = [
    BoxShadow(
      color: AppColors.black.withValues(alpha: 0.35),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  /// Subtle lift for cards that need to visually separate from a busy
  /// background (rare — most cards rely on surface-layer contrast alone,
  /// see DESIGN_SYSTEM.md's Elevation & shadow section).
  static List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.black.withValues(alpha: 0.18),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// Soft outer bloom for the gradient CTA button on auth screens.
  /// Two layers: a warm orange haze on the left and a cool blue haze
  /// on the right, giving the button a sense of being lit from within.
  /// Spread radius is 0 so the glow bleeds outward rather than
  /// expanding the button's footprint.
  static List<BoxShadow> ctaGlow = [
    BoxShadow(
      color: AppColors.ctaGradientStart.withValues(alpha: 0.28),
      blurRadius: 22,
      offset: const Offset(-4, 0),
    ),
    BoxShadow(
      color: AppColors.ctaGradientEnd.withValues(alpha: 0.28),
      blurRadius: 22,
      offset: const Offset(4, 0),
    ),
  ];

  /// Orange bloom behind the centre START orb in the nav bar.
  static const List<BoxShadow> startOrb = [
    BoxShadow(color: AppColors.startOrbGlow, blurRadius: 22),
  ];

  /// Blue bloom for the selected planet, completed nodes and the main
  /// game CTA.
  static List<BoxShadow> gameBlueGlow = [
    BoxShadow(
      color: AppColors.gameBlue.withValues(alpha: 0.6),
      blurRadius: 22,
    ),
  ];

  /// Gold bloom for the current level node and its callout.
  static List<BoxShadow> gameGoldGlow = [
    BoxShadow(
      color: AppColors.gameGoldDeep.withValues(alpha: 0.75),
      blurRadius: 26,
    ),
  ];

  /// Soft halo around a hub avatar (Profile, Captain profile).
  static List<BoxShadow> hubAvatarGlow = [
    BoxShadow(
      color: AppColors.hubRing.withValues(alpha: 0.33),
      blurRadius: 28,
    ),
  ];
}
