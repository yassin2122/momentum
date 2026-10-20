/// GRIT's sizing token system.
///
/// Every concrete pixel measurement used for icon sizes, control
/// heights, and minimum hit-targets anywhere in the app must come from
/// one of these tokens. Centralizing sizes prevents two adjacent
/// widgets from drifting into slightly different "small icon" values
/// (one is 16, one is 18) that read as inconsistent at a glance even
/// though neither looks "wrong" in isolation.
abstract final class AppSizing {
  // ==========================================================
  // Icons — three sizes matching the same small/medium/large scale
  // used elsewhere. `iconSm` is for inline-with-text chrome
  // (section eyebrows, table-row actions), `iconMd` for tab bar and
  // list-row icons, `iconLg` for empty-state hero icons.
  // ==========================================================
  static const double iconSm = 16;
  static const double iconMd = 24;
  static const double iconLg = 32;

  // ==========================================================
  // Control heights — single source of truth for any primary
  // button, form input, search field, or other tap target's height.
  // Using the same token across all of them is what makes a
  // vertically-stacked form read as a coherent set rather than a
  // pile of independently-sized widgets.
  // ==========================================================
  static const double buttonHeight = 52;
  static const double inputHeight = 52;

  // ==========================================================
  // Min touch target — WCAG / Apple HIG / Material all recommend a
  // minimum interactive target around 44pt. Used by icon-only buttons
  // (close, settings) so a large enough tappable area is guaranteed
  // even when the visible icon is much smaller.
  // ==========================================================
  static const double minTouchTarget = 44;

  // ==========================================================
  // Floating bottom nav bar height (icon + label + padding).
  // ==========================================================
  static const double navBarHeight = 64;
}
