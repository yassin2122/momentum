import 'package:flutter/material.dart';

/// App's color token system.
///
/// Base brand palette (the 5 supplied source colors):
///   #191c21  -> background   (darkest, the canvas)
///   #235768  -> primary      (brand teal-blue)
///   #496575  -> secondary    (lighter blue-gray, second cool hue)
///   #E8E5DD  -> textPrimary  (warm off-white)
///   #FF683D  -> accent       (single warm "energy" hue)
///
/// Every other token below is DERIVED from these 5 — either by shifting
/// lightness/opacity, or (for semantic success/warning/error/info) by
/// using conventional, meaning-stable hues that don't bend to the brand
/// palette, since "success = green" etc. must stay legible regardless of
/// how the brand colors get retuned later.
abstract final class AppColors {
  // ==========================================================
  // Neutrals — raw white/black/transparent. Nothing else in the
  // codebase should reference Colors.white/black/transparent directly.
  // ==========================================================
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // ==========================================================
  // Background — the base canvas, straight from the source palette.
  // backgroundElevated is a step lighter, for panels that sit "above"
  // the canvas but still need to be opaque background (not glass).
  // ==========================================================
  static const Color background = Color(0xFF191C21);
  static const Color backgroundElevated = Color(0xFF20242B);

  // ==========================================================
  // Surface — opaque panels. Used where content must never let
  // background bleed through. One step lighter again than
  // backgroundElevated, keeping a consistent depth ladder.
  // ==========================================================
  static const Color surface = Color(0xFF262B33);
  static const Color surfaceElevated = Color(0xFF2E343D);

  // ==========================================================
  // Glass — translucent fill layer. Base is white so BackdropFilter's
  // blur picks up whatever is genuinely behind it; opacity does the
  // work, not hue. Three steps for three implied elevations.
  // ==========================================================
  static const Color glassLight = Color(0x0DFFFFFF); // ~5% white
  static const Color glassMedium = Color(0x14FFFFFF); // ~8% white
  static const Color glassStrong = Color(0x1FFFFFFF); // ~12% white

  // ==========================================================
  // Stroke — hairline panel-edge borders. Faint by default;
  // strokeStrong for edges that need to read against a busy/bright
  // background (e.g. active/focused state).
  // ==========================================================
  static const Color stroke = Color(0x1FFFFFFF); // ~12% white
  static const Color strokeStrong = Color(0x33FFFFFF); // ~20% white

  // ==========================================================
  // Divider — separates content within a panel. Lighter than stroke
  // on purpose: a divider should recede, a stroke should frame.
  // ==========================================================
  static const Color divider = Color(0x0FFFFFFF); // ~6% white

  // ==========================================================
  // Glass border — semantic alias for GlassContainer specifically,
  // kept distinct from stroke/strokeStrong as a seam for future
  // divergence, even though it starts out equal to them.
  // ==========================================================
  static const Color glassBorderLight = stroke;
  static const Color glassBorder = stroke;
  static const Color glassBorderStrong = strokeStrong;

  // ==========================================================
  // Primary — brand teal-blue, straight from the source palette.
  // primaryMuted is a darkened variant (for pressed/muted contexts),
  // primaryBright a lightened one (for highlights/hover glow).
  // ==========================================================
  static const Color primary = Color(0xFF235768);
  static const Color primaryMuted = Color(0xFF163A46);
  static const Color primaryBright = Color(0xFF3D82A0);

  // ==========================================================
  // Secondary — the lighter blue-gray from the source palette, a
  // genuine second hue (not just a lighter/darker primary) for
  // things that need to differ from primary actions without
  // competing with them.
  // ==========================================================
  static const Color secondary = Color(0xFF496575);
  static const Color secondaryMuted = Color(0xFF2E4048);

  // ==========================================================
  // Accent — the one warm "energy" hue, straight from the source
  // palette. Used sparingly (streaks, CTAs, celebratory moments) so
  // it keeps its impact.
  // ==========================================================
  static const Color accent = Color(0xFFFF683D);

