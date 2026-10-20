import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Shell wrapping every bottom-nav-bearing screen. Port of PhoneScreen's
/// per-page `<BottomNav />` + `<HomeIndicator />` composition, but as a
/// single persistent shell (GoRouter ShellRoute) instead of re-mounting
/// per page — avoids rebuilding the nav bar (and losing its animation
/// state) on every navigation the way the React version implicitly did.
class GritShell extends StatelessWidget {
  final Widget child;
  const GritShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: const GritBottomNav(),
    );
  }
}

class _NavItem {
  final String route;
  final String label;
  final IconData icon;
  final IconData activeIcon;
  const _NavItem(this.route, this.label, this.icon, this.activeIcon);
}

const _navItems = [
  _NavItem(AppRoutes.dashboard, 'Dashboard', Icons.home_outlined, Icons.home_rounded),
  _NavItem(AppRoutes.achievements, 'Achievements', Icons.emoji_events_outlined, Icons.emoji_events_rounded),
  _NavItem(AppRoutes.roadmap, 'Roadmap', Icons.change_history_outlined, Icons.change_history_rounded),
  _NavItem(AppRoutes.profile, 'Profile', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Floating rounded nav bar with a center "Start" button that pops above
/// the bar — direct port of BottomNav.jsx's glass pill + floating play FAB.
class GritBottomNav extends StatelessWidget {
  const GritBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
      child: SizedBox(
        height: 92,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [AppColors.glassFillTop, AppColors.glassFillBottom],
                      ),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: AppColors.glassBorder),
                      boxShadow: AppColors.shadowSoft,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _navButton(context, _navItems[0], location),
                        _navButton(context, _navItems[1], location),
                        const SizedBox(width: 62),
                        _navButton(context, _navItems[2], location),
                        _navButton(context, _navItems[3], location),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 58,
              child: _StartButton(active: location == AppRoutes.start),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navButton(BuildContext context, _NavItem item, String location) {
    final active = location == item.route;
    final color = active ? AppColors.primary : AppColors.textMuted;
    return InkWell(
      onTap: () => context.go(item.route),
      customBorder: const StadiumBorder(),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(active ? item.activeIcon : item.icon, color: color, size: 22),
            const SizedBox(height: 4),
            Text(
              item.label,
              style: AppTypography.small.copyWith(
                color: color,
                fontSize: 10,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  final bool active;
  const _StartButton({required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () => context.go(AppRoutes.start),
          customBorder: const CircleBorder(),
          child: Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF1A2030), AppColors.background],
              ),
              border: Border.all(color: AppColors.primary, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.8),
                  blurRadius: 32,
                  offset: const Offset(0, 16),
                  spreadRadius: -8,
                ),
              ],
            ),
            child: const Icon(Icons.play_arrow_rounded, color: AppColors.primary, size: 30),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'START',
          style: AppTypography.small.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}
