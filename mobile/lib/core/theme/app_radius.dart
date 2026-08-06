/// MOTRA's corner radius token system.
///
/// Every `BorderRadius`/`Radius` anywhere in the app must come from one
/// of these tokens — no widget should ever write `BorderRadius.circular(
/// 14)` with a number invented on the spot. Consistent radius is one of
/// the fastest ways a UI reads as "considered" rather than "assembled,"
/// especially in a glassmorphic design where soft, rounded edges are
/// doing a lot of the visual work.
abstract final class AppRadius {
  /// Smallest rounding — small controls that shouldn't read as fully
  /// "pill" shaped: input field corners, small badges, tooltip corners.
  static const double small = 8;

  /// Two-letter aliases matching the AppSpacing `xxs/xs/sm/md/lg/xl`
  /// scale, for call sites that already use those names instead of
  /// `small/medium/large/xl`. `sm` → small, `md` → medium, `lg` →
  /// large. Aliases, not the canonical names — keep the long-form
  /// tokens above as the single source of truth.
  static const double xs = small;
  static const double sm = small;
  static const double md = medium;
  static const double lg = large;

  /// Default rounding for compact interactive elements — icon buttons,
  /// chips, small glass panels.
  static const double medium = 12;

  /// The most common radius in the app — standard cards, glass panels,
  /// list rows, sheets' non-anchored corners.
  static const double large = 20;

  /// Prominent rounding for hero surfaces — the top corners of a
  /// bottom sheet or modal, large feature cards, onboarding panels.
  /// Rounded enough to feel distinctly softer than `large` without
  /// tipping into `pill`'s fully-capsule territory.
  static const double xl = 28;

  /// Fully rounds the short side of an elongated shape into a capsule
  /// — buttons, search bars, filter chips. Set high enough (well above
  /// half of any realistic control height) that it always resolves to
  /// a true pill regardless of the exact height a given button ends up
  /// being, without needing to compute that height here.
  static const double pill = 999;

  /// Fully rounds an equal-dimension shape into a circle — avatars,
  /// circular icon buttons, dot indicators. Numerically identical to
  /// [pill] today, but named separately because the *intent* differs:
  /// `pill` is for elongated shapes becoming a capsule, `circle` is for
  /// square/equal-dimension shapes becoming a disc. Keeping them
  /// distinct tokens means a future design change to one shape family
  /// (e.g. slightly squaring off circular avatars) doesn't have to
  /// touch every pill-shaped button along with it.
  static const double circle = 999;

  // ==========================================================
  // Dashboard — radii introduced on the dashboard screen.
  // Not folded into the existing scale because the spec is
  // explicit about the two card tiers needing distinct tokens
  // (compact stat cards vs. large content cards).
  // ==========================================================

  /// Small stat cards (Streak, Rings) — 20 px per spec §5.
  static const double cardCompact = 20;

  /// Large content cards (Workout, Skill, Community container)
  /// — 24 px per spec §5.
  static const double cardLarge = 24;

  /// Community post thumbnails — 16 px per spec §5.
  static const double postThumbnail = 16;

  /// Notification bell icon button — 16 px rounded square,
  /// not circular, per spec §5.
  static const double bellButton = 16;
}
