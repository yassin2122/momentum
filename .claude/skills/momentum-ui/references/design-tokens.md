# Momentum design tokens

Generated from the real token files in `mobile/lib/core/theme/`. Every value below is an
actual Dart identifier in those files — don't invent names that aren't here. If a design
calls for something not in this list, check the source file first (it may be newer than
this summary); if it's genuinely missing, ask rather than adding a raw literal.

## Colors — `app_colors.dart` (`AppColors`)

Base brand palette (5 source colors, everything else is derived):
`background` (#191C21), `primary` (#235768), `secondary` (#496575), `textPrimary` (#E8E5DD,
warm off-white), `accent` (#FF683D).

- **Surfaces**: `background` → `backgroundElevated` → `surface` → `surfaceElevated`
  (depth ladder, each a step lighter).
- **Glass**: `glassLight` / `glassMedium` / `glassStrong` (white @ ~5/8/12%); borders:
  `glassBorderLight` / `glassBorder` / `glassBorderStrong`; nav-specific gradient stops
  `glassFillTop` / `glassFillBottom`.
- **Stroke / divider**: `stroke`, `strokeStrong`, `divider`, `border` (= `strokeStrong`).
- **Brand**: `primary` / `primaryMuted` / `primaryBright`; `secondary` / `secondaryMuted`;
  `accent` (use sparingly — streaks, CTAs, celebratory moments only).
- **Semantic** (NOT derived from brand palette — kept conventional on purpose):
  `success`, `warning`, `error`, `info`, each with a `*Container` 20%-opacity variant for
  chip/badge/toast backgrounds.
- **Text**: `textPrimary` → `textSecondary` → `textTertiary` (alias `textMuted`) →
  `textDisabled`.
- **Overlay/scrim**: `overlayLight` / `overlay` / `overlayHeavy`; `overlayScrim` (=`overlay`).
- **Glow**: `glowPrimary` + `glowPrimarySoft` / `glowPrimaryStrong`; `glowAccent`;
  `heroGlow` / `heroGlowSoft`.
- **Interaction**: `hover`, `pressed`, `selected` (= `primary`), `focus` (= `primary`).
- **Nav bar**: `navBarBackground`, `navBarSelected` (= `primary`), `navBarUnselected`
  (= `textTertiary`); `shadowSoft` (List<BoxShadow> — floating nav bar specifically).
- **Misc feature accents**: `ringMove`/`ringExercise`/`ringStand`/`ringTrack` (activity
  rings), `heatmapWireframe`/`heatmapActiveStart`/`heatmapActiveEnd`, `skillViolet`/
  `skillVioletLight` (roadmap accent), `streakFlameStart`/`streakFlameEnd`, `xpTrack`,
  `ctaGradientStart`/`ctaGradientMid`/`ctaGradientEnd`, `accentLink`, `cardSurface`/
  `cardBorder`, `bgGradientTop`/`bgGradientBottom`, `socialHeart` (legacy — social is
  removed; don't use for new work, see CLAUDE.md Known gaps).
- **Neutrals**: `white`, `black`, `transparent` — exist only so nothing else in the codebase
  needs raw `Colors.white`/`Colors.black`.

## Typography — `app_typography.dart` (`AppTypography`)

Every style is built through the private `_style()` helper, which **requires** `height`
(line height) as a named param — no token can forget it. Font family: `fontFamily`
(`'SF Pro Display'`), defined once there.

Scale (large → small variant per group): `displayLarge/Medium/Small` (hero numbers only, not
screen titles), `headlineLarge/Medium/Small` (screen/section titles, one per screen),
`titleLarge/Medium/Small` (repeating card/list/dialog headers), `bodyLarge/Medium/Small`
(reading text), `labelLarge/Medium/Small` (chips/tabs/form labels), `caption` (metadata),
`button` (control labels), `overline` (eyebrow text, meant to be rendered uppercase by the
widget). Default aliases most call sites should reach for: `title` (=`titleMedium`), `body`
(=`bodyMedium`), `headline` (=`headlineMedium`), `small` (=`labelSmall`).

Numeric/tabular figures: `numericStyle` (a tuned stat-number default) and
`numeric(style)` (applies tabular figures to any token — use for timers, rep counts, chart
axis labels, anything where digits must not jitter).

Responsive: `scale(style, screenWidth)` / `responsive(context, style)` — widens type for
tablet/desktop breakpoints (600/1024px); this is separate from OS accessibility text scaling,
which Flutter already applies automatically.

`copyWithWeight` / `copyWithColor` / `copyWithSpacing` extension methods exist on
`TextStyle` for one-off adjustments to an existing token — prefer these over constructing a
new `TextStyle` from scratch.

## Spacing — `app_spacing.dart` (`AppSpacing`)

`xxs`(4) · `xs`(8) · `sm`(12) · `md`(16, most common) · `lg`(24) · `xl`(32) · `xl2`(48) ·
`xl3`(64) · `xl4`(96). Aliases: `screenPadding` (=`md`), `xxl` (=`lg`), `xxxl` (=`xl3`).
Note: the design brief's `2xl/3xl/4xl` names aren't valid Dart identifiers, hence `xl2/3/4`.

## Radius — `app_radius.dart` (`AppRadius`)

`small`(8, aliases `xs`/`sm`) · `medium`(12, alias `md`) · `large`(20, alias `lg`, most
common — standard cards/panels/sheets) · `xl`(28, hero surfaces/modal tops) · `pill`(999,
elongated shapes → capsule) · `circle`(999, equal-dimension shapes → disc — numerically
same as `pill` but a distinct token by intent). Dashboard-specific: `cardCompact`(20),
`cardLarge`(24), `postThumbnail`(16), `bellButton`(16).

## Sizing — `app_sizing.dart` (`AppSizing`)

Icons: `iconSm`(16) · `iconMd`(24) · `iconLg`(32). Controls: `buttonHeight`(52) ·
`inputHeight`(52). Touch target: `minTouchTarget`(44, for icon-only tap targets whose
visible icon is smaller).

## Shadows — `app_shadows.dart` (`AppShadows`)

Hard drop shadows are avoided by design — these are soft, wide, low-opacity, used sparingly:
`floating` (nav bar / sticky bars), `card` (rare — most cards rely on surface-layer contrast
instead), `ctaGlow` (two-tone warm/cool bloom for the auth gradient CTA button).
