import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../sample/achievements_sample_data.dart';
import 'achievement_badge.dart';

/// Opens the achievement detail sheet (design/canvas: ach/Detail).
Future<void> showAchievementDetail(BuildContext context, Achievement a) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.transparent,
    barrierColor: AppColors.achScrim,
    builder: (_) => AchievementDetailSheet(achievement: a),
  );
}

class AchievementDetailSheet extends StatelessWidget {
  const AchievementDetailSheet({required this.achievement, super.key});

  final Achievement achievement;

  static const double _badgeSize = 170;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final palette = a.rarity.palette;
    final earned = a.isEarned;
    final String status;
    if (earned && a.earnedOn != null) {
      status = 'Earned ${DateFormat('d MMMM y').format(a.earnedOn!)}';
    } else if (a.state == AchievementState.inProgress) {
      status = 'In progress';
    } else {
      status = 'Locked';
    }
    final progressText = earned
        ? 'Complete'
        : a.progressLabel ?? '${(a.progress * 100).round()}%';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.88,
      ),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
        border: Border(top: BorderSide(color: AppColors.hubNavBorder)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.achSheetTop, AppColors.achSheetInset],
          stops: [0, 0.6],
        ),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md + 4,
            AppSpacing.sm - 2,
            AppSpacing.md + 4,
            AppSpacing.lg,
          ),
          child: Column(
            children: [
              Container(
                width: AppSpacing.xl + AppSpacing.xxs + 2,
                height: AppSpacing.xxs,
                decoration: BoxDecoration(
                  color: AppColors.achHandle,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              const SizedBox(height: AppSpacing.md - 2),
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (earned)
                    IgnorePointer(
                      child: Container(
                        width: _badgeSize * 1.5,
                        height: _badgeSize * 1.5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              palette.glow.withValues(alpha: 0.28),
                              palette.glow.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.62],
                          ),
                        ),
                      ),
                    ),
                  AchievementBadge(
                    achievement: a,
                    size: _badgeSize,
                    animated: true,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                a.title,
                textAlign: TextAlign.center,
                style: AppTypography.headlineLarge
                    .copyWith(color: AppColors.achText),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RarityHex(color: palette.label),
                  const SizedBox(width: AppSpacing.xxs + 2),
                  Text(
                    a.rarity.label,
                    style: AppTypography.labelLarge.copyWith(
                      color: palette.label,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm - 2),
                  Text(
                    status,
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.achTextMuted),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md - 2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  a.description,
                  textAlign: TextAlign.center,
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.phaseTextBody,
                    fontWeight: AppTypography.regular,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md + 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.achSheet,
                  borderRadius: BorderRadius.circular(AppRadius.hubCard),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Requirement',
                            style: AppTypography.bodyMedium
                                .copyWith(color: AppColors.achTextMuted),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              a.requirement,
                              textAlign: TextAlign.right,
                              style: AppTypography.bodyMedium
                                  .copyWith(color: AppColors.achText),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.divider),
                    Padding(
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Progress',
                                  style: AppTypography.bodyMedium
                                      .copyWith(color: AppColors.achTextMuted),
                                ),
                              ),
                              Text(
                                progressText,
                                style: AppTypography.numeric(
                                  AppTypography.bodyMedium,
                                ).copyWith(
                                  color: AppColors.achText,
                                  fontWeight: AppTypography.semiBold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: LinearProgressIndicator(
                              value: earned ? 1 : a.progress,
                              minHeight: AppSpacing.xxs,
                              backgroundColor: AppColors.achTrack,
                              valueColor:
                                  AlwaysStoppedAnimation(palette.accent),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (a.category == AchievementCategory.skills) ...[
                const SizedBox(height: AppSpacing.sm),
                _LinkRow(
                  icon: LucideIcons.orbit,
                  title: 'Skill roadmap',
                  subtitle: 'Galaxy I · Calisthenics universe',
                  onTap: () {
                    final router = GoRouter.of(context);
                    Navigator.of(context).pop();
                    router.go(AppRoutes.universe);
                  },
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                height: AppSizing.buttonHeight,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.phaseButton,
                    foregroundColor: AppColors.phaseInk,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium + 2),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Done',
                    style: AppTypography.button.copyWith(
                      color: AppColors.phaseInk,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.hubCard);
    return Material(
      color: AppColors.achSheet,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.divider),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md - 2,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Icon(icon, size: AppSizing.iconLg, color: AppColors.gameBlueLight),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleSmall
                          .copyWith(color: AppColors.achText),
                    ),
                    Text(
                      subtitle,
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.achTextMuted),
                    ),
                  ],
                ),
              ),
              const Icon(
                LucideIcons.chevronRight,
                size: AppSizing.iconSm,
                color: AppColors.achTextMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small hexagon swatch in a rarity colour.
class RarityHex extends StatelessWidget {
  const RarityHex({required this.color, this.size = 11, super.key});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(size, size * 12 / 11),
      painter: _HexSwatch(color),
    );
  }
}

class _HexSwatch extends CustomPainter {
  _HexSwatch(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width / 2, 0)
      ..lineTo(s.width, s.height * 0.25)
      ..lineTo(s.width, s.height * 0.75)
      ..lineTo(s.width / 2, s.height)
      ..lineTo(0, s.height * 0.75)
      ..lineTo(0, s.height * 0.25)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_HexSwatch old) => old.color != color;
}
