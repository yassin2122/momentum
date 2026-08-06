import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_state_notifier.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/exercises/presentation/screens/exercises_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/statistics/presentation/screens/statistics_screen.dart';
import '../../features/workouts/presentation/screens/workouts_screen.dart';
import '../constants/app_constants.dart';
import '../widgets/loading_overlay.dart';
import 'app_shell.dart';

/// App-wide router, gated by auth state.
///
/// This is the composition root for navigation — it's the one place
/// allowed to depend on a feature's presentation layer directly, since its
/// entire job is wiring features together into a navigable app.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthRefreshNotifier(ref),
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
      final isLoading = authState.isLoading && !authState.hasValue;
      final isAuthRoute = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.forgotPassword;

      if (isLoading) return null; // stay on splash until session resolves
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
        pageBuilder: (context, state) =>
            _fadePage(state, const _SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) =>
            _fadePage(state, const LoginScreen()),
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
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
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
              GoRoute(
                path: AppRoutes.workouts,
                pageBuilder: (context, state) =>
                    _fadePage(state, const WorkoutsScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.exercises,
                pageBuilder: (context, state) =>
                    _fadePage(state, const ExercisesScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.statistics,
                pageBuilder: (context, state) =>
                    _fadePage(state, const StatisticsScreen()),
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
/// state changes (login, logout, guest session started, etc.).
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(this._ref) {
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: LoadingOverlay(isLoading: true, child: SizedBox.expand()),
    );
  }
}
