import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:gym_app/lib/core/widgets/scaffold_placeholder.dart';
import 'package:gym_app/lib/core/supabase/supabase_client.dart';
import '../../shared/widgets/motra_bottom_nav.dart';
import '../../features/roadmap/presentation/pages/roadmap_page.dart';
import '../../features/roadmap/presentation/pages/galaxy_page.dart';
import '../../features/roadmap/presentation/pages/planet_page.dart';
import '../../features/roadmap/presentation/pages/achievements_page.dart';
import 'package:gym_app/lib/features/auth/presentation/pages/splash_page.dart';
import 'package:gym_app/lib/features/auth/presentation/pages/login_page.dart';
import 'package:gym_app/lib/features/auth/presentation/pages/register_page.dart';
import '../../features/dashboard/presentation/pages/dashboard_page.dart';

/// Bridges a Stream (Supabase auth changes) into a [Listenable] so GoRouter
/// re-runs its `redirect` callback whenever auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Route paths. `friends` REMOVED — Connect pillar is deferred.
class AppRoutes {
  AppRoutes._();
  static const splash = '/';
  static const login = '/login';
  static const register = '/register';
  static const dashboard = '/dashboard';
  static const roadmap = '/roadmap';
  static const galaxy = '/roadmap/:galaxySlug';
  static const planet = '/roadmap/:galaxySlug/:planetSlug';
  static const achievements = '/achievements';
  static const profile = '/profile';
  static const start = '/start';
  static const workout = '/workout';
  static const templates = '/templates';
  static const templateBuilder = '/templates/new';

  static String galaxyFor(String slug) => '/roadmap/$slug';
  static String planetFor(String galaxySlug, String planetSlug) => '/roadmap/$galaxySlug/$planetSlug';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshStream = GoRouterRefreshStream(supabase.auth.onAuthStateChange);
  ref.onDispose(refreshStream.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    refreshListenable: refreshStream,
    redirect: (context, state) {
      final isAuthed = supabase.auth.currentSession != null;
      final loggingIn = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register;
      final onSplash = state.matchedLocation == AppRoutes.splash;

      if (!isAuthed && !loggingIn && !onSplash) return AppRoutes.login;
      if (isAuthed && (loggingIn || onSplash)) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterPage(),
      ),

      GoRoute(
        path: AppRoutes.galaxy,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => GalaxyPage(
          galaxySlug: state.pathParameters['galaxySlug']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.planet,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => PlanetPage(
          planetSlug: state.pathParameters['planetSlug']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.achievements,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AchievementsPage(),
      ),
      GoRoute(
        path: AppRoutes.workout,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ScaffoldPlaceholder(title: 'Workout Session'),
      ),
      GoRoute(
        path: AppRoutes.templateBuilder,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ScaffoldPlaceholder(title: 'New Template'),
      ),

      // Bottom-nav shell: Dashboard / Start / Roadmap / Profile.
      // `Friends` tab REMOVED (Connect deferred) — motra_bottom_nav.dart
      // needs its `_NavItem(AppRoutes.friends, ...)` line removed too,
      // see MIGRATION_NOTES.md.
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => MotraShell(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.dashboard,
            builder: (context, state) => const DashboardPage(),
          ),
          GoRoute(
            path: AppRoutes.roadmap,
            builder: (context, state) => const RoadmapPage(),
          ),
          GoRoute(
            path: AppRoutes.profile,
            builder: (context, state) => const ScaffoldPlaceholder(title: 'Profile'),
          ),
          GoRoute(
            path: AppRoutes.start,
            builder: (context, state) => const ScaffoldPlaceholder(title: 'Start'),
          ),
          GoRoute(
            path: AppRoutes.templates,
            builder: (context, state) => const ScaffoldPlaceholder(title: 'Templates'),
          ),
        ],
      ),
    ],
  );
});
