import 'package:flutter/material.dart';

/// MOTRA's color token system.
///
/// Every color used anywhere in the app must come from this file — no
/// widget should ever construct a `Color(0x...)` literal directly. This
/// is what lets the entire dark-luxury-glass aesthetic be re-tuned from
/// one place, and what guarantees every glass surface, border, and glow
/// in the app reads as part of the same coherent system rather than
/// several developers' individual guesses at "looks about right."
///
/// Token groups, and why each exists as its own group rather than being
/// folded into a neighboring one:
/// - **Background / Surface / Glass** are three distinct depth layers,
///   not synonyms. Background is the canvas; Surface is an opaque panel
///   sitting on it (rare in this design — most panels are glass);
///   Glass is the translucent, blurred layer that does most of the
///   visual work in a glassmorphic UI and therefore needs its own
///   dedicated opacity steps rather than reusing Surface's solid values.
/// - **Stroke vs. Divider vs. Glass Border** are three different lines
///   with three different jobs: Stroke outlines a panel's own edge;
///   Divider separates content *within* a panel (deliberately lighter
///   than Stroke, since a divider should recede, not frame); Glass
///   Border is a semantic alias layer specifically for
///   `GlassContainer`, kept distinct so glass borders can be retuned
///   independently of generic strokes even though they start out
///   referencing the same values.
/// - **Glow** exists because soft ambient glows (behind primary buttons,
///   around active/selected elements, celebratory moments) need colors
///   that are pre-tuned at specific alpha levels for that purpose —
///   `glowPrimary` is the full-saturation base hue for cases that apply
///   their own opacity/blur at the draw site, while `glowPrimarySoft`/
///   `glowPrimaryStrong` are ready-to-use pre-baked intensities for the
///   common case of animating between elevation states without every
///   call site inventing its own alpha value.
/// - **Container colors** (`successContainer`, etc.) are low-opacity
///   fills for chips/badges/pills/status cards/toasts — kept separate
///   from the semantic colors themselves because a semantic color is
///   almost always used as text/icon/border (needs full saturation to
///   stay legible), while its container is a background (needs low
///   opacity so text placed on it stays readable).
abstract final class AppColors {
  // ==========================================================
  // Neutrals — the only three colors in the app that aren't part of
  // the layered token system above. Exist purely so nothing in the
  // codebase ever writes `Colors.white`/`Colors.black`/
  // `Colors.transparent` directly — these three ARE the neutral
  // palette, referenced by name like everything else.
  // ==========================================================
  static const Color white = Color(0xFFFFFFFF);
  static const Color black = Color(0xFF000000);
  static const Color transparent = Colors.transparent;

  // ==========================================================
  // Background — the base canvas. Slightly cool/blue-black rather
  // than pure neutral black — this is what gives glass surfaces
  // something with a hint of color temperature to pick up and
  // refract, which is what makes glassmorphism read as "glass"
  // instead of just "semi-transparent gray."
  // ==========================================================
  static const Color background = Color(0xFF08090D);
  static const Color backgroundElevated = Color(0xFF0E1015);

  // ==========================================================
  // Surface — opaque panels. Used sparingly in this design (most
  // panels are Glass, below) — reserved for contexts where a fully
  // opaque backing is required, e.g. behind a glass layer that needs
  // something solid underneath it to blur, or for content that must
  // never let background bleed through (readability-critical text
  // blocks, modals over highly dynamic backgrounds).
  // ==========================================================
  static const Color surface = Color(0xFF13151B);
  static const Color surfaceElevated = Color(0xFF1A1D25);

  // ==========================================================
  // Glass — the translucent fill layer for GlassContainer and
  // everything built on it. Three steps (light/medium/strong) instead
  // of one because different elevations of glass need different
  // opacity to still read as "layered" rather than all looking like
  // the same panel repeated — a search bar, a card, and a modal sheet
  // each sit at a different implied height and should look like it.
  // Base color is white so BackdropFilter's blur picks up whatever is
  // genuinely behind it; opacity is what does the work, not hue.
  // ==========================================================
  static const Color glassLight = Color(0x0DFFFFFF); // ~5% white
  static const Color glassMedium = Color(0x14FFFFFF); // ~8% white
  static const Color glassStrong = Color(0x1FFFFFFF); // ~12% white

