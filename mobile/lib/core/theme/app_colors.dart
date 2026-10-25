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
  // Selected uses primaryBright, not primary: #235768 on the near-black
  // bar is ~2:1 contrast, too faint to read as "active" for icon+label.
  // ==========================================================
  static const Color navBarBackground = Color(0xF01A1E24); // ~94% opaque
  static const Color navBarSelected = primaryBright;
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

  // ==========================================================
  // Background gradient — used on auth screens and anywhere a
  // top-to-bottom dark gradient is needed behind content.
  // ==========================================================
  static const Color bgGradientTop = Color(0xFF12151B);
  static const Color bgGradientBottom = Color(0xFF191C21);

  // ==========================================================
  // Card surface / border — glass-style cards. Surface is slightly
  // lighter than backgroundElevated; border is a faint white stroke.
  // ==========================================================
  static const Color cardSurface = Color(0x14FFFFFF); // ~8% white glass
  static const Color cardBorder = Color(0x1AFFFFFF); // ~10% white stroke

  // ==========================================================
  // Hero glow — the teal/green bloom behind mascot / hero elements.
  // heroGlowSoft is the low-opacity fill; heroGlow is the stronger rim.
  // ==========================================================
  static const Color heroGlow = Color(0xFF3DDDC2);
  static const Color heroGlowSoft = Color(0x1A3DDDC2); // ~10% heroGlow

  // ==========================================================
  // CTA gradient — three-stop gradient for the primary action button.
  // start (warm orange) → mid (coral) → end (teal) gives the energy feel.
  // ==========================================================
  static const Color ctaGradientStart = Color(0xFFFF7A3D);
  static const Color ctaGradientMid = Color(0xFFFF4E6A);
  static const Color ctaGradientEnd = Color(0xFF235768);

  // ==========================================================
  // Accent link — inline hyperlink / action text tint.
  // ==========================================================
  static const Color accentLink = Color(0xFF5B93F5);

  // ==========================================================
  // Activity rings — move / exercise / stand, plus the shared track.
  // ==========================================================
  static const Color ringMove = Color(0xFFFF3B30);
  static const Color ringExercise = Color(0xFF30D158);
  static const Color ringStand = Color(0xFF5AC8FA);
  static const Color ringTrack = Color(0x26FFFFFF); // ~15% white track fill

  // ==========================================================
  // Heatmap — contribution / activity calendar cells.
  // ==========================================================
  static const Color heatmapWireframe = Color(0x26FFFFFF);
  static const Color heatmapActiveStart = Color(0xFF235768);
  static const Color heatmapActiveEnd = Color(0xFF3DDDC2);

  // Anatomy hologram (muscle map): white line art on a near-black body,
  // trained/targeted muscles in electric cyan. Fills are opaque so the
  // art's paint order hides covered shapes.
  static const Color anatomyBody = Color(0xFF05080C);
  static const Color anatomyLine = Color(0xFFFFFFFF);
  static const Color anatomyCyanDeep = Color(0xFF0B5E7A);
  static const Color anatomyCyan = Color(0xFF22D3EE);
  static const Color anatomyCyanBright = Color(0xFFA5F3FC);

  // ==========================================================
  // Skill violet — roadmap skill-tree accent hue.
  // ==========================================================
  static const Color skillViolet = Color(0xFF7C5CBF);
  static const Color skillVioletLight = Color(0x337C5CBF); // ~20% violet

  // ==========================================================
  // Streak flame — hot orange/amber gradient for streak indicators.
  // ==========================================================
  static const Color streakFlameStart = Color(0xFFFF9F0A);
  static const Color streakFlameEnd = Color(0xFFFF3B30);

  // ==========================================================
  // Social heart — like / reaction color on community feed cards.
  // ==========================================================
  static const Color socialHeart = Color(0xFFFF2D55);

  // ==========================================================
  // XP track — the background track behind an XP / progress bar.
  // ==========================================================
  static const Color xpTrack = Color(0x26FFFFFF);

  // ==========================================================
  // Glass fill gradient pair — top/bottom stops for the floating
  // nav bar's glass container gradient (separate from the general
  // glass* tokens so the nav bar can be retuned independently).
  // ==========================================================
  static const Color glassFillTop = Color(0x1AFFFFFF); // ~10% white
  static const Color glassFillBottom = Color(0x0DFFFFFF); // ~5% white

  // ==========================================================
  // Shadow soft list — convenience alias for a single soft shadow
  // used in the floating nav bar; kept here (not AppShadows) to
  // avoid a circular dependency between theme files.
  // ==========================================================
  static const List<BoxShadow> shadowSoft = [
    BoxShadow(
      color: Color(0x40000000), // 25% black
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];

  // ==========================================================
  // Text muted — semantic alias for tertiary text, used in widgets
  // that need a name more descriptive than "textTertiary."
  // ==========================================================
  static const Color textMuted = textTertiary;

  // ==========================================================
  // Auth / onboarding — Splash, Login, Register (app_design/*.png).
  // These screens sit on a near-black canvas behind the lit mascot
  // art, much darker than `background` (#191C21) — on #191C21 the
  // art's own dark edges would show as a visible box. Everything
  // else here is tuned against that darker canvas, so the general
  // tokens (textSecondary, accentLink, ctaGradient*, cardSurface)
  // read too warm / too bright / wrong hue on it.
  // ==========================================================

  /// Splash canvas — pure black, matching the splash art's edges.
  static const Color splashBackground = black;

  /// Login / Register canvas; also the edge stop of the Register radial.
  static const Color authBackground = Color(0xFF02040A);

  /// Centre stop of the Register screen's radial background.
  static const Color authBackgroundGlow = Color(0xFF0A1018);

  /// Sky-blue accent: links, "BECOME", progress fill. Lighter and more
  /// cyan than accentLink (#5B93F5), matching the mascot's scarf.
  static const Color authSky = Color(0xFF4FB3E8);

  /// Second line of the two-line auth titles (horizontal gradient).
  static const Color authTitleGradientStart = Color(0xFF6FB6E8);
  static const Color authTitleGradientEnd = Color(0xFF3F86C4);

  /// Auth CTA button — cool steel-blue, unlike the warm ctaGradient*.
  static const Color authCtaStart = Color(0xFF5A8FBD);
  static const Color authCtaMid = Color(0xFF3B6488);
  static const Color authCtaEnd = Color(0xFF1E3448);

  /// Login form card — opaque, since translucent cardSurface would
  /// let the mascot art bleed through.
  static const Color authCardTop = Color(0xFF0A0E14);
  static const Color authCardBottom = Color(0xFF06090D);
  static const Color authCardBorder = Color(0x17FFFFFF); // ~9% white

  /// Text inputs and social buttons on the auth screens.
  static const Color authInputFill = Color(0xFF070A0F);
  static const Color authInputBorder = Color(0x1CFFFFFF); // ~11% white

  /// Register's circular back button.
  static const Color authBackButton = Color(0xFF11151B);

  /// Splash loading-bar track (opaque; xpTrack is translucent white).
  static const Color authProgressTrack = Color(0xFF1A1D21);

  /// Neutral greys for auth copy — cool and unwarmed, unlike the
  /// textSecondary/textTertiary ramp derived from warm #E8E5DD.
  static const Color authTextLabel = Color(0xFFC9CBCE); // field labels
  static const Color authTextSubtitle = Color(0xFFB3B5B8); // title subtitles
  static const Color authTextHint = Color(0xFFA3A6AA); // tagline, helper text
  static const Color authTextSoft = Color(0xFF9B9DA0); // splash body copy
  static const Color authTextFaint = Color(0xFF85878A); // "Loading…" caption

  // ==========================================================
  // Hub — Dashboard, Coach hub, Captain screens, Profile, Skill.
  // Same near-black canvas family as the auth screens, with a deep
  // blue lift at the top and dark slate cards (design/canvas: ref/*).
  // ==========================================================
  static const Color hubBackgroundTop = Color(0xFF071624);
  static const Color hubBackgroundBottom = Color(0xFF01050A);
  static const Color hubCardTop = Color(0xFF0B1218);
  static const Color hubCardBottom = Color(0xFF04080C);
  static const Color hubCardBorder = Color(0x14FFFFFF); // ~8% white
  static const Color hubCardBorderStrong = Color(0x26FFFFFF); // ~15% white
  static const Color hubHeroGlow = Color(0xFF0E3550);
  static const Color hubHeroMid = Color(0xFF08141D);
  static const Color hubHeroEdge = Color(0xFF060B10);
  static const Color hubIconButton = Color(0xFF0A1015);
  static const Color hubEyebrow = authSky;
  static const Color hubTextBright = Color(0xFFF2F2F2);
  static const Color hubTextNumber = Color(0xFFF2EFE8);
  static const Color hubTextBody = Color(0xFFC2C4C7);
  static const Color hubTextMuted = authTextHint;
  // Floor for any secondary/caption text on the dark hub canvas.
  static const Color hubTextFaint = Color(0xFF9AA4B2);
  static const Color hubTrack = Color(0xFF0E151B);
  static const Color hubBarStart = Color(0xFF1C5A80);
  static const Color hubBarEnd = Color(0xFF3C95CC);
  static const Color hubDayDone = Color(0xFF154A6B);
  static const Color hubDayEmpty = Color(0xFF1F2830);
  static const Color hubRing = Color(0xFF2678AD);
  static const Color hubAvatarRing = Color(0xFF1F6FA0);
  static const Color hubChipText = Color(0xFFCFE8F7);
  static const Color hubSkyLight = Color(0xFF8FD0F2);
  static const Color hubCtaStart = Color(0xFF1F5C82);
  static const Color hubCtaEnd = Color(0xFF0B2A3E);
  static const Color hubCtaKnob = Color(0xFF06192A);
  static const Color hubNote = Color(0xFF0A1520);
  static const Color hubShareOnFill = Color(0x1A4ADE80); // ~10% success
  static const Color hubShareOnText = Color(0xFF8EE6AD);
  static const Color hubShareOffFill = Color(0x0DFFFFFF); // ~5% white
  static const Color hubWaitFill = Color(0x26FBBF24); // ~15% warning
  static const Color hubWaitText = Color(0xFFFCD77A);
  static const Color hubDanger = Color(0xFFFF7A85);
  static const Color hubStreak = Color(0xFFF4501A);

  // Semantic accents for the hub. Progress = blue (rings, bars, links);
  // action = the solid orange of the centre START button (primary CTAs).
  static const Color accentProgress = authSky;
  static const Color accentAction = Color(0xFFFF5A1F);
  static const Color accentActionPressed = Color(0xFFE04A12);

  /// Ring / bar track a step brighter than hubTrack, for contrast.
  static const Color hubTrackStrong = Color(0xFF1C2833);

  /// Rest-day dot on the week strip.
  static const Color hubRestDay = Color(0xFF141C24);

  // Grit nav bar with the orange START orb.
  static const Color hubNavTop = Color(0xFF080D12);
  static const Color hubNavBottom = Color(0xFF03070A);
  static const Color hubNavBorder = Color(0x17FFFFFF); // ~9% white
  // Glass nav bar: a frosted pill, icon-only, with the selected tab in a
  // filled blue circle.
  /// Light frost over a slight ink underlay, so icons hold up on bright art.
  static const Color navGlassTop = Color(0x6619222C); // ~40% slate
  static const Color navGlassBottom = Color(0x800B1118); // ~50% ink
  /// Hairline rim and the brighter top-edge highlight.
  static const Color navGlassRim = Color(0x2EFFFFFF); // ~18% white
  static const Color navGlassHighlight = Color(0x40FFFFFF); // ~25% white
  /// Selected-tab circle: light-to-deep blue, with a soft blue bloom.
  static const Color navSelectedTop = Color(0xFF5CC2F2);
  static const Color navSelectedBottom = Color(0xFF1F6FA0);
  static const Color navSelectedGlow = Color(0x734FB3E8); // ~45% sky
  /// Unselected tab icons.
  static const Color navIcon = Color(0xFF8FB7D6);
  static const Color startOrbLight = Color(0xFFFFC46B);
  static const Color startOrbMid = accentAction;
  static const Color startOrbDeep = Color(0xFFF03C10);
  static const Color startOrbGlow = Color(0x8CFF5A1F); // ~55% orange
  static const Color startOrbCore = Color(0xFF3A0F05);

  // Skill certification tiers (Complete / Master / Legendary).
  static const Color tierComplete = hubSkyLight;
  static const Color tierCompleteFill = Color(0xFF071A2A);
  static const Color tierMaster = Color(0xFFC9B8F2);
  static const Color tierMasterFillTop = Color(0xFF261A40);
  static const Color tierMasterFillBottom = Color(0xFF100B1B);
  static const Color tierMasterBorder = Color(0x887C5CBF);
  static const Color tierLegendary = Color(0xFFFFA36B);
  static const Color tierLegendaryFillTop = Color(0xFF3A1A08);
  static const Color tierLegendaryFillBottom = Color(0xFF160904);
  static const Color tierLegendaryBorder = Color(0x66F4501A);
  static const Color tierLockedFill = Color(0xFF070B0F);

  // ==========================================================
  // Game — Phases, Calisthenics universe, planet level path.
  // Deep space canvas with nebula washes, HUD capsules, blue
  // completed nodes, gold "current" node and violet elite trial.
  // ==========================================================
  static const Color spaceBase = Color(0xFF03040C);
  static const Color nebulaViolet = Color(0xFF2A1660);
  static const Color nebulaTeal = Color(0xFF0B3A5C);
  static const Color nebulaBlue = Color(0xFF0D2A6B);
  static const Color nebulaGreen = Color(0xFF0F4A3A);
  static const Color nebulaIndigo = Color(0xFF1B2A6B);
  static const Color nebulaDeep = Color(0xFF0D3A7A);
  static const Color hudFill = Color(0xC7080C1C); // ~78% deep navy
  static const Color hudBorder = Color(0x1FFFFFFF); // ~12% white
  static const Color gameTextSubtle = Color(0xFF9FB4D6);
  static const Color gameTextBody = Color(0xFFB9C6DC);
  static const Color gameBlue = Color(0xFF3A8DFF);
  static const Color gameBlueDeep = Color(0xFF2A6FD6);
  static const Color gameBlueLight = Color(0xFF6CC4FF);
  static const Color gameBluePale = Color(0xFFBFE6FF);
  static const Color gamePathDash = Color(0xFF7CC8FF);
  static const Color gameNodeMid = Color(0xFF0B1F4A);
  static const Color gameNodeEdge = Color(0xFF050B1C);
  static const Color gamePanelTop = Color(0xEB0E1A3A); // ~92%
  static const Color gamePanelBottom = Color(0xF2060A18); // ~95%
  static const Color gameLabelFill = Color(0xD1060A18); // ~82%
  static const Color gameGold = Color(0xFFFFC83D);
  static const Color gameGoldLight = Color(0xFFFFD36B);
  static const Color gameGoldPale = Color(0xFFFFF1BF);
  static const Color gameGoldDeep = Color(0xFFF08A1A);
  static const Color gameGoldDark = Color(0xFF7A3A05);
  static const Color gameGoldInk = Color(0xFF2A1400);
  static const Color gameElite = Color(0xFFA48BE0);
  static const Color gameEliteLight = Color(0xFFD9CBFF);
  static const Color gameEliteText = Color(0xFFB9A8E8);
  static const Color gameEliteDeep = Color(0xFF2B1D55);
  static const Color gameLockedTop = Color(0xFF3A4250);
  static const Color gameLockedBottom = Color(0xFF151A22);
  static const Color gameLockedBorder = Color(0xFF556070);
  static const Color gameLockedText = Color(0xFF9AA4B2);
  static const Color gameStar = Color(0xFFFFFFFF);

  // Phases — the three galaxies (Origin / Ascension / Singularity).
  static const Color phaseOrigin = Color(0xFFFF9A3C);
  static const Color phaseAscension = Color(0xFF7A8CFF);
  static const Color phaseSingularity = Color(0xFFE8E8EA);
  static const Color phaseInk = Color(0xFF0B0B0D);
  static const Color phaseButton = Color(0xFFECECEE);
  static const Color phaseTextTag = Color(0xFFB4B7BD);
  static const Color phaseTextBody = Color(0xFFC9CBD0);
  static const Color phaseTextFaint = Color(0xFF7D8088);
  static const Color phaseLockFill = Color(0xB308080E); // ~70%

  // ==========================================================
  // Achievements — neutral graphite sheet the medallions sit on.
  // Medallion materials live in [AchievementPalette] below.
  // ==========================================================
  static const Color achBackgroundTop = Color(0xFF1A1B20);
  static const Color achBackground = Color(0xFF0B0B0D);
  static const Color achSurface = Color(0xFF16171A);
  static const Color achSurfaceLow = Color(0xFF111214);
  static const Color achSheetTop = Color(0xFF17181B);
  static const Color achSheet = Color(0xFF141518);
  static const Color achSheetInset = Color(0xFF0F1012);
  static const Color achTrack = Color(0xFF24262B);
  static const Color achHandle = Color(0xFF3A3C42);
  static const Color achText = Color(0xFFECECEE);
  static const Color achTextMuted = Color(0xFF9A9DA4);
  static const Color achTextFaint = Color(0xFF6F727A);
  static const Color achNewPill = Color(0xFFE8E5DD);
  static const Color achScrim = Color(0x99050507); // ~60%

  // ==========================================================
  // Analytics — dark graphite, brushed-silver details and the Grit
  // teal (heroGlow). Each feature screen adds one restrained accent:
  // distribution = teal, hologram = anatomyCyan, body = steel,
  // recovery = dusk blue. Caution is a muted amber, never alarm red.
  // ==========================================================
  static const Color analyticsBgTop = Color(0xFF16181C);
  static const Color analyticsBgBottom = Color(0xFF060708);
  static const Color analyticsPanelTop = Color(0xFF1A1D22);
  static const Color analyticsPanelBottom = Color(0xFF0D0F12);
  static const Color analyticsPanelBorder = Color(0x1AFFFFFF); // ~10% white
  static const Color analyticsHairline = Color(0x12FFFFFF); // ~7% white
  static const Color analyticsTrack = Color(0xFF1D2127);
  static const Color analyticsScrim = Color(0xCC050607); // ~80%

  /// Brushed-silver ramp for metallic type, edges and ticks.
  static const Color silverBright = Color(0xFFF3F4F6);
  static const Color silver = Color(0xFFBAC0C8);
  static const Color silverDim = Color(0xFF80868F);
  static const Color silverDeep = Color(0xFF3B4048);
  static const Color silverEdge = Color(0x40FFFFFF); // ~25% white

  static const Color analyticsTeal = heroGlow;
  static const Color analyticsTealMid = Color(0xFF2A9E8C);
  static const Color analyticsTealDeep = Color(0xFF145247);
  static const Color analyticsTealSoft = Color(0x263DDDC2); // ~15% teal
  static const Color analyticsTealFaint = Color(0x0F3DDDC2); // ~6% teal

  /// Ordered teal shades for chart series (distribution segments).
  static const List<Color> analyticsSeries = [
    analyticsTeal,
    analyticsTealMid,
    Color(0xFF1F7A6C),
    analyticsTealDeep,
    Color(0xFF8FD8CB),
    Color(0xFF5DBFB0),
  ];

  static const Color analyticsSteel = Color(0xFFD8DEE6);
  static const Color analyticsSteelSoft = Color(0x1FD8DEE6); // ~12%

  static const Color analyticsDusk = Color(0xFF9FB2FF);
  static const Color analyticsDuskDeep = Color(0xFF34407A);
  static const Color analyticsDuskSoft = Color(0x229FB2FF); // ~13%

  static const Color analyticsCaution = Color(0xFFF0C46E);
  static const Color analyticsCautionSoft = Color(0x1FF0C46E); // ~12%
  static const Color analyticsPositive = Color(0xFF7FE0B0);
  static const Color analyticsPositiveSoft = Color(0x1F7FE0B0); // ~12%
}

