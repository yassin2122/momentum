import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/dashboard/presentation/widgets/start_workout_actions.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../widgets/grit_nav_bar.dart';

/// Root shell for the five tabs — Dashboard, Coach, START (Train),
/// Universe, Profile. Wraps GoRouter's [StatefulNavigationShell], which
/// preserves each tab's own navigation stack and scroll position when
/// switching away and back.
///
/// Coach and Universe are "Coming soon" placeholders for now.
///
/// The centre START button opens a sheet instead of switching tabs:
/// today's recommended template first, the other templates under it, plus
/// free workout and "New template".
///
/// Slot order must match the branch order in `app_router.dart`.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) => navigationShell.goBranch(
        index,
        // Tapping the already-active tab pops it back to its root,
        // matching standard tabbed-app behavior.
        initialLocation: index == navigationShell.currentIndex,
      );

  void _onTap(BuildContext context, WidgetRef ref, int index) {
    HapticFeedback.selectionClick();
    if (index != GritNavBar.startIndex) {
      _goBranch(index);
      return;
    }
    showStartSheet(
      context,
      onResume: () => context.push(AppRoutes.activeWorkout),
      onStartTemplate: (t) => startTemplateWorkout(context, ref, t),
      onFree: () => startFreeWorkout(context, ref),
      onCreateTemplate: () => context.push(AppRoutes.createTemplate),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // Same near-black as the hub canvas, so nothing grey shows around
      // the floating bar or during a tab's first fade-in.
      backgroundColor: AppColors.hubBackgroundBottom,
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: GritNavBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTap(context, ref, index),
      ),
    );
  }
}
