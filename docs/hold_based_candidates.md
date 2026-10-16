# Hold-based exercise candidates — for review

`exercises.is_hold_based` is `false` for all 873 imported free-exercise-db rows,
because the dataset has no hold/reps flag. **Nothing has been changed.** This list
is for a human to decide which rows should become `is_hold_based = true`.

How it was generated (read-only SQL against the linked project, 2026-10-16):
name matches one of `plank, hang, hold, l-sit, lever, isometric, static, wall sit,
bridge, support, handstand, hollow, superman, dead bug, bird dog, iron cross,
planche, flag, squeeze, pause`, **or** upstream `force = 'static'`.
Searches for `hold`, `l-sit`, `hollow`, `planche`, `flag`, `wall sit`, `bird dog`
and `pause` found nothing: those exercises aren't in the dataset.

Related: the unapplied `20261016000001_train_workout_logging.sql` already derives
`tracking_type = 'duration'` for every `category = 'stretching'` row and every
`is_hold_based` row, so the stretching group below gets timed tracking
whatever you decide about `is_hold_based`.

## A. Likely hold-based (recommend `true`)

| Name | Slug | Category | Why |
|---|---|---|---|
| Plank | `plank` | strength | static, classic hold |
| Side Bridge | `side-bridge` | strength | static (side plank) |
| Isometric Chest Squeezes | `isometric-chest-squeezes` | plyometrics | static, isometric |
| Isometric Neck Exercise - Front And Back | `isometric-neck-exercise-front-and-back` | strength | static, isometric |
| Isometric Neck Exercise - Sides | `isometric-neck-exercise-sides` | strength | static, isometric |
| Plate Pinch | `plate-pinch` | strength | static grip hold |
| Standing Olympic Plate Hand Squeeze | `standing-olympic-plate-hand-squeeze` | strength | static grip hold |
| Crucifix | `crucifix` | strongman | static, held arms-out |
| Downward Facing Balance | `downward-facing-balance` | strength | static balance hold |
| One Handed Hang | `one-handed-hang` | stretching | static dead hang |
| Superman | `superman` | stretching | static |
| Stomach Vacuum | `stomach-vacuum` | stretching | static, held contraction |

## B. Ambiguous — check the instructions

| Name | Slug | Category | Why unsure |
|---|---|---|---|
| Isometric Wipers | `isometric-wipers` | strength | "isometric" in name, but upstream force = push (moving) |
| Prone Manual Hamstring | `prone-manual-hamstring` | strength | static, but partner-resisted reps |
| Iron Cross | `iron-cross` | strength | gymnastics hold by name; upstream data is a moving dumbbell exercise |
| Cable Iron Cross | `cable-iron-cross` | strength | cable fly variant, likely reps |
| Iron Crosses (stretch) | `iron-crosses-stretch` | stretching | dynamic stretch (force = pull) |
| Pelvic Tilt Into Bridge | `pelvic-tilt-into-bridge` | stretching | static, but tilt → bridge movement |
| Push Up to Side Plank | `push-up-to-side-plank` | strength | rep-based combo with a brief plank |
| Dead Bug | `dead-bug` | strength | usually reps |

## C. Name matched, almost certainly NOT hold-based (recommend leave `false`)

- **Hang = Olympic-lift start position:** Alternating Hang Clean, Bottoms-Up Clean From The Hang Position, Double Kettlebell Alternating Hang Clean, Hang Clean, Hang Clean - Below the Knees, Hang Snatch, Hang Snatch - Below Knees, Kettlebell Hang Clean, Smith Machine Hang Power Clean
- **Hanging = position, movement is reps:** Hanging Bar Good Morning, Hanging Leg Raise, Hanging Pike
- **Leverage = machine brand/type:** Leverage Chest Press, Leverage Deadlift, Leverage Decline Chest Press, Leverage High Row, Leverage Incline Chest Press, Leverage Iso Row, Leverage Shoulder Press, Leverage Shrug
- **Bridge = hip-thrust reps:** Barbell Glute Bridge, Butt Lift (Bridge), London Bridges, Physioball Hip Bridge, Single Leg Glute Bridge
- **Handstand Push-Ups:** reps

## D. Stretching / SMR with `force = static` (94 of 123 stretching rows)

Every row in category `stretching` that upstream marks `static`. They're timed in
practice (static stretches, plus the `-SMR` foam-rolling rows), and the
train-logging migration already gives every stretching row
`tracking_type = 'duration'`. Whether they should *also* get `is_hold_based = true`
is a product call: does `is_hold_based` mean "timed", or specifically
"strength/skill hold" (plank, L-sit, lever)? The roadmap's skill objectives may
read it with the second meaning.

To list them: `select name, slug from exercises where category = 'stretching' and force = 'static' order by name;`
(The slugs in A that are also `stretching` — `one-handed-hang`, `superman`,
`stomach-vacuum` — are listed there separately because they're holds even under
the narrower meaning.)