/// One medallion material for a rarity tier. Every colour an achievement
/// badge paints with — frame, bevelled edge, inner plate, glow, ring and
/// glyph — so a badge never reaches for a raw hex value.
final class RarityPalette {
  const RarityPalette({
    required this.frameTop,
    required this.frameMid,
    required this.frameBottom,
    required this.edgeLight,
    required this.edgeMid,
    required this.edgeDark,
    required this.innerTop,
    required this.innerBottom,
    required this.innerEdge,
    required this.glyph,
    required this.glow,
    required this.ring,
    required this.accent,
    required this.label,
    this.glowOpacity = 0,
    this.ringOpacity = 0,
    this.outerRingOpacity = 0,
    this.tickOpacity = 0,
    this.rimOpacity = 0,
    this.sweepOpacity = 0,
    this.edgeWidth = 1.4,
  });

  final Color frameTop;
  final Color frameMid;
  final Color frameBottom;
  final Color edgeLight;
  final Color edgeMid;
  final Color edgeDark;
  final Color innerTop;
  final Color innerBottom;
  final Color innerEdge;
  final Color glyph;
  final Color glow;
  final Color ring;

  /// Progress-ring and metadata colour for this tier.
  final Color accent;

  /// Text colour for the tier name on the dark sheet.
  final Color label;
  final double glowOpacity;
  final double ringOpacity;
  final double outerRingOpacity;
  final double tickOpacity;
  final double rimOpacity;
  final double sweepOpacity;
  final double edgeWidth;
}

