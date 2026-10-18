import 'dart:ui';

import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';
import '../theme/app_sizing.dart';

class NavBarItem {
  const NavBarItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Floating, rounded, translucent bottom navigation bar. Deliberately not
/// a standard Material [NavigationBar] — it floats above content with
/// margin on all sides and a blurred glass background, matching the
/// Apple Fitness-inspired premium feel called for in DESIGN_SYSTEM.md.
///
/// Tab switches don't animate the underlying page content (each tab
/// preserves its own navigation state via GoRouter's
/// StatefulShellRoute.indexedStack — an instant switch is the correct,
/// expected behavior there, matching how Apple Fitness itself behaves).
/// What *does* animate smoothly here is the selection state itself: the
/// active icon's color/scale and the indicator dot beneath it.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  final List<NavBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            height: AppSizing.navBarHeight,
            decoration: BoxDecoration(
              color: AppColors.navBarBackground,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(color: AppColors.stroke, width: 1),
              boxShadow: AppShadows.floating,
            ),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavBarButton(
                      item: items[i],
                      isSelected: i == currentIndex,
                      onTap: () => onTap(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarButton extends StatelessWidget {
  const _NavBarButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final NavBarItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color =
        isSelected ? AppColors.navBarSelected : AppColors.navBarUnselected;

    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              duration: AppConstants.animInstant,
              scale: isSelected ? 1.08 : 1.0,
              child: AnimatedContainer(
                duration: AppConstants.animInstant,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                child: Icon(item.icon, size: AppSizing.iconMd, color: color),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            AnimatedDefaultTextStyle(
              duration: AppConstants.animInstant,
              style: AppTypography.caption.copyWith(color: color),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
