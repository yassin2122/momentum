# GRIT — Design System

**Version:** 1.0  
**Platform:** Flutter mobile app  
**Theme:** Dark-first, premium, minimal, one-handed

---

## 1. Design Principles

### 1. Clarity before decoration
Workout data, progress, and actions must always be understandable at a glance.

### 2. Progress must feel earned
Do not use visual effects that make ordinary actions feel more important than real milestones.

### 3. Calm during training
The interface becomes quieter once a workout starts. Animations, mascot activity, and secondary information should reduce.

### 4. One-handed usability
Primary actions should remain reachable near the bottom half of the screen.

### 5. Dark does not mean empty black
Use layered near-black surfaces, subtle borders, restrained highlights, and material depth.

### 6. Character with restraint
Grit adds emotion and identity but never competes with workout information.

### 7. Consistency over novelty
Components should behave the same everywhere.

---

## 2. Foundations

## 2.1 Color Tokens

### Brand
```dart
static const brandPrimary = Color(0xFF23576B);
static const brandSecondary = Color(0xFF496575);
static const brandAccent = Color(0xFFFF6B3D);
static const legendary = Color(0xFFC8A85A);
```

### Dark surfaces
```dart
static const bgPrimary = Color(0xFF0D0F12);
static const bgSecondary = Color(0xFF101318);
static const surfacePrimary = Color(0xFF14171B);
static const surfaceSecondary = Color(0xFF1B1F24);
static const surfaceElevated = Color(0xFF22272D);
static const borderSubtle = Color(0xFF2A3037);
static const borderStrong = Color(0xFF3A424C);
```

### Dark text
```dart
static const textPrimary = Color(0xFFF5F4F0);
static const textSecondary = Color(0xFFA8AFB7);
static const textMuted = Color(0xFF747C86);
static const textDisabled = Color(0xFF515861);
```

### Light theme support
```dart
static const lightBgPrimary = Color(0xFFF6F3EC);
static const lightSurface = Color(0xFFFFFFFF);
static const lightBorder = Color(0xFFD8D4CC);
static const lightTextPrimary = Color(0xFF101216);
static const lightTextSecondary = Color(0xFF5F646B);
```

### Semantic
```dart
static const success = Color(0xFF4FAE7B);
static const warning = Color(0xFFF4B860);
static const error = Color(0xFFE45D5D);
static const info = Color(0xFF5A8FB8);
```

### Overlay
```dart
static const scrim = Color(0xB3000000);
static const white08 = Color(0x14FFFFFF);
static const white12 = Color(0x1FFFFFFF);
static const white16 = Color(0x29FFFFFF);
```

### Color usage rules
- Primary blue: selected states, main buttons, active progress, links.
- Steel blue: secondary progress, charts, supporting elements.
- Orange: PRs, urgent highlight, energetic celebration. Never use as the default CTA color.
- Gold: Legendary certification only.
- Red: destructive actions and errors only.
- Green: confirmed success only.

---

## 2.2 Typography

### Font family
- Primary: `SF Pro Display` / `SF Pro Text`
- Fallback: `Inter`

### Type scale
| Token | Size | Weight | Line height | Use |
|---|---:|---:|---:|---|
| displayLarge | 40 | 700 | 46 | Major achievement or onboarding |
| displayMedium | 34 | 700 | 40 | Hero numbers and key progress |
| headlineLarge | 28 | 700 | 34 | Screen title |
| headlineMedium | 24 | 700 | 30 | Section title |
| titleLarge | 20 | 600 | 26 | Card title |
| titleMedium | 17 | 600 | 22 | List title |
| bodyLarge | 16 | 400 | 24 | Main body |
| bodyMedium | 14 | 400 | 20 | Supporting body |
| labelLarge | 14 | 600 | 18 | Buttons |
| labelMedium | 12 | 600 | 16 | Chips, metadata |
| labelSmall | 11 | 600 | 14 | Eyebrow labels |

### Numeric styles
- Use tabular figures.
- Weight and reps: 20–28 px semibold.
- Workout timer: 32–40 px bold.
- Progress percentages: 16–20 px semibold.
- Never use condensed type for data entry.

### Text rules
- Screen title: sentence case.
- Small section eyebrow: uppercase with 0.08–0.12 em tracking.
- Buttons: sentence case.
- Avoid centered paragraphs except onboarding and empty states.

---

## 2.3 Spacing

Use a 4-point base grid.