/// Medallion materials, one per rarity (design/canvas: ach/BadgeSystem).
abstract final class AchievementPalette {
  static const RarityPalette common = RarityPalette(
    frameTop: Color(0xFF34373D),
    frameMid: Color(0xFF24262B),
    frameBottom: Color(0xFF18191D),
    edgeLight: Color(0xFF4A4D54),
    edgeMid: Color(0xFF3A3D43),
    edgeDark: Color(0xFF2C2E33),
    innerTop: Color(0xFF1F2125),
    innerBottom: Color(0xFF141518),
    innerEdge: Color(0xFF2F3238),
    glyph: Color(0xFFC9CCD2),
    glow: Color(0xFF000000),
    ring: Color(0xFF000000),
    accent: Color(0xFFA7ABB3),
    label: Color(0xFFA7ABB3),
    edgeWidth: 1.5,
  );

  static const RarityPalette uncommon = RarityPalette(
    frameTop: Color(0xFFB6BDC6),
    frameMid: Color(0xFF5F666F),
    frameBottom: Color(0xFF2F343A),
    edgeLight: Color(0xFFEEF4FA),
    edgeMid: Color(0xFF9AA3AD),
    edgeDark: Color(0xFF5A616A),
    innerTop: Color(0xFF23282E),
    innerBottom: Color(0xFF14171B),
    innerEdge: Color(0xFF4A525B),
    glyph: Color(0xFFE9EDF2),
    glow: Color(0xFFC9D8EA),
    ring: Color(0xFF000000),
    accent: Color(0xFFC9D3DE),
    label: Color(0xFFC9D3DE),
    glowOpacity: 0.08,
    rimOpacity: 0.6,
  );

