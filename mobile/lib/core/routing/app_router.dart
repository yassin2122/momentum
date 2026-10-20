import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../features/auth/presentation/providers/auth_state_notifier.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/achievements/presentation/screens/achievement_unlock_screen.dart';
import '../../features/achievements/presentation/screens/achievements_screen.dart';
import '../../features/connect/presentation/screens/captain_hub_screen.dart';
import '../../features/connect/presentation/screens/captain_profile_editor_screen.dart';
import '../../features/connect/presentation/screens/captain_profile_screen.dart';
import '../../features/connect/presentation/screens/client_detail_screen.dart';
import '../../features/connect/presentation/screens/connect_screen.dart';
import '../../features/connect/presentation/screens/find_captain_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/exercises/presentation/screens/exercises_screen.dart';
import '../../features/muscle_map/presentation/screens/muscle_map_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/progress/presentation/screens/planet_screen.dart';
import '../../features/progress/presentation/screens/skill_screen.dart';
import '../../features/workouts/domain/services/workout_finalizer.dart';
import '../../features/workouts/presentation/screens/active_workout_screen.dart';
import '../../features/workouts/presentation/screens/create_template_screen.dart';
import '../../features/workouts/presentation/screens/workout_summary_screen.dart';
import '../../features/workouts/presentation/screens/workouts_screen.dart';
import '../constants/app_constants.dart';
import '../widgets/coming_soon_screen.dart';
import 'app_shell.dart';

/// App-wide router, gated by auth state.
///
/// This is the composition root for navigation — it's the one place
/// allowed to depend on a feature's presentation layer directly, since its
/// entire job is wiring features together into a navigable app.
final appRouterProvider = Provider<GoRouter>((ref) {
  // Do NOT watch authStateProvider here — watching would cause a new GoRouter
  // to be constructed on every auth change, leaving MaterialApp.router with a
  // stale instance. Instead, read the current state inside the redirect closure
  // each time GoRouter asks for it (triggered by _AuthRefreshNotifier).
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isLoggedIn = authState.valueOrNull != null;
      final isLoading = authState.isLoading && !authState.hasValue;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword;

      if (isLoading) return null; // stay on splash until session resolves

      // An opened reset link grants a recovery session; hold the user on
      // the set-new-password screen until they finish or cancel.
      final isRecovering = isLoggedIn && ref.read(passwordRecoveryProvider);
      final onResetRoute = state.matchedLocation == AppRoutes.resetPassword;
      if (isRecovering) return onResetRoute ? null : AppRoutes.resetPassword;
      if (onResetRoute) return isLoggedIn ? AppRoutes.dashboard : AppRoutes.login;

      // Hold on the splash route until its intro animation has played.
      if (state.matchedLocation == AppRoutes.splash &&
          !ref.read(splashCompleteProvider)) {
        return null;
      }
      if (!isLoggedIn && !isAuthRoute) return AppRoutes.login;
      if (isLoggedIn &&
          (isAuthRoute || state.matchedLocation == AppRoutes.splash)) {
        return AppRoutes.dashboard;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _fadePage(state, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _fadePage(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) =>
            _fadePage(state, const RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        pageBuilder: (context, state) =>
            _fadePage(state, const ForgotPasswordScreen()),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        pageBuilder: (context, state) =>
            _fadePage(state, const ResetPasswordScreen()),
      ),
      GoRoute(
        path: AppRoutes.captainProfile,
        pageBuilder: (context, state) => _fadePage(
          state,
          CaptainProfileScreen(coachId: state.pathParameters['coachId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.planet,
        pageBuilder: (context, state) => _fadePage(
          state,
          PlanetScreen(planetId: state.pathParameters['planetId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.skill,
        pageBuilder: (context, state) => _fadePage(
          state,
          SkillScreen(skillId: state.pathParameters['skillId']!),
        ),
      ),
      GoRoute(
        path: AppRoutes.achievementUnlock,
        pageBuilder: (context, state) => _fadePage(
          state,
          AchievementUnlockScreen(
            achievementId: state.pathParameters['achievementId']!,
          ),
        ),
      ),
      GoRoute(
        path: AppRoutes.muscleMap,
        pageBuilder: (context, state) =>
            _fadePage(state, const MuscleMapScreen()),
      ),
      GoRoute(
        path: AppRoutes.activeWorkout,
        pageBuilder: (context, state) =>
            _fadePage(state, const ActiveWorkoutScreen()),
      ),
      GoRoute(
        path: AppRoutes.exercises,
        pageBuilder: (context, state) =>
            _fadePage(state, const ExercisesScreen()),
      ),
      GoRoute(
        path: AppRoutes.createTemplate,
        pageBuilder: (context, state) =>
            _fadePage(state, const CreateTemplateScreen()),
      ),
      GoRoute(
        path: AppRoutes.workoutSummary,
        // The summary only exists in memory; after a reload there's
        // nothing to show, so fall back to the Workouts tab.
        redirect: (context, state) =>
            state.extra is WorkoutSummary ? null : AppRoutes.train,
        pageBuilder: (context, state) => _fadePage(
          state,
          WorkoutSummaryScreen(summary: state.extra! as WorkoutSummary),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        // Order must match GritNavBar.items.
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                pageBuilder: (context, state) =>
                    _fadePage(state, const DashboardScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              // Coach tab — the athlete's Captain, plus the Captain Hub
              // for users who coach. Sub-routes keep the nav bar.
              GoRoute(
                path: AppRoutes.connect,
                pageBuilder: (context, state) =>
                    _fadePage(state, const ConnectScreen()),
                routes: [
                  GoRoute(
                    path: 'find',
                    pageBuilder: (context, state) =>
                        _fadePage(state, const FindCaptainScreen()),
                  ),
                  GoRoute(
                    path: 'hub',
                    pageBuilder: (context, state) =>
                        _fadePage(state, const CaptainHubScreen()),
                    routes: [
                      GoRoute(
                        path: 'profile',
                        pageBuilder: (context, state) => _fadePage(
                            state, const CaptainProfileEditorScreen()),
                      ),
                      GoRoute(
                        path: 'client/:relationshipId',
                        pageBuilder: (context, state) => _fadePage(
                          state,
                          ClientDetailScreen(
                            relationshipId:
                                state.pathParameters['relationshipId']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.train,
                pageBuilder: (context, state) =>
                    _fadePage(state, const WorkoutsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              // Universe tab — placeholder until the skill galaxies ship.
              GoRoute(
                path: AppRoutes.progress,
                pageBuilder: (context, state) => _fadePage(
                  state,
                  const ComingSoonScreen(
                    icon: LucideIcons.orbit,
                    eyebrow: 'Universe',
                    title: 'Coming soon',
                    message: 'Skill galaxies, roadmaps and certifications.',
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'achievements',
                    pageBuilder: (context, state) =>
                        _fadePage(state, const AchievementsScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                pageBuilder: (context, state) =>
                    _fadePage(state, const ProfileScreen()),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Standard ~250ms fade transition used for every route in the app, per
/// DESIGN_SYSTEM.md's Standard Animation Timing (`animMedium`) — kept as
/// a raw literal here rather than importing AppConstants to avoid a
/// routing → constants → routing import cycle risk; matches
/// AppConstants.pageTransition (250ms) exactly.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 250),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: child,
      );
    },
  );
}

/// Bridges Riverpod's [authStateProvider] to GoRouter's [Listenable]-based
/// refresh mechanism, so the router re-evaluates `redirect` whenever auth
/// state changes (login, logout, guest session started, reset link opened).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(splashCompleteProvider, (_, __) => notifyListeners());
    _ref.listen(passwordRecoveryProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}
