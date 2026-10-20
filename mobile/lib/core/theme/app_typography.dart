import 'package:flutter/material.dart';
import 'app_colors.dart';

/// GRIT's typography token system.
///
/// Every `TextStyle` used anywhere in the app must come from this file —
/// no widget should ever construct `TextStyle(...)` directly. This is
/// what keeps the app's type feeling like one coherent, HIG/M3-inspired
/// scale instead of every screen inventing its own sizes, weights, and
/// spacing as it goes.
///
/// Structure: every public token is a `static final TextStyle` built
/// from the private [_style] helper, which is the single place font
/// family, and the "every style must define height" rule, are actually
/// enforced — no individual token can forget to set line height, because
/// [_style] requires it as a named parameter with no default.
abstract final class AppTypography {
  // ==========================================================
  // Font family — the one and only place "SF Pro Display" (or
  // whatever GRIT's brand typeface ends up being) is written. If the
  // typeface ever changes, this is the only line that needs to.
  // ==========================================================
  static const String fontFamily = 'SF Pro Display';

  // ==========================================================
  // Font weights — named semantically rather than every call site
  // writing `FontWeight.w600` and needing to remember what weight
  // "600" is supposed to mean in this design system.
  // ==========================================================
  static const FontWeight light = FontWeight.w300;
  static const FontWeight regular = FontWeight.w400;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semiBold = FontWeight.w600;
  static const FontWeight bold = FontWeight.w700;
  static const FontWeight extraBold = FontWeight.w800;

  /// Shared constructor for every token below. Centralizing this is
  /// what makes "every style must define height" and "always reference
  /// [fontFamily]" structural guarantees rather than conventions someone
  /// has to remember to follow when adding a new style.
  static TextStyle _style({
    required double fontSize,
    required FontWeight weight,
    required double letterSpacing,
    required double height,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      height: height,
      color: color,
    );
  }

  // ==========================================================
  // Display — the largest type on screen, and the rarest. Used for
  // the one or two hero numbers/moments a screen gets: a Dashboard
  // stat callout, a completed-workout summary's headline number, a
  // PR celebration. Not for screen titles — see Headline for that.
  // Negative letter spacing tightens large type, which at this size
  // would otherwise look loose and unrefined; the tightening scales
  // up with size because the effect of a fixed spacing value is more
  // pronounced at larger sizes.
  // ==========================================================
  static final TextStyle displayLarge = _style(
    fontSize: 40, weight: extraBold, letterSpacing: -0.6, height: 1.1,
  );
  static final TextStyle displayMedium = _style(
    fontSize: 34, weight: bold, letterSpacing: -0.5, height: 1.12,
  );
  static final TextStyle displaySmall = _style(
    fontSize: 28, weight: bold, letterSpacing: -0.4, height: 1.15,
  );

  // ==========================================================
  // Headline — screen and section titles. This is what a user reads
  // to orient themselves ("what am I looking at right now") — one per
  // screen or major section, not a repeating pattern down a list.
  // ==========================================================
  static final TextStyle headlineLarge = _style(
    fontSize: 26, weight: bold, letterSpacing: -0.4, height: 1.2,
  );
  static final TextStyle headlineMedium = _style(
    fontSize: 22, weight: semiBold, letterSpacing: -0.3, height: 1.22,
  );
  static final TextStyle headlineSmall = _style(
    fontSize: 20, weight: semiBold, letterSpacing: -0.2, height: 1.25,
  );

  // ==========================================================
  // Title — card headers, list section headers, dialog titles: the
  // repeating "what is this group of content" label that appears many
  // times per screen, unlike Headline which appears once. Given a
  // small negative tracking rather than zero — a deliberate middle
  // ground between Headline's tightened feel and Body's neutral one,
  // so Title doesn't read as visually loose sitting directly under a
  // Headline.
  // ==========================================================
  static final TextStyle titleLarge = _style(
    fontSize: 18, weight: semiBold, letterSpacing: -0.1, height: 1.3,
  );
  static final TextStyle titleMedium = _style(
    fontSize: 16, weight: semiBold, letterSpacing: -0.1, height: 1.3,
  );
  static final TextStyle titleSmall = _style(
    fontSize: 15, weight: medium, letterSpacing: -0.1, height: 1.3,
  );

  // ==========================================================
  // Body — the actual reading text of the app: descriptions,
  // instructions, form input, paragraph content. Neutral (zero)
  // letter spacing, per the brief — body text is read continuously,
  // not glanced at, and tracking adjustments that help a short label
  // stand out actively hurt continuous readability at this size.
  // Generous line height (1.4–1.5) for the same reason.
  // ==========================================================
  static final TextStyle bodyLarge = _style(
    fontSize: 16, weight: regular, letterSpacing: 0, height: 1.5,
  );
  static final TextStyle bodyMedium = _style(
    fontSize: 14, weight: regular, letterSpacing: 0, height: 1.45,
    color: AppColors.textSecondary,
  );
  static final TextStyle bodySmall = _style(
    fontSize: 12, weight: regular, letterSpacing: 0, height: 1.4,
    color: AppColors.textSecondary,
  );

  // ==========================================================
  // Label — UI chrome text: chip labels, tab labels, form field
  // labels, badge text. Positive letter spacing (per the brief) is
  // what makes small, often-uppercase-adjacent UI labels feel
  // deliberately designed rather than just "body text, but smaller."
  // ==========================================================
  static final TextStyle labelLarge = _style(
    fontSize: 14, weight: medium, letterSpacing: 0.2, height: 1.3,
    color: AppColors.textSecondary,
  );
  static final TextStyle labelMedium = _style(
    fontSize: 12, weight: medium, letterSpacing: 0.3, height: 1.3,
    color: AppColors.textSecondary,
  );
  static final TextStyle labelSmall = _style(
    fontSize: 11, weight: medium, letterSpacing: 0.4, height: 1.3,
    color: AppColors.textTertiary,
  );