  static const RarityPalette rare = RarityPalette(
    frameTop: Color(0xFF808D9B),
    frameMid: Color(0xFF3E4955),
    frameBottom: Color(0xFF1F262E),
    edgeLight: Color(0xFFC3D6E8),
    edgeMid: Color(0xFF6F8396),
    edgeDark: Color(0xFF3A4653),
    innerTop: Color(0xFF255C8C),
    innerBottom: Color(0xFF0D2742),
    innerEdge: Color(0xFF5384AE),
    glyph: Color(0xFFEEF5FB),
    glow: Color(0xFF4F8FCF),
    ring: Color(0xFFA9C9E6),
    accent: Color(0xFF6FA8DC),
    label: Color(0xFF8CBBE6),
    glowOpacity: 0.22,
    ringOpacity: 0.75,
    rimOpacity: 0.45,
  );

  static const RarityPalette epic = RarityPalette(
    frameTop: Color(0xFF6C6281),
    frameMid: Color(0xFF3A3349),
    frameBottom: Color(0xFF1E1A27),
    edgeLight: Color(0xFFE2D5FD),
    edgeMid: Color(0xFF8A74B8),
    edgeDark: Color(0xFF4A3D63),
    innerTop: Color(0xFF5D4196),
    innerBottom: Color(0xFF24163D),
    innerEdge: Color(0xFF9077C9),
    glyph: Color(0xFFF4EEFF),
    glow: Color(0xFF9F80E6),
    ring: Color(0xFFCDB6F5),
    accent: Color(0xFFA98BE6),
    label: Color(0xFFBDA4EE),
    glowOpacity: 0.4,
    ringOpacity: 0.8,
    outerRingOpacity: 0.55,
    rimOpacity: 0.45,
  );

