import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Top bar of the dashboard: time-aware greeting + user name on the
/// left; a notification bell icon button on the right.
///
/// Animation: fades + slides in first on screen enter (see
/// DashboardScreen's stagger helper) per spec §15.
class GreetingHeader extends StatelessWidget {
  const GreetingHeader({
    required this.userName,
    this.unreadNotifications = 0,
    super.key,
  });

  final String userName;

  /// Number of unread notifications. When > 0 an orange dot is shown
  /// on the bell icon top-right. 0 = no dot (spec §10).
  final int unreadNotifications;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 18) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // ── Greeting + name ─────────────────────────────────────────────
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greeting,
                style: AppTypography.bodyMedium.copyWith(
                  fontSize: 15,
                  color: AppColors.textSecondary,
                  fontWeight: AppTypography.regular,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    userName,
                    style: AppTypography.headlineLarge.copyWith(
                      fontSize: 26,
                      fontWeight: AppTypography.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  const Text('👋', style: TextStyle(fontSize: 22)),
                ],
              ),
            ],
          ),
        ),

        // ── Notification bell ────────────────────────────────────────────
        _NotificationBell(unread: unreadNotifications),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification bell icon button
// ─────────────────────────────────────────────────────────────────────────────

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.unread});

  final int unread;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.bellButton),
          border: Border.all(color: AppColors.cardBorder, width: 1),
        ),
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            const Icon(
              LucideIcons.bell,
              size: AppSizing.iconMd,
              color: AppColors.textSecondary,
            ),
            if (unread > 0)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.streakFlameStart,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.background, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
