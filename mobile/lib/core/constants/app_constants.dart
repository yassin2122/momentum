/// App-wide constant values. Anything that could otherwise be a magic
/// number/string scattered across the codebase belongs here.
abstract final class AppConstants {
  static const String appName = 'Grit';

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
  static const String authRedirectUrl = 'io.grit.app://login-callback/';

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

  /// Second sign-in step for accounts with two-factor auth.
  static const String mfaVerify = '/mfa';

  /// Profile > Two-factor authentication settings.
  static const String twoFactor = '/security/two-factor';

  // Shell tabs — Dashboard, Coach, START (Train), Universe, Profile.
  // Order matches AppShell / the branches in app_router.dart.
  static const String dashboard = '/dashboard';
  static const String connect = '/connect';
  static const String train = '/train';
  static const String progress = '/progress';
  static const String profile = '/profile';

  /// The centre START button opens the Train branch.
  static const String start = train;

  // CONNECT — inside the Coach tab (the nav bar stays visible).
  static const String findCaptain = '/connect/find';

  /// The coach's side: requests, clients, invites, own profile.
  static const String captainHub = '/connect/hub';

  /// Create or edit the signed-in user's Captain profile.
  static const String captainHubProfile = '/connect/hub/profile';

  /// One coached athlete, by coaching relationship id.
  static const String captainClient = '/connect/hub/client/:relationshipId';
  static String captainClientPath(String relationshipId) =>
      '/connect/hub/client/$relationshipId';

  // CONNECT — full-screen
  static const String captainProfile = '/captain/:coachId';
  static String captainProfilePath(String coachId) => '/captain/$coachId';

  // GYMS — Find a gym keeps the nav bar (Coach tab); a gym page, the gym
  // dashboard and its editors are full-screen.
  static const String findGym = '/connect/gyms';

  /// Captain Hub → Gyms (invitations, affiliations, AI allowance).
  static const String coachGyms = '/connect/hub/gyms';

  static const String gymDetail = '/gym/:gymId';
  static String gymDetailPath(String gymId) => '/gym/$gymId';

  /// Profile → Your gyms (dashboards, register, join a team).
  static const String myGyms = '/gyms';
  static const String gymRegister = '/gyms/new';

  static const String gymAdmin = '/gym-admin/:gymId';
  static String gymAdminPath(String gymId) => '/gym-admin/$gymId';
  static const String gymAdminBranches = '/gym-admin/:gymId/branches';
  static String gymAdminBranchesPath(String gymId) => '/gym-admin/$gymId/branches';
  static const String gymAdminAi = '/gym-admin/:gymId/ai';
  static String gymAdminAiPath(String gymId) => '/gym-admin/$gymId/ai';

  // HEALTH — doctors & physiotherapists (discovery only, no booking).
  // Find a health pro and Saved keep the nav bar (Coach tab).
  static const String healthMarketplace = '/connect/health';
  static const String savedProviders = '/connect/health/saved';
  static const String healthProvider = '/health/:listingId';
  static String healthProviderPath(String listingId) => '/health/$listingId';

  /// Provider side: set up (`?kind=doctor|physical_therapist`) and edit.
  static const String healthProSetup = '/health-pro/new';
  static String healthProSetupPath(String kind) => '/health-pro/new?kind=$kind';
  static const String healthProEditor = '/health-pro/:listingId';
  static String healthProEditorPath(String listingId) => '/health-pro/$listingId';

  /// First-time setup in four steps, right after creating the profile.
  static String healthProOnboardingPath(String listingId) => '/health-pro/$listingId/setup';

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

  /// Athlete Analytics hub (the Dashboard's Analytics button).
  static const String analytics = '/analytics';
  static const String analyticsDistribution = '/analytics/distribution';
  static const String analyticsBody = '/analytics/body';
  static const String analyticsRecovery = '/analytics/recovery';

  /// Full-screen muscle hologram (opened from Analytics).
  static const String muscleMap = '/muscles';
  static const String workoutSummary = '/workout/summary';

  /// Searchable, filterable exercise library (opened from the Train tab).
  static const String exercises = '/exercises';

  /// Build a new workout template from scratch.
  static const String createTemplate = '/templates/new';
}
