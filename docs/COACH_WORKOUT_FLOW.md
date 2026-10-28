# Coach workouts, Coach tab cleanup, and the Marketplace

Status: database written (not yet pushed), feedback card removed, rest of the
client not built yet.

Decisions (2026-10-28):

1. A workout a coach sends goes **straight into the athlete's own templates**.
2. Coach feedback is **removed from the athlete UI for now**.
3. The Marketplace lists **coaches, gyms, physical therapists and doctors**, and
   is **contact + location only** — no booking, payments or data sharing.
4. "Are you a coach?" leaves the Coach tab; coach sign-in moves to Sign In.

---

## 1. Coach workout → athlete's templates

### Database — `20261028120000_coach_workout_to_template.sql`

- `workout_templates` gains `assigned_by`, `assigned_note`, `assigned_at`.
  Null for the athlete's own templates.
- `send_workout_to_athlete(p_relationship_id, p_name, p_exercises, p_note)`:
  - Only an approved coach with an **active** relationship to that athlete.
  - Creates the template **owned by the athlete** plus its exercises
    (sets / reps / hold seconds / notes per exercise).
  - Library exercises only — a coach's custom exercise is invisible to the
    athlete, so it's rejected.
  - Sends the athlete a notification: "Coach Sam sent you a workout: Upper
    Body Power".
  - If the athlete already has 7 templates, the send fails with: "This
    athlete already has 7 templates. Ask them to delete one, then send again".
- No new RLS policy for coaches. The coach writes only through this function
  and can't read or change the template afterwards.

After delivery the template is the athlete's like any other: they can start,
edit, rename or delete it.

### Where the athlete sees it

No new screens. It's a template, so it shows up everywhere templates already do:

| Place | What changes |
|---|---|
| **Dashboard → "Your Plan" carousel** | Coach templates sort first (after the in-progress card). `_PlanCard` gets a tag: coach avatar + "From Coach Sam", plus a "New" pill until opened once. |
| **Preview sheet** (`_TemplatePreviewSheet`) | Shows the coach's note at the top, if any. Start works exactly as for any template. |
| **Train tab → "Your templates"** | Same row, with the "From Coach Sam" tag under the name. Delete works as normal. |
| **Active workout / summary** | Unchanged. It's a normal template workout, so PRs, streak and template additions all behave as usual. |

```
┌──────────────────────────────┐
│ (o) From Coach Sam     [New] │
│  Upper Body Power            │
│  6 exercises                 │
│       [ muscle art ]         │
│  [        View        ]      │
└──────────────────────────────┘
```

The tag uses `AppTypography.labelMedium` / `AppColors.hubTextMuted`, so it
looks like the rest of the card.

### Flow

1. **Coach:** Coach Hub → client → **Send workout** → pick exercises (reuse
   `ExercisePickerSheet`), set sets × reps, optional note → **Send**.
2. **Athlete:** gets the notification → tap opens the Dashboard on that card.
   If the app is open, listening on `notifications` (already in Realtime)
   refreshes `workoutTemplatesProvider`.
3. **Athlete:** View → Start → normal workout → normal summary.

### Client work still to do

| File | Change |
|---|---|
| `workouts/data/datasources/workout_remote_datasource.dart` | select `assigned_by, assigned_note, assigned_at` + coach `display_name, avatar_url` (explicit columns — `profiles` rejects `select('*')`) |
| `workouts/domain/entities/workout_template.dart` | optional `assignedBy`, `coachName`, `coachAvatarUrl`, `assignedNote`, `assignedAt` |
| `dashboard/.../dashboard_screen.dart` | sort coach templates first; tag + "New" on `_PlanCard`; note in preview sheet |
| `workouts/.../workouts_screen.dart` | tag on `_TemplateRow` |
| `connect/...` repository + datasource | `sendWorkoutToAthlete(...)` |
| `connect/.../client_detail_screen.dart` | **Send workout** button + builder screen (new route under `/connect/hub/client/:id`) |

---

## 2. Coach tab cleanup

- **Done:** `_FeedbackCard` ("Latest feedback") removed from
  `connect_screen.dart`. The repository and `coaching_feedback` data are kept,
  so it can come back later.
- **To do:** remove `_CaptainHubEntry` ("Are you a coach?") from the Coach tab.
- **To do:** on `LoginScreen`, add the link **"Coach, gym, physical therapist
  or doctor? Sign in here"**. Same login; afterwards it routes to the Coach Hub
  instead of the Dashboard. A user with no coach profile lands on
  `CaptainProfileEditorScreen`.
- The "Assigned program" card stays for now. Once coaches send templates, it
  can be removed. That's a follow-up decision.

---

## 3. Marketplace (coaches, gyms, physical therapists, doctors)

### Database — `20261028120100_marketplace_listings.sql`

`marketplace_listings`. One row per listing:

- **Type:** `provider_type` = `coach | gym | physical_therapist | doctor`
- **Profile:** name, headline, description, specialties, logo
- **Contact:** phone, WhatsApp, email, website. At least one is required.
- **Location:** address, area, city, country (default `EG`), optional
  latitude/longitude, or `is_online_only`. A city is required unless the
  listing is online-only.
- **Status:** `pending → approved → suspended`. Only an admin changes status.
  When an owner edits contact details on an approved listing, it goes back to
  `pending` for review.
- **Access:** signed-in users see approved listings. Owners see and edit their
  own, and soft-delete via `deleted_at`. Admins can do everything.
- One live listing per owner per type. Admins can add a listing with no owner,
  e.g. a gym that isn't on Grit.

This is separate from coaching. Listing in the Marketplace doesn't create a
Captain relationship, and `coach_profiles` / `choose_captain` are unchanged.

### Athlete UI (to build)

`FindCaptainScreen` becomes the Marketplace:

- Type is chosen with **one button** next to the search field ("All types ▾").
  Tapping it opens a menu: **All · Coaches · Gyms · Physical therapists ·
  Doctors**. The current choice is checked and shown on the button. Same
  pattern as `_TypeMenuButton` in `find_captain_screen.dart`, not a row of
  chips. A city picker sits under the search row.
- List cards show: logo, name, type, headline, city/area, and contact
  buttons: **Call** (`tel:`), **WhatsApp** (`https://wa.me/`), **Email**,
  **Website**, **Directions** (maps link from lat/lng or address).
- These buttons need `url_launcher`, which is **not** in `pubspec.yaml` yet.

### Pro side (to build)

After coach sign-in: Coach Hub → **My listing** → create or edit. It shows
"Under review" until an admin approves it.

---

## 4. Not done / needs your OK

- **`supabase db push` has not been run.** Both migrations hit the live
  project. Docker wasn't running, so `supabase db reset` couldn't test them
  locally either. Run `supabase db reset` first, then push once you confirm.
- **Coupling note:** `workout_templates` (TRAIN) now records which coach sent
  a template. It only references `profiles`, which TRAIN already shares, but
  it's the first coaching field on a TRAIN table.
- **Old notification text:** the existing program-assignment trigger still says
  "Your Captain assigned you a program". It's unused once coaches send
  templates instead.
