/// App-wide constant values. Anything that could otherwise be a magic
/// number/string scattered across the codebase belongs here.
abstract final class AppConstants {
  static const String appName = 'Gym App';

  // Standard animation timing — see DESIGN_SYSTEM.md's canonical table.
  static const Duration animInstant = Duration(milliseconds: 100);
  static const Duration animFast = Duration(milliseconds: 150);
  static const Duration animMedium = Duration(milliseconds: 300);
  static const Duration animSlow = Duration(milliseconds: 500);
  static const Duration animShimmer = Duration(milliseconds: 1200);

  // Page transitions
  static const Duration pageTransition = Duration(milliseconds: 250);

  // Validation rules
  static const int minPasswordLength = 8;

  // Local storage keys
  static const String keyIsGuest = 'is_guest_session';
  static const String keyHasSeenOnboarding = 'has_seen_onboarding';

  // Deep-link / OAuth redirect URL registered in AndroidManifest.xml and
  // iOS Info.plist.  Supabase will redirect here after OAuth / magic-link flows.
  static const String authRedirectUrl = 'io.momentum.app://login-callback/';

  // Base URL for exercise images. exercises.images holds paths relative to
  // free-exercise-db's exercises/ folder (e.g. "Air_Bike/0.jpg").
  static const String exerciseImageBaseUrl =
      'https://raw.githubusercontent.com/yuhonas/free-exercise-db/main/exercises/';
}

/// Route path constants, referenced by [AppRouter] and any widget that
/// navigates — avoids typo-prone raw path strings scattered in the UI.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  /// Set-new-password screen, reached from the reset-email deep link.
  static const String resetPassword = '/reset-password';

  // Shell tabs — Dashboard, Coach, START (Train), Universe, Profile.
  // Order matches AppShell / the branches in app_router.dart.
  static const String dashboard = '/dashboard';
  static const String connect = '/connect';
  static const String train = '/train';
  static const String progress = '/progress';
  static const String profile = '/profile';

  /// The centre START button opens the Train branch.
  static const String start = train;

  // CONNECT — inside the Coach tab. Not routed while the Coach tab is a
  // "Coming soon" placeholder; kept so the connect feature still compiles.
  static const String findCaptain = '/connect/find';

  // CONNECT — full-screen
  static const String captainProfile = '/captain/:coachId';
  static String captainProfilePath(String coachId) => '/captain/$coachId';

  // PROGRESS — inside the Universe tab. While the tab is a "Coming soon"
  // placeholder, `universe` points at the tab root so existing links
  // (Dashboard, Profile) land there instead of a dead route.
  static const String universe = progress;
  static const String achievements = '/progress/achievements';

  /// Skill roadmap entry point (the galaxy's planets).
  static const String roadmap = universe;

  // PROGRESS — full-screen
  static const String planet = '/planet/:planetId';
  static String planetPath(String planetId) => '/planet/$planetId';
  static const String skill = '/skill/:skillId';
  static String skillPath(String skillId) => '/skill/$skillId';
  static const String achievementUnlock = '/achievement/:achievementId/unlock';
  static String achievementUnlockPath(String id) => '/achievement/$id/unlock';

  // TRAIN — full-screen, outside the tab shell
  static const String activeWorkout = '/workout';

  /// Full-screen muscle activity map (opened from the Dashboard).
  static const String muscleMap = '/muscles';
  static const String workoutSummary = '/workout/summary';

  /// Build a new workout template from scratch.
  static const String createTemplate = '/templates/new';
}