  // ==========================================================
  // Stroke — hairline borders that outline a panel's own edge. Kept
  // deliberately faint; this design uses borders to suggest an edge
  // catching light, not to draw a hard outline. `strokeStrong` exists
  // for the rare case a border needs to read clearly against a very
  // busy or bright background (e.g. an active/focused state).
  // ==========================================================
  static const Color stroke = Color(0x1FFFFFFF); // ~12% white
  static const Color strokeStrong = Color(0x33FFFFFF); // ~20% white

  // ==========================================================
  // Divider — separates content *within* a panel (a list row from
  // the next, a section from the one below it). Deliberately lighter
  // than `stroke`, not a reuse of it: a divider should recede into
  // the background almost to the point of being felt rather than
  // seen, where a stroke is doing the more assertive job of framing
  // a whole panel's edge.
  // ==========================================================
  static const Color divider = Color(0x0FFFFFFF); // ~6% white

  // ==========================================================
  // Glass border — semantic aliases used specifically by
  // GlassContainer, kept as their own named tokens (rather than
  // widgets reaching for `stroke`/`strokeStrong` directly) so glass
  // borders can be retuned independently later without affecting
  // every other stroke in the app. They intentionally start out
  // referencing the same underlying values as `stroke`/`strokeStrong`
  // — this is a seam for future divergence, not a sign the aliasing
  // is redundant today.
  // ==========================================================
  static const Color glassBorderLight = stroke;
  static const Color glassBorder = stroke;
  static const Color glassBorderStrong = strokeStrong;

  // ==========================================================
  // Primary — the signature brand color. A refined indigo-blue:
  // premium and a little electric (matches the Linear/Nothing-OS-
  // adjacent brief) without tipping into the generic "AI startup
  // purple" a fully saturated violet would read as. Tuned slightly
  // bluer than an earlier draft (was 0xFF7C6CFF) specifically because
  // this hue sits closer on the color wheel to both `secondary`
  // (cyan) and `info` (sky blue) — the palette reads as one coherent
  // cool family with `accent` as the single deliberate warm contrast,
  // rather than primary and secondary pulling toward different,
  // slightly competing color temperatures.
  // ==========================================================
  static const Color primary = Color(0xFF738BFF);
  static const Color primaryMuted = Color(0xFF4A3FB8);
  static const Color primaryBright = Color(0xFF9B8FFF);

  // ==========================================================
  // Secondary — a cool cyan. Exists as a distinct hue (not just a
  // lighter/darker Primary) so the palette has a genuine second color
  // available for things that need to be differentiated from primary
  // actions without competing with them — e.g. a secondary data
  // series on a future chart, or a non-primary active state.
  // ==========================================================
  static const Color secondary = Color(0xFF5EEAD4);
  static const Color secondaryMuted = Color(0xFF2E7D72);

  // ==========================================================
  // Accent — reserved for the app's one "energy" moment: the
  // calisthenics/athletic half of the brief calls for something
  // hotter than the cool primary/secondary/info trio, used sparingly
  // (streak badges, PR celebrations, high-intensity indicators) so it
  // keeps its impact rather than becoming background noise.
  // ==========================================================
  static const Color accent = Color(0xFFFF6B4A);

  // ==========================================================
  // Semantic — success/warning/error/info. Deliberately NOT reused
  // from Primary/Secondary/Accent even where a hue might coincidentally
  // be close — semantic meaning must stay stable and unambiguous
  // regardless of how the brand palette shifts in a future retune.
  // `error` was named `danger` in an earlier draft — renamed for
  // consistency with the more common Flutter/Material semantic-color
  // vocabulary; the underlying color is unchanged.
  // `info` is its own hue (a soft sky blue) rather than reusing
  // `primary`/`secondary`, specifically for coach messages, tips,
  // banners, and mascot hints — content that needs to read as
  // "helpful system voice," not as a brand or interactive-action color.
  // ==========================================================
  static const Color success = Color(0xFF4ADE80);
  static const Color warning = Color(0xFFFBBF24);
  static const Color error = Color(0xFFFF5C6C);
  static const Color info = Color(0xFF5B93F5);