```dart
static const space2 = 2.0;
static const space4 = 4.0;
static const space8 = 8.0;
static const space12 = 12.0;
static const space16 = 16.0;
static const space20 = 20.0;
static const space24 = 24.0;
static const space32 = 32.0;
static const space40 = 40.0;
static const space48 = 48.0;
static const space64 = 64.0;
```

### Default layout values
- Screen horizontal padding: 20 px
- Compact screen padding: 16 px
- Card internal padding: 16 px
- Large card padding: 20–24 px
- Section gap: 32 px
- Card gap: 12–16 px
- Form field gap: 16 px

---

## 2.4 Radius

```dart
static const radiusXs = 6.0;
static const radiusSm = 10.0;
static const radiusMd = 14.0;
static const radiusLg = 18.0;
static const radiusXl = 24.0;
static const radiusPill = 999.0;
```

### Radius usage
- Input fields: 14 px
- Standard cards: 18 px
- Bottom sheets: 24 px top corners
- Buttons: 14–18 px
- Chips: pill
- App icon: platform standard

Avoid applying maximum rounding to every surface. Stronger radius should indicate higher-level containers.

---

## 2.5 Borders

### Standard border
- 1 px
- `borderSubtle`

### Strong border
- 1 px
- `borderStrong`
- Used for focus, selection, and important controls

### Selected border
- 1.5 px
- `brandPrimary`

### Legendary border
- 1 px gold with a restrained highlight; no permanent glow

---

## 2.6 Elevation and Shadows

Dark surfaces should rely more on value contrast and borders than large shadows.

### Elevation levels
| Level | Use |
|---|---|
| 0 | Page background |
| 1 | Standard card |
| 2 | Active card, sticky control |
| 3 | Bottom sheet, dialog |
| 4 | Celebration overlay |

### Shadow guidance
- Low opacity
- Large blur
- Minimal vertical offset
- Avoid colored shadows except very rare milestone moments

Suggested shadow:
```dart
BoxShadow(
  color: const Color(0x66000000),
  blurRadius: 24,
  offset: const Offset(0, 10),
)
```

---

## 2.7 Glass and Metal Materials

### Glass surface
Use only for overlays, floating controls, or navigation—not for every card.

- Background: white at 6–10% opacity
- Border: white at 10–14% opacity
- Blur: 16–24 px
- Maintain readable contrast

### Metal surface
Used for premium achievement, PR, or skill certification elements.

- Dark neutral gradient
- Thin directional highlight
- Subtle inner border
- No chrome mirror effect
- No excessive shine

### Rule
A screen should not mix more than two material styles at once.

---

## 3. Layout System

### Safe areas
Always respect device safe areas.

### Grid
- Mobile: 4-column conceptual grid
- Gutter: 16–20 px
- Content max width on large screens: 680 px

### Primary action zone
Place frequent actions within the lower 40% of the screen.

### Scroll behavior
- Screen titles may collapse into a compact app bar.
- Important workout controls may remain sticky.
- Avoid horizontal scrolling for critical content.

---

## 4. Icon System

### Library
Lucide Icons

### Default stroke
- 2.0 px at 24 px size
- 1.75 px at 20 px size

### Icon states
- Inactive: `textMuted`
- Active: `textPrimary` or `brandPrimary`
- Destructive: `error`
- Disabled: `textDisabled`

### Navigation icons
Use outline inactive and filled/custom active states only where a matching pair exists. Do not mix inconsistent visual weights.

---

## 5. Core Components

## 5.1 Buttons

### Primary button
- Height: 52 px
- Background: `brandPrimary`
- Text: `textPrimary`
- Radius: 16 px
- Horizontal padding: 20 px
- Icon gap: 8 px

States:
- Default
- Pressed: darken by 8–10%
- Loading: preserve width; show inline spinner
- Disabled: 40% opacity; no shadow

### Secondary button
- Height: 52 px
- Background: `surfaceSecondary`
- Border: `borderStrong`
- Text: `textPrimary`

### Tertiary button
- Transparent
- Text/icon: `brandPrimary` or `textPrimary`
- Minimum tap target: 44 px

### Destructive button
Use red only when the consequence is destructive.

### Floating workout action
- 56–64 px
- Bottom-center or lower-right depending on navigation
- Strong contrast
- Never obscure workout data

---

## 5.2 Input Fields

### Standard field
- Height: 52 px
- Radius: 14 px
- Background: `surfacePrimary`
- Border: `borderSubtle`
- Focus border: `brandPrimary`
- Padding: 16 px

### Numeric workout field
- Large tabular number
- Centered or right-aligned depending on table context
- Stepper controls optional
- Input must remain usable with one hand

