---
name: momentum-ui
description: Build or restyle a Momentum screen or widget using the existing dark-only design system (AppColors, AppTypography, AppSpacing, AppRadius, AppSizing, AppShadows) under mobile/lib. Use when adding or changing a screen, card, button, or other widget, or when asked to match Momentum's visual style.
---

# Momentum UI

Shared rules (don't invent, verify before claiming, standard commands) are in the root
`CLAUDE.md` — read it first. This skill is the design-system layer on top of that.

## Before writing any widget

1. Read `references/design-tokens.md` for the token catalogue — every color, text style,
   spacing, radius, size, and shadow value actually defined in `mobile/lib/core/theme/`.
2. Find the closest existing widget to copy conventions from:
   - Generic chrome: `mobile/lib/core/widgets/` (`app_card.dart`, `primary_button.dart`,
     `secondary_button.dart`, `app_text_field.dart`, `loading_skeleton.dart`, etc.)
   - Feature-specific: the same feature's own `presentation/widgets/` folder (e.g.
     `features/exercises/presentation/widgets/exercise_card.dart`).
   Reuse or extend before adding a new widget that does the same job slightly differently.
3. If the task touches bottom-nav or tab routes: the live shell is `AppShell`
   (`core/routing/app_shell.dart`) + `FloatingNavBar`, 5 tabs. `MotraShell`/
   `MotraBottomNav` (`shared/widgets/motra_bottom_nav.dart`) is **not wired** and references
   routes that don't exist. Neither matches the product's actual 3-tab TRAIN/PROGRESS/CONNECT
   target (see CLAUDE.md Known gaps). Don't silently extend either as if it were final —
   confirm with the user before adding a tab to any shell.

## Hard rules

- No widget ever constructs `TextStyle(...)` directly — use an `AppTypography` token, or
  `AppTypography.numeric(style)` / `.scale(style, width)` for the two documented variants.
- No widget ever references `Colors.white`, `Colors.black`, or any other raw `Colors.*` /
  hex value — use `AppColors`. If a color you need genuinely isn't in `AppColors`, say so
  and ask before inventing one; don't add an ad hoc `Color(0xFF...)` inline.
- No raw pixel numbers for spacing (`SizedBox(height: 16)`) or radius
  (`BorderRadius.circular(12)`) — use `AppSpacing` / `AppRadius`.
- Theme is dark-only. Don't add a `lightTheme` branch or `Theme.of(context).brightness`
  light-mode logic.
- Don't use "Motra"/"MOTRA" in any new widget name, variable, or comment — product name is
  Momentum.

## Steps

1. Identify the pillar (TRAIN / PROGRESS / CONNECT) and the feature folder.
2. Check `references/design-tokens.md` for the tokens the design calls for.
3. Build the widget as a `StatelessWidget` or `ConsumerWidget` (per `flutter-feature`'s
   Riverpod conventions if it needs live data) in the correct `presentation/widgets/` or
   `presentation/screens/` folder.
4. Run `flutter analyze` from `mobile/` and show the actual output.

## Completion criteria

- `flutter analyze --no-pub` run and its real output shown, with no *new* issues introduced
  by this change (the repo currently has 276 pre-existing issues — see CLAUDE.md Known gaps
  — don't claim those are yours to fix here unless asked).
- Diff contains zero raw `Colors.`, zero inline `TextStyle(`, zero magic-number
  `EdgeInsets`/`SizedBox`/`BorderRadius.circular(<number>)`.
- New widget lives under the correct feature's `presentation/` subtree (or `core/widgets/`
  /`shared/widgets/` only if it's genuinely cross-feature chrome).
