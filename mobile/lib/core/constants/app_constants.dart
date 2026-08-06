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
}

/// Route path constants, referenced by [AppRouter] and any widget that
/// navigates — avoids typo-prone raw path strings scattered in the UI.
abstract final class AppRoutes {
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Shell tabs
  static const String dashboard = '/dashboard';
  static const String workouts = '/workouts';
  static const String exercises = '/exercises';
  static const String statistics = '/statistics';
  static const String profile = '/profile';
}