### Error state
- Red border
- Error message below field
- Do not rely on color alone; include icon or text

---

## 5.3 Cards

### Standard card
- Background: `surfacePrimary`
- Radius: 18 px
- Border: `borderSubtle`
- Padding: 16 px

### Interactive card
- Entire card may be tappable
- Press state: scale to 0.985 or reduce brightness slightly
- Include a clear affordance such as chevron, button, or state label

### Hero card
Used for Today’s Workout, current skill, or weekly progress.
- Radius: 24 px
- Padding: 20–24 px
- May include Grit illustration
- One primary action only

---

## 5.4 Navigation

### Bottom navigation
Recommended items for current phase:
1. Home
2. Train
3. Roadmap
4. Profile

The social feed is deferred and should not occupy a primary navigation slot.

### Navigation bar dimensions
- Height: 64–72 px plus safe area
- Icon: 24 px
- Label: 11–12 px
- Selected item: brand blue or light text
- Background: elevated dark surface or restrained glass

### App bar
- Height: 56 px
- Title: 20–24 px semibold
- Back button tap target: 44 px
- Maximum two trailing actions

---

## 5.5 Chips and Tags

### Filter chip
- Height: 32–36 px
- Horizontal padding: 12 px
- Radius: pill
- Default: surface + border
- Selected: blue-tinted surface + blue border

### Status chip
Use semantic colors with text labels. Examples: Completed, Locked, In progress, Rest day.

---

## 5.6 Progress Indicators

### Linear progress
- Height: 6–8 px
- Track: `surfaceElevated`
- Fill: `brandPrimary`
- Radius: pill

### Skill progress
Show both objective completion and XP feedback where relevant. XP must not imply automatic skill unlock.

### Circular progress
Use sparingly for daily readiness, completion percentage, or compact dashboard summaries.

### Legendary progress
Gold may be used only when the user is actually progressing toward or holding Legendary certification.

---

## 5.7 Workout Set Row

Required information:
- Set number
- Previous performance
- Weight
- Reps
- Optional RPE
- Completion control

Rules:
- Weight and reps get the highest visual priority.
- Previous values use muted text.
- Completed rows become quieter, not brighter.
- Swipe gestures must have visible alternatives.
- Minimum row height: 56 px.

---

## 5.8 Roadmap Node

### States
- Locked
- Available
- In progress
- Objective complete
- Skill complete
- Master
- Legendary

### Visual behavior
- Locked: muted, visible, no mystery glow
- Available: strong border and clear CTA
- In progress: blue progress ring or bar
- Complete: success check with restrained animation
- Master: premium steel treatment
- Legendary: gold accent

### Node rules
- Every locked node should explain its prerequisite.
- Do not use XP alone to communicate unlock eligibility.
- Objective completion must remain visible.

---

## 5.9 Achievement Badge

- Shape based on achievement family
- Category icon centered
- Tier communicated by border/material
- Title and requirement shown separately
- Locked achievements remain visible unless intentionally hidden elite content

---

## 5.10 Bottom Sheets

- Top radius: 24 px
- Drag handle: 36 × 4 px
- Background: `surfaceSecondary`
- Padding: 20 px
- Primary action remains visible above safe area
- Use for exercise selection, filters, quick editing, and workout actions

---

## 5.11 Dialogs

Use only for:
- Destructive confirmation
- Important permission explanation
- Workout cancellation
- Irreversible actions

Avoid using dialogs for normal navigation or routine information.

---

## 5.12 Snackbars and Toasts

- Duration: 2–4 seconds
- One action maximum
- Non-blocking
- Bottom placement above navigation
- Success feedback should be brief
- Do not show a snackbar for every set completion

---

## 5.13 Empty States

Include:
- Small Grit illustration
- Clear title
- One short explanation
- One action

Example:
**No workouts yet**  
Build your first template and start tracking progress.  
`Create workout`

---

## 5.14 Loading States

### Skeletons
Preferred for cards, lists, and dashboard content.

### Spinner
Use for small local operations only.

### Mascot loading
Use only for app launch, major initialization, or branded empty/loading moments. Do not show the mascot animation for every network request.

---

## 6. Mascot Integration System

### Size tiers
- XS: 24–32 px — decorative mark only
- S: 40–64 px — compact empty state or status
- M: 80–140 px — card illustration
- L: 180–280 px — onboarding or achievement

### Interaction rules
- Grit may point toward one important action.
- Grit should not overlap text or touch targets.
- Avoid constant looping animation.
- During workout logging, Grit should be static or absent.
- Major milestone animation should be dismissible and under 2 seconds before controls become available.

