# Gym App — Mobile (Flutter)

## Setup

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Create a Supabase project (free tier is fine for development) and enable
   **Email** auth and **Anonymous sign-ins** under
   Authentication → Providers.

3. Run with your Supabase credentials passed via `--dart-define` (never
   commit these):
   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://YOUR_PROJECT.supabase.co \
     --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY
   ```

   For repeated local runs, put these in a `.vscode/launch.json` or an
   untracked `run.sh` script rather than typing them each time.

## Testing the Auth flow

- **Guest Mode**: tap "Continue as Guest" on the login screen — starts an
  anonymous Supabase session and routes to the home placeholder.
- **Register**: tap "Sign Up", fill in email/password/confirm — creates a
  real Supabase account. If your Supabase project has email confirmation
  enabled, the user will need to confirm before `signInWithPassword` works
  (Supabase dashboard → Authentication → Providers → Email → toggle "Confirm
  email" off for faster local testing).
- **Login**: existing email/password account signs in and routes to home.
- **Forgot Password**: enter an email — Supabase sends a reset link (check
  Supabase dashboard → Authentication → Email Templates to see/customize
  what's sent). The screen shows a confirmation state either way (we don't
  reveal whether the email exists, for security).
- **Logout**: not yet wired to a UI button (no Profile/Settings screen
  exists yet) — call `ref.read(authStateProvider.notifier).signOut()` from
  anywhere once Profile is built. The use case and repository method are
  fully implemented and ready.

## Architecture

See `lib/features/auth/` for a full Clean Architecture reference — every
future feature (`dashboard`, `workouts`, `exercises`, `history`,
`statistics`, `profile`) should follow the same `data/domain/presentation`
shape, already scaffolded as empty folders.