  // ==========================================================
  // Status containers — low-opacity fills for chips, badges, pills,
  // status cards, and toast backgrounds. See the class-level doc for
  // why these are separate from the semantic colors above rather than
  // the same token used at a different opacity ad hoc. Each is the
  // corresponding semantic color at a fixed 20% opacity (alpha 0x33)
  // — kept the same across all four so status containers stay
  // visually consistent with each other regardless of which one is
  // shown.
  // ==========================================================
  static const Color successContainer = Color(0x334ADE80); // success, 20% opacity
  static const Color warningContainer = Color(0x33FBBF24); // warning, 20% opacity
  static const Color errorContainer = Color(0x33FF5C6C); // error, 20% opacity
  static const Color infoContainer = Color(0x335B93F5); // info, 20% opacity

  // ==========================================================
  // Text — four steps. `textDisabled` is distinct from
  // `textSecondary` (not just a lower-opacity version applied ad hoc)
  // so disabled-state text is guaranteed consistent everywhere
  // instead of depending on each widget picking its own opacity.
  // ==========================================================
  static const Color textPrimary = Color(0xFFF5F6FA);
  static const Color textSecondary = Color(0xFFA8ACBD);
  static const Color textTertiary = Color(0xFF6E7180);
  static const Color textDisabled = Color(0xFF484B57);

  // ==========================================================
  // Focus — keyboard focus / accessibility ring, needed for
  // desktop and web targets where hover/focus states matter in a way
  // they don't on a touch-only mobile surface. Defaults to
  // referencing `primary` (a focus ring should read as "the brand
  // color is telling you where you are," not introduce a fifth hue)
  // but is kept as its own named token so it can diverge later
  // without every focus-ring call site needing to change.
  // ==========================================================
  static const Color focus = primary;

  // ==========================================================
  // Overlay — full-screen scrims behind modals/sheets. Kept separate
  // from Background/Surface because a scrim's job (dim what's behind
  // it) is conceptually different from a panel's job (be content),
  // even though both might visually be "dark." Three levels for three
  // different contexts: `overlayLight` for a bottom sheet where the
  // content behind should still read as present, `overlay` (the
  // original default) for a standard dialog, `overlayHeavy` for a
  // fullscreen loading state or a modal stacked above another modal,
  // where the layer beneath should recede almost entirely.
  // ==========================================================
  static const Color overlayLight = Color(0x66050609); // ~40% near-black
  static const Color overlay = Color(0xB3050609); // ~70% near-black
  static const Color overlayHeavy = Color(0xE6050609); // ~90% near-black

  // ==========================================================
  // Glow — ambient soft-light colors. `glowPrimary` now shares its
  // exact base value with `primary` (0xFF738BFF) rather than the
  // earlier, separate 0xFF7C6CFF — a glow behind a primary-colored
  // element should be the same hue as the element itself, not a
  // subtly different one. `glowPrimarySoft`/`glowPrimaryStrong` are
  // pre-baked, ready-to-use intensities derived from that same base,
  // for the common case of animating a glow between elevation states
  // without every call site inventing its own alpha value.
  // `glowAccent` remains the accent-hued counterpart for celebratory
  // moments (PR hit, streak milestone).
  // ==========================================================
  static const Color glowPrimary = Color(0xFF738BFF);
  static const Color glowPrimarySoft = Color(0x1A738BFF); // ~10% glowPrimary
  static const Color glowPrimaryStrong = Color(0x66738BFF); // ~40% glowPrimary
  static const Color glowAccent = Color(0xFFFF6B4A);