---

## 7. Motion System

### Durations
```dart
static const instant = Duration(milliseconds: 100);
static const fast = Duration(milliseconds: 180);
static const normal = Duration(milliseconds: 280);
static const slow = Duration(milliseconds: 420);
static const celebration = Duration(milliseconds: 700);
```

### Easing
- Standard entrance: easeOutCubic
- Exit: easeInCubic
- Repositioning: easeInOutCubic
- Spring: only for mascot and milestone moments

### Motion rules
- Button feedback: 100–150 ms
- Screen transition: 220–320 ms
- Bottom sheet: 280–360 ms
- Progress fill: 400–700 ms
- Celebration: under 1.5 seconds for the main motion

### Reduce motion
Respect platform accessibility settings. Replace large movement with fades and instant state changes.

---

## 8. Haptics

### Light
- Button press
- Chip selection
- Set completion

### Medium
- Workout start
- Personal record
- Skill objective completion

### Strong
- Major skill unlock
- Master or Legendary certification

Do not use haptics repeatedly during scrolling, typing, or timers.

---

## 9. Accessibility

### Touch targets
Minimum 44 × 44 px.

### Contrast
- Body text: target WCAG AA
- Muted text must remain readable
- Never communicate status through color alone

### Text scaling
Support at least 200% system text scaling without hiding primary actions.

### Screen readers
- Provide semantic labels for icons
- Announce completed sets and timer state
- Describe progress values with meaningful language

### Motion
Support reduced motion.

### Input
Numeric fields should use appropriate keyboards and clear labels.

---

## 10. Screen-Level Patterns

## Dashboard
Order:
1. Greeting/status
2. Today’s workout hero
3. Current skill progress
4. Weekly consistency/streak
5. Recent performance or PR

Avoid placing social content in the current primary dashboard.

## Workout screen
Priority:
1. Current exercise
2. Active set entry
3. Rest timer
4. Previous performance
5. Notes and secondary actions

The mascot should not animate continuously here.

## Roadmap screen
- Galaxy/discipline overview
- Skill planets/cards
- Locked prerequisites remain visible
- Progress should distinguish objectives from XP
- Smooth zoom transitions are allowed but must remain fast and clear

## Profile
- Identity
- Training statistics
- Achievements
- Personal records
- Settings

---

## 11. Content and Microcopy

### Button verbs
Use direct verbs:
- Start workout
- Log set
- Continue
- View roadmap
- Add exercise
- Complete workout

### Avoid vague labels
Avoid:
- Go
- Okay
- Submit
- Click here

### Error structure
1. What happened
2. What the user can do

Example:
**Workout couldn’t be saved.**  
Check your connection and try again.

---

## 12. Data Visualization

### Chart style
- Minimal axes
- Few grid lines
- No 3D effects
- Brand blue for main series
- Steel blue for comparison
- Orange only for highlight/PR
- Tooltips show exact values

### Chart rules
- Start y-axis at zero when comparing magnitude unless doing so would hide meaningful variation.
- Label units clearly.
- Do not show more than four series on mobile.
- Use tabular numerals.

---

## 13. Component States Checklist

Every interactive component must define:
- Default
- Pressed
- Focused
- Selected
- Loading
- Disabled
- Error
- Success where relevant
- Empty where relevant

---

## 14. Flutter File Structure

```text
lib/
└── core/
    └── design_system/
        ├── tokens/
        │   ├── app_colors.dart
        │   ├── app_typography.dart
        │   ├── app_spacing.dart
        │   ├── app_radius.dart
        │   ├── app_borders.dart
        │   ├── app_shadows.dart
        │   └── app_motion.dart
        ├── theme/
        │   ├── app_theme.dart
        │   ├── dark_theme.dart
        │   └── light_theme.dart
        ├── components/
        │   ├── buttons/
        │   ├── cards/
        │   ├── inputs/
        │   ├── navigation/
        │   ├── feedback/
        │   ├── progress/
        │   ├── roadmap/
        │   ├── workout/
        │   └── mascot/
        └── extensions/
```

---

## 15. Definition of Done

A screen is design-system complete only when:
- It uses tokens rather than hard-coded values.
- All component states are defined.
- Touch targets meet minimum size.
- Text scaling is tested.
- Dark-theme contrast is verified.
- Loading, empty, error, and offline states exist.
- Motion respects reduced-motion settings.
- The primary action is reachable with one hand.
- Mascot usage supports rather than distracts from the task.
- The screen is consistent with Train, Progress, Become.
