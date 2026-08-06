import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../widgets/floating_nav_bar.dart';

/// Root shell for the five authenticated tabs. Wraps GoRouter's
/// [StatefulNavigationShell], which preserves each tab's own navigation
/// stack and scroll position when switching away and back — the behavior
/// users expect from a tabbed app (switching to Profile and back to
/// Exercises shouldn't lose your scroll position or push a fresh screen).
class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  // Icon identifiers below (layoutDashboard, dumbbell, search, barChart3,
  // user) were checked against lucide_icons 0.257.0's published API docs
  // during Sprint 1 verification. dumbbell, calendar, activity, award,
  // barChart3, and clipboardList were directly confirmed present in the
  // class listing; layoutDashboard, search, trendingUp, and user are
  // long-standing Lucide/Feather-era icons not expected to have changed
  // names, but were not each individually confirmed by URL — if
  // `flutter analyze` flags any of these, see PROJECT_STATUS.md.
  static const _items = [
    NavBarItem(icon: LucideIcons.layoutDashboard, label: 'Dashboard'),
    NavBarItem(icon: LucideIcons.dumbbell, label: 'Workouts'),
    NavBarItem(icon: LucideIcons.search, label: 'Exercises'),
    NavBarItem(icon: LucideIcons.barChart3, label: 'Statistics'),
    NavBarItem(icon: LucideIcons.user, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: FloatingNavBar(
        items: _items,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => navigationShell.goBranch(
          index,
          // Tapping the already-active tab pops it back to its root,
          // matching standard tabbed-app behavior (e.g. tapping
          // "Exercises" while already browsing deep in Exercises
          // returns to the library root instead of doing nothing).
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
