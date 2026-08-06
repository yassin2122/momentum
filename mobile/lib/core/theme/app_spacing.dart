/// MOTRA's spacing token system.
///
/// Every `EdgeInsets`, `SizedBox`, and `Gap` value anywhere in the app
/// must be built from one of these tokens — no widget should ever write
/// a raw pixel number for spacing. This is what keeps rhythm consistent
/// across screens built at different times by different people (or by
/// the same person on a different day).
///
/// Scale note: the brief's requested step names are `xxs, xs, sm, md,
/// lg, xl, 2xl, 3xl, 4xl`. `2xl`/`3xl`/`4xl` are not valid Dart
/// identifiers (an identifier can't start with a digit), so they're
/// named `xl2`/`xl3`/`xl4` here — same scale, same intent, the only
/// change is what's mechanically possible to write as a Dart field
/// name. Flagging this rename explicitly rather than silently
/// resolving it.
abstract final class AppSpacing {
  /// Smallest step — hairline gaps: between an icon and its adjacent
  /// label, between a chip's border and its text.
  static const double xxs = 4;

  /// Tight grouping — related elements that should read as one visual
  /// unit but still need a breath between them (e.g. a title and the
  /// subtitle directly under it).
  static const double xs = 8;

  /// Default gap between closely related controls within the same
  /// component (e.g. two buttons in a row, a label above its input).
  static const double sm = 12;

  /// The most common spacing value in the app — default internal
  /// padding for cards/panels, default gap between stacked components
  /// within one section.
  static const double md = 16;

  /// Separates distinct sections within the same screen (e.g. the gap
  /// between a page header and the content below it).
  static const double lg = 24;

  /// Separates major regions of a screen, or provides a screen's
  /// standard outer horizontal margin.
  static const double xl = 32;

  /// Large separation for hero content — the space above a screen's
  /// primary call-to-action, or around a celebratory moment (PR
  /// achieved, workout completed) that deserves visual room to breathe.
  static const double xl2 = 48;

  /// Very large separation — full section breaks on a long scrolling
  /// screen (e.g. between Statistics' chart section and its Personal
  /// Records section).
  static const double xl3 = 64;

  /// Largest step — reserved for generous top/bottom screen padding on
  /// wide viewports (tablet/desktop), where MOTRA's phone-tuned smaller
  /// steps alone would leave content looking cramped against the extra
  /// available space.
  static const double xl4 = 96;

  /// Semantic alias for the app's standard horizontal screen margin.
  /// Equal to [md] today — kept as its own named constant (rather than
  /// every screen writing `AppSpacing.md` for this specific purpose)
  /// because "screen padding" is a decision that could diverge from
  /// the general-purpose `md` step later without that being a change
  /// to the `md` step's own meaning.
  static const double screenPadding = md;

  /// Extra-large vertical rhythm — between hero sections of an
  /// otherwise listless "wide, airy" page. Matches `lg`; named
  /// `xxl` for call sites that read as "this is the big gap" in a
  /// context where the `lg` step already means something narrower.
  static const double xxl = lg;

  /// Triple-extra-large — the absolute largest gap the app uses
  /// short of section-break whitespace. Matches `xl3`; the same
  /// alias/naming distinction as [xxl], just one rung up the scale.
  static const double xxxl = xl3;
}

/// Sizing tokens — touch targets, icon sizes, and standard control
/// heights. Not part of the MOTRA spacing scale above (those are gaps
/// *between* things; these are the dimensions of the things
/// themselves), and not part of the original MOTRA design-system file
/// list either — restored here during the post-migration cleanup
/// because every interactive control in the app depends on it and
/// there is no glass-system equivalent to migrate to instead.
abstract final class AppSizing {
  /// Absolute minimum tappable area, per platform accessibility
  /// guidance — every tappable control must be at least this large
  /// regardless of how small its visible content looks.
  static const double minTouchTarget = 48;

  static const double buttonHeight = 56;
  static const double inputHeight = 56;

  static const double iconSm = 18;
  static const double iconMd = 24;
  static const double iconLg = 32;
}