  // ==========================================================
  // Caption — metadata attached to other content: a timestamp under
  // a workout entry, a muscle/equipment tag under an exercise name.
  // Always secondary to whatever it's captioning, never the primary
  // thing being read on screen.
  // ==========================================================
  static final TextStyle caption = _style(
    fontSize: 12, weight: regular, letterSpacing: 0.2, height: 1.35,
    color: AppColors.textTertiary,
  );

  // ==========================================================
  // Button — label text inside interactive controls specifically.
  // Kept distinct from Label/Title even at an overlapping size,
  // because a button's text has a different job (state a single,
  // committed action) and needs its own weight/spacing tuning
  // independent of what a Title or Label token happens to look like.
  // ==========================================================
  static final TextStyle button = _style(
    fontSize: 16, weight: semiBold, letterSpacing: 0.3, height: 1.2,
  );

  // ==========================================================
  // Overline — the smallest, widest-tracked style: section eyebrows
  // ("WORKOUT SUMMARY" above a headline), category tags meant to be
  // rendered uppercase by the widget using them. The widest positive
  // spacing in the whole scale on purpose — an overline's entire job
  // is to look like considered, wide-tracked micro-typography, not
  // to be readable at a glance the way Body/Label are.
  // ==========================================================
  static final TextStyle overline = _style(
    fontSize: 11, weight: semiBold, letterSpacing: 1.2, height: 1.4,
    color: AppColors.textTertiary,
  );

  // ==========================================================
  // Default aliases — the three "what do I reach for by default"
  // tokens (Title, Body, Headline) used by the majority of call sites.
  // They resolve to the medium variants above, which are the values
  // most screens actually want; explicit Large/Small suffixes exist
  // for the cases that genuinely need to opt up or down.
  // ==========================================================
  static final TextStyle title = titleMedium;
  static final TextStyle body = bodyMedium;
  static final TextStyle headline = headlineMedium;
  // Convenience alias used by nav-bar and micro-label widgets.
  static final TextStyle small = labelSmall;

  // ==========================================================
  // Numeric — tabular-figure styles for anything where digits sit in
  // a grid or change rapidly: workout timers, calorie counts, weight/
  // rep entry, chart axis labels, PR values. Proportional (default)
  // figures have per-digit widths that differ ("1" is narrower than
  // "8"), which makes a changing number visibly jitter horizontally
  // as it updates — unacceptable for a live rest timer or a set of
  // stacked weight values that should align into a column. Tabular
  // figures give every digit the same advance width, eliminating that
  // jitter and letting numbers align like a spreadsheet.
  //
  // `numericStyle` is a sensible default (tuned like a prominent stat
  // number); `numeric()` applies the same tabular-figure feature to
  // ANY existing token, since numbers legitimately appear at many
  // different sizes across the app (a big timer is Display-sized, a
  // rep count next to a set row is Body-sized) and forcing everything
  // numeric through one fixed size would be wrong.
  // ==========================================================
  static final TextStyle numericStyle = _style(
    fontSize: 32, weight: bold, letterSpacing: -0.3, height: 1.1,
  ).copyWith(fontFeatures: const [FontFeature.tabularFigures()]);

  static TextStyle numeric(TextStyle style) {
    return style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]);
  }

  // ==========================================================
  // Responsive scaling — adjusts fontSize for the device's physical
  // size class (phone/tablet/desktop). This is deliberately NOT the
  // same mechanism as accessibility text scaling: Flutter already
  // applies the user's OS-level text scale factor to any `Text`
  // widget automatically, on top of whatever fontSize a TextStyle
  // specifies, with no action needed here — reimplementing that here
  // would double-apply scaling and fight the accessibility system
  // instead of respecting it. This method only widens type for a
  // physically larger screen at a comfortable viewing distance
  // (a tablet/desktop held or sat further away than a phone), which
  // is an entirely separate concern from a user's accessibility
  // preference.
  // ==========================================================
  static const double _tabletBreakpoint = 600;
  static const double _desktopBreakpoint = 1024;
  static const double _minScaleFactor = 0.9;
  static const double _maxScaleFactor = 1.2;

  static double _scaleFactorForWidth(double width) {
    final double raw = switch (width) {
      < _tabletBreakpoint => 1.0,
      < _desktopBreakpoint => 1.08,
      _ => 1.15,
    };
    return raw.clamp(_minScaleFactor, _maxScaleFactor).toDouble();
  }

  /// Pure, context-free scaling — takes a screen width directly, so it
  /// stays trivially testable without needing a widget tree.
  static TextStyle scale(TextStyle style, double screenWidth) {
    final double? fontSize = style.fontSize;
    if (fontSize == null) return style;
    return style.copyWith(fontSize: fontSize * _scaleFactorForWidth(screenWidth));
  }

  /// Convenience wrapper over [scale] for call sites that already have
  /// a [BuildContext] to hand.
  static TextStyle responsive(BuildContext context, TextStyle style) {
    return scale(style, MediaQuery.sizeOf(context).width);
  }
}

/// `copyWith*` convenience helpers for [TextStyle], so call sites don't
/// repeatedly write `style.copyWith(fontWeight: ..., color: null, ...)`
/// (and accidentally clobber unrelated fields) every time they need to
/// adjust one property of an [AppTypography] token.
extension AppTextStyleX on TextStyle {
  TextStyle copyWithWeight(FontWeight weight) => copyWith(fontWeight: weight);

  TextStyle copyWithColor(Color color) => copyWith(color: color);

  TextStyle copyWithSpacing(double letterSpacing) =>
      copyWith(letterSpacing: letterSpacing);
}