  static const RarityPalette legendary = RarityPalette(
    frameTop: Color(0xFFF3D896),
    frameMid: Color(0xFFB07D32),
    frameBottom: Color(0xFF5C3C10),
    edgeLight: Color(0xFFFFF3CF),
    edgeMid: Color(0xFFD9AC5A),
    edgeDark: Color(0xFF7A5218),
    innerTop: Color(0xFF3A2B13),
    innerBottom: Color(0xFF150E06),
    innerEdge: Color(0xFFC9A052),
    glyph: Color(0xFFF7DF9D),
    glow: Color(0xFFE3AC4D),
    ring: Color(0xFFD8B066),
    accent: Color(0xFFE0B866),
    label: Color(0xFFE9C983),
    glowOpacity: 0.28,
    ringOpacity: 0.7,
    tickOpacity: 0.75,
    rimOpacity: 0.65,
    sweepOpacity: 0.5,
    edgeWidth: 1.5,
  );

  static const RarityPalette mythic = RarityPalette(
    frameTop: Color(0xFF24242E),
    frameMid: Color(0xFF0E0E14),
    frameBottom: Color(0xFF050508),
    edgeLight: Color(0xFFDFE6F0),
    edgeMid: Color(0xFFC4B4EA),
    edgeDark: Color(0xFFA3D8D0),
    innerTop: Color(0xFF13131B),
    innerBottom: Color(0xFF050507),
    innerEdge: Color(0xFF3C3F4C),
    glyph: Color(0xFFF2F4F8),
    glow: Color(0xFFA9B8DE),
    ring: Color(0xFFE1E6EE),
    accent: Color(0xFFD8DDE6),
    label: Color(0xFFDFE4EC),
    glowOpacity: 0.2,
    ringOpacity: 0.6,
    outerRingOpacity: 0.35,
    rimOpacity: 0.5,
    sweepOpacity: 0.32,
    edgeWidth: 2.2,
  );

  /// Shared material for locked and in-progress medallions.
  static const RarityPalette locked = RarityPalette(
    frameTop: Color(0xFF18191C),
    frameMid: Color(0xFF121315),
    frameBottom: Color(0xFF0D0E10),
    edgeLight: Color(0xFF2F3238),
    edgeMid: Color(0xFF2A2D33),
    edgeDark: Color(0xFF25272C),
    innerTop: Color(0xFF101113),
    innerBottom: Color(0xFF0B0C0E),
    innerEdge: Color(0xFF202227),
    glyph: Color(0xFF767A82),
    glow: Color(0xFF000000),
    ring: Color(0xFF000000),
    accent: Color(0xFF6F727A),
    label: Color(0xFF6F727A),
    edgeWidth: 1.5,
  );

  /// Track behind the progress arc on an in-progress medallion.
  static const Color progressTrack = Color(0xFF2A2D33);
}