  // ==========================================================
  // Interaction states — hover/pressed/selected. `hover` and
  // `pressed` are subtle white-alpha overlays meant to be layered on
  // top of an element's existing fill (the same pattern as
  // `glassLight`/`glassMedium`, but named for what triggers them
  // rather than their visual weight), with `pressed` deliberately
  // stronger than `hover` so the two remain distinguishable when
  // animated between. `selected` references `primary` directly rather
  // than introducing a new hue — a selected state should read as "the
  // brand color is confirming your choice," consistent with how
  // `focus` also defaults to `primary` above.
  // ==========================================================
  static const Color hover = Color(0x12FFFFFF); // ~7% white
  static const Color pressed = Color(0x1FFFFFFF); // ~12% white
  static const Color selected = primary;

  // ==========================================================
  // Navigation — added post-freeze, during the widget-layer MOTRA
  // migration: the floating nav bar needs a background more opaque
  // than the general-purpose `glass*` tokens, since it sits fixed
  // over arbitrary, fast-scrolling content behind it and must stay
  // legible regardless of what's underneath — a general glass panel
  // over static card content can afford to be more transparent than
  // that. This is a genuine gap, not a rename target; the nav bar's
  // selected/unselected icon colors are NOT duplicated here — they
  // map exactly to `primary`/`textTertiary` and reference those
  // directly at the call site instead.
  // ==========================================================
  static const Color navBarBackground = Color(0xF0101218); // ~94% opaque

  // ==========================================================
  // Shadow — pure black used as the base for the soft, wide
  // shadow layers in `app_shadows.dart`. Call sites apply their
  // own alpha via `.withValues(alpha: ...)`; the token itself
  // stays full-opacity so the same source is reusable at every
  // elevation without re-declaring it.
  // ==========================================================
  static const Color shadow = black;

  // ==========================================================
  // Border — explicit border-line color used by the dark theme's
  // InputDecoration (form fields, the floating nav bar). A bit
  // stronger than `stroke` so that an outlined control still
  // reads as framed against a busy or animated background — `stroke`
  // is the ambient glass edge, `border` is the deliberate frame.
  // ==========================================================
  static const Color border = strokeStrong;

  // ==========================================================
  // Nav-bar selection colors — added alongside [navBarBackground]
  // during the floating-nav-bar wiring. Kept as their own tokens
  // (rather than reaching directly for `primary`/`textTertiary`
  // at the call site) because a future "selected vs unselected"
  // tuning pass shouldn't have to touch every internal reference
  // — only this one place.
  // ==========================================================
  static const Color navBarSelected = primary;
  static const Color navBarUnselected = textTertiary;

  // ==========================================================
  // Shimmer — base/highlight pair driving the [LoadingSkeleton]
  // gradient. Cool neutrals rather than primary-tinted so a
  // skeleton reads as "loading chrome" rather than "faded content";
  // re-using `primary` here would make skeletons feel like a
  // soft-but-real UI element instead of a stand-in.
  // ==========================================================
  static const Color shimmerBase = glassLight;
  static const Color shimmerHighlight = stroke;

  // ==========================================================
  // Loading-overlay scrim — full-screen scrim used specifically by
  // [LoadingOverlay]. Aliased from the standard `overlay` so the
  // blocking-spinner case can be retuned independently of dialog
  // and sheet scrims (which need different levels of dimming).
  // ==========================================================
  static const Color overlayScrim = overlay;

  // ==========================================================
  // Accent green — referenced by the dark theme's ColorScheme as
  // the secondary hue. Kept as a separate token (not aliased from
  // `success` or `secondary`) so theme wiring never silently
  // couples itself to a semantic color; if either ever moves,
  // this stays put.
  // ==========================================================
  static const Color accentGreen = secondary;

