import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../gyms/presentation/providers/gym_providers.dart';
import '../../../gyms/presentation/widgets/gym_ui.dart';
import '../../../health/domain/entities/health_entities.dart';
import '../../../health/presentation/providers/health_providers.dart';
import '../../domain/entities/connect_entities.dart';
import '../providers/connect_providers.dart';

/// The four ways to work on Grit — Coach, Gym, Doctor, Physiotherapist —
/// opened from Profile → "Join Grit as a pro". Each option either starts
/// setup or opens what the user already runs.
Future<void> showProJoinSheet(BuildContext context) =>
    showGymSheet<void>(context, const _ProJoinSheet());

class _ProJoinSheet extends ConsumerWidget {
  const _ProJoinSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hub = ref.watch(captainHubProvider).valueOrNull;
    final gyms = ref.watch(myGymsProvider).valueOrNull ?? const [];
    final health = ref.watch(myHealthProfilesProvider).valueOrNull ?? const [];
    MyHealthProfile? healthOf(HealthKind k) => health.where((h) => h.kind == k).firstOrNull;

    void open(String location) {
      final router = GoRouter.of(context);
      Navigator.of(context).pop();
      router.push(location);
    }

    Widget? statusFor(MyHealthProfile? h) => h == null
        ? null
        : GymStatusPill(
            switch (h.state) {
              HealthProfileState.draft => 'Draft',
              HealthProfileState.inReview => 'In review',
              HealthProfileState.live => 'Live',
              HealthProfileState.hidden => 'Hidden',
              HealthProfileState.suspended => 'Suspended',
            },
            tone: h.state == HealthProfileState.live ? GymTone.positive : GymTone.neutral,
          );

    final doctor = healthOf(HealthKind.doctor);
    final physio = healthOf(HealthKind.physio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GymSheetHeader(
          title: 'Work with Grit',
          subtitle: 'Pick how you\'d like to be listed. You can have more than one.',
        ),
        GymSection(
          children: [
            _Option(
              icon: LucideIcons.clipboardList,
              title: 'Coach',
              subtitle: hub == null
                  ? 'Coach athletes on Grit, free with your clients'
                  : 'Open your Coach Hub',
              trailing: hub == null
                  ? null
                  : GymStatusPill(
                      hub.status == CoachStatus.approved ? 'Active' : hub.status == CoachStatus.pending ? 'In review' : 'Suspended',
                      tone: hub.status == CoachStatus.approved ? GymTone.positive : GymTone.neutral,
                    ),
              onTap: () => open(AppRoutes.captainHub),
            ),
            _Option(
              icon: LucideIcons.dumbbell,
              title: 'Gym',
              subtitle: gyms.isEmpty
                  ? 'List your gym, add your coaches, answer people who want to join'
                  : gyms.length == 1
                      ? 'Open ${gyms.first.name}'
                      : 'Open your ${gyms.length} gyms',
              trailing: gyms.isEmpty ? null : const GymStatusPill('Active', tone: GymTone.positive),
              onTap: () => open(AppRoutes.myGyms),
            ),
            _Option(
              icon: LucideIcons.stethoscope,
              title: 'Doctor',
              subtitle: doctor == null
                  ? 'Sports medicine, orthopedics and more'
                  : 'Edit your doctor profile',
              trailing: statusFor(doctor),
              onTap: () => open(doctor == null
                  ? AppRoutes.healthProSetupPath(HealthKind.doctor.dbValue)
                  : AppRoutes.healthProEditorPath(doctor.listingId)),
            ),
            _Option(
              icon: LucideIcons.activity,
              title: 'Physiotherapist',
              subtitle: physio == null
                  ? 'Sports and post-injury rehabilitation'
                  : 'Edit your physiotherapist profile',
              trailing: statusFor(physio),
              onTap: () => open(physio == null
                  ? AppRoutes.healthProSetupPath(HealthKind.physio.dbValue)
                  : AppRoutes.healthProEditorPath(physio.listingId)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Every profile is reviewed by Grit before it appears to athletes.',
          textAlign: TextAlign.center,
          style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextFaint),
        ),
      ],
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GymRow(
      leading: Container(
        width: AppSizing.minTouchTarget - 4,
        height: AppSizing.minTouchTarget - 4,
        decoration: BoxDecoration(
          color: AppColors.hubHeroGlow,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Icon(icon, size: AppSizing.iconMd, color: AppColors.hubSkyLight),
      ),
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      showChevron: true,
      onTap: onTap,
    );
  }
}