  // ==========================================================
  // Semantic — success/warning/error/info. Deliberately NOT derived
  // from the brand palette — semantic meaning must stay conventional
  // and unambiguous (green=success, red=error) no matter how the
  // brand hues shift later.
  // ==========================================================
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFFF5C6C);
  static const Color info = Color(0xFF5B93F5);

  // ==========================================================
  // Status containers — each semantic color at a fixed 20% opacity
  // (alpha 0x33), for chip/badge/pill/toast backgrounds. Kept
  // separate from the semantic colors themselves: text/icon needs
  // full saturation, a background fill needs low opacity to stay
  // readable under text.
  // ==========================================================
  static const Color successContainer = Color(0x334ADE80);
  static const Color warningContainer = Color(0x33FBBF24);
  static const Color errorContainer = Color(0x33FF5C6C);
  static const Color infoContainer = Color(0x335B93F5);

  // ==========================================================
  // Text — 4 steps, walking down from the source cream toward the
  // background. textDisabled is its own token (not an ad hoc opacity)
  // so disabled state stays consistent everywhere.
  // ==========================================================
  static const Color textPrimary = Color(0xFFE8E5DD);
  static const Color textSecondary = Color(0xFFA8A69F);
  static const Color textTertiary = Color(0xFF6E6D68);
  static const Color textDisabled = Color(0xFF48473F);

  // ==========================================================
  // Focus — keyboard focus / accessibility ring. Defaults to
  // primary: a focus ring should read as "the brand color is
  // telling you where you are," not a fifth hue.
  // ==========================================================
  static const Color focus = primary;

  // ==========================================================
  // Overlay — full-screen scrims behind modals/sheets, at three
  // dimming levels for three contexts (bottom sheet / dialog /
  // stacked-modal or loading state).
  // ==========================================================
  static const Color overlayLight = Color(0x66101216); // ~40% near-black
  static const Color overlay = Color(0xB3101216); // ~70% near-black
  static const Color overlayHeavy = Color(0xE6101216); // ~90% near-black

  // ==========================================================
  // Glow — ambient soft-light colors. glowPrimary shares its exact
  // base with primary (a glow should be the same hue as the element
  // it's glowing behind, not a subtly different one). Soft/Strong
  // are pre-baked alpha variants so call sites never invent their
  // own. glowAccent is the accent-hued counterpart for celebratory
  // moments.
  // ==========================================================
  static const Color glowPrimary = Color(0xFF235768);
  static const Color glowPrimarySoft = Color(0x1A235768); // ~10% glowPrimary
  static const Color glowPrimaryStrong = Color(0x66235768); // ~40% glowPrimary
  static const Color glowAccent = Color(0xFFFF683D);

  // ==========================================================
  // Interaction states — hover/pressed white-alpha overlays, layered
  // on top of an element's existing fill. selected references
  // primary directly, consistent with focus above.
  // ==========================================================
  static const Color hover = Color(0x12FFFFFF); // ~7% white
  static const Color pressed = Color(0x1FFFFFFF); // ~12% white
  static const Color selected = primary;

  // ==========================================================
  // Navigation — floating nav bar background, more opaque than the
  // general glass* tokens since it sits fixed over fast-scrolling
  // content and must stay legible regardless of what's underneath.
  // Selected/unselected icon colors intentionally NOT duplicated
  // here — they reference primary/textTertiary directly.
  // ==========================================================
  static const Color navBarBackground = Color(0xF01A1E24); // ~94% opaque
  static const Color navBarSelected = primary;
  static const Color navBarUnselected = textTertiary;

  // ==========================================================
  // Shadow / Border — shadow is pure black, alpha applied at the
  // call site. border is a touch stronger than stroke so outlined
  // controls (form fields, nav bar) still read as framed.
  // ==========================================================
  static const Color shadow = black;
  static const Color border = strokeStrong;

  // ==========================================================
  // Shimmer — base/highlight pair for loading-skeleton gradients.
  // Cool neutrals rather than primary-tinted, so a skeleton reads
  // as "loading chrome," not "faded real content."
  // ==========================================================
  static const Color shimmerBase = glassLight;
  static const Color shimmerHighlight = stroke;

  // ==========================================================
  // Loading-overlay scrim — aliased from overlay so the blocking-
  // spinner case can be retuned independently of dialog/sheet scrims.
  // ==========================================================
  static const Color overlayScrim = overlay;
}