  // ==========================================================
  // CTA gradient — the warm-orange → violet → blue gradient used
  // exclusively on the GradientPillButton (primary CTA on auth
  // screens). Three stops so the transition reads as one flowing
  // colour rather than two flat halves. The warm stop is the only
  // warm colour on the login screen — its singularity is what makes
  // it the loudest non-hero element on the page.
  // ==========================================================
  static const Color ctaGradientStart = Color(0xFFF2673D); // warm orange
  static const Color ctaGradientMid   = Color(0xFFB85BD1); // magenta-violet bridge
  static const Color ctaGradientEnd   = Color(0xFF3E63F0); // cool blue

  // ==========================================================
  // Hero glow — the radial cool-blue light source behind the mascot.
  // `heroGlow` is the full-saturation base for programmatic use;
  // `heroGlowSoft` is a pre-baked 28%-opacity version for the outer
  // spread of the radial gradient (matching the spec's 25-35% opacity
  // range at the outermost edge of the glow).
  // ==========================================================
  static const Color heroGlow     = Color(0xFF3FA9F5);
  static const Color heroGlowSoft = Color(0x473FA9F5); // ~28% heroGlow

  // ==========================================================
  // Link accent — the blue-violet used for inline text links
  // ("Forgot password?", "Sign up"). Deliberately NOT reusing
  // `primary` (which is indigo-leaning) — this sits closer to the
  // mascot glow hue, so links feel on-brand rather than like
  // generic system-blue.
  // ==========================================================
  static const Color accentLink = Color(0xFF5B7CFA);

  // ==========================================================
  // Background gradient stops — the subtle vertical gradient that
  // runs behind the full login screen. Top is a barely-there
  // cool navy (lifts the hero area), bottom deepens to near-black
  // so the CTA "floats" above it. Distinct from the general
  // `background` token, which is a flat mid-point between them.
  // ==========================================================
  static const Color bgGradientTop    = Color(0xFF0B1220);
  static const Color bgGradientBottom = Color(0xFF050709);

  // ==========================================================
  // Dashboard — new tokens introduced on the dashboard screen.
  // All login tokens carry forward; this group only adds what
  // the denser multi-zone layout requires.
  //
  // Design rule: every card on the dashboard introduces exactly
  // ONE accent hue of its own (streak=orange, rings=red/green/
  // blue, workout=orange/blue gradient, skill=violet, community
  // =red heart) — this is how density is managed without chaos.
  // ==========================================================

  // Card surface & border — slightly more opaque than login
  // inputs so cards hold real content, not just placeholder text.
  static const Color cardSurface = Color(0xCC12161F); // #12161F ~80% opacity
  static const Color cardBorder  = Color(0x12FFFFFF); // ~7% white hairline

  // Streak flame — warm fire gradient, universally legible
  // "streak" signifier; orange→yellow reads as "lit/active."
  static const Color streakFlameStart = Color(0xFFFF7A1A);
  static const Color streakFlameEnd   = Color(0xFFFFB020);

  // Activity rings — directly matches Apple Health/Watch
  // conventions (Move=red/outer, Exercise=green/mid,
  // Stand=cyan/inner). Any deviation would feel wrong to the
  // iOS-native audience this app targets.
  static const Color ringMove     = Color(0xFFFF375F);
  static const Color ringExercise = Color(0xFF33D375);
  static const Color ringStand    = Color(0xFF3FD8FF);
  static const Color ringTrack    = Color(0xFF2A2E38); // unfilled ring track

  // Muscle heatmap — warm orange overlay on cool wireframe.
  // High contrast signals "this is what's working today."
  static const Color heatmapActiveStart  = Color(0xFFFF6A2C);
  static const Color heatmapActiveEnd    = Color(0xFFFFB35C);
  static const Color heatmapWireframe    = Color(0x663A4356); // low opacity

  // Skill / progression — violet is deliberately distinct from
  // the login's blue, reserved exclusively for progression/skill
  // content so it always means "level / rank."
  static const Color skillViolet      = Color(0xFF6C5CE7);
  static const Color skillVioletLight = Color(0xFF8B7CFF);

  // XP bar track — unfilled segment fill.
  static const Color xpTrack = Color(0xFF1C212B);

  // Social heart — universal "like" red.
  static const Color socialHeart = Color(0xFFFF3B5C);
}
