import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Who is signing up. Athlete is the default; the rest are the
/// professional account types (matching `provider_type` in the schema).
enum AccountType {
  athlete(
    label: 'Athlete',
    description: 'Train, track progress and work with a coach',
    icon: Icons.directions_run_rounded,
    tint: AppColors.authSky,
  ),
  coach(
    label: 'Coach',
    description: 'Build programs and guide your athletes',
    icon: Icons.sports_rounded,
    tint: AppColors.accentAction,
  ),
  gym(
    label: 'Gym',
    description: 'List your facility and reach new members',
    icon: Icons.fitness_center_rounded,
    tint: AppColors.success,
  ),
  doctor(
    label: 'Doctor',
    description: 'Sports medicine, orthopedics and more',
    icon: Icons.medical_services_rounded,
    tint: AppColors.error,
  ),
  physio(
    label: 'Physiotherapist',
    description: 'Help athletes recover and get back to training',
    icon: Icons.accessibility_new_rounded,
    tint: AppColors.info,
  );

  const AccountType({
    required this.label,
    required this.description,
    required this.icon,
    required this.tint,
  });

  final String label;
  final String description;
  final IconData icon;
  final Color tint;

  bool get isProfessional => this != AccountType.athlete;
}

/// "I'm joining as": a segmented tab (Athlete | Professional). Choosing
/// Professional reveals an iOS-style inset grouped list of the four
/// professional types — hairline separators inset past the icon, trailing
/// checkmark on the selected row — and a footer note.
class AccountTypePicker extends StatelessWidget {
  const AccountTypePicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AccountType value;
  final ValueChanged<AccountType> onChanged;

  static const double _iconTile = 32;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (final type in AccountType.values.where((t) => t.isProfessional)) {
      if (rows.isNotEmpty) {
        rows.add(
          const Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.md + _iconTile + AppSpacing.sm,
            ),
            child: Divider(
              height: 1,
              thickness: 1,
              color: AppColors.authCardBorder,
            ),
          ),
        );
      }
      rows.add(_row(type));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.md,
            bottom: AppSpacing.xs,
          ),
          child: Text(
            "I'M JOINING AS",
            style: AppTypography.labelMedium.copyWith(
              color: AppColors.authTextHint,
              letterSpacing: 0.6,
            ),
          ),
        ),
        _Segmented(
          professional: value.isProfessional,
          onChanged: (pro) {
            if (pro == value.isProfessional) return;
            HapticFeedback.selectionClick();
            onChanged(pro ? AccountType.coach : AccountType.athlete);
          },
        ),
        AnimatedSize(
          duration: AppConstants.animMedium,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: !value.isProfessional
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Semantics(
                    container: true,
                    label: 'Professional account type',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.authInputFill,
                          border: Border.all(color: AppColors.authInputBorder),
                          borderRadius: BorderRadius.circular(AppRadius.medium),
                        ),
                        child: Column(children: rows),
                      ),
                    ),
                  ),
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            0,
          ),
          child: AnimatedSwitcher(
            duration: AppConstants.animFast,
            child: Text(
              value.isProfessional
                  ? 'After sign-up you\'ll set up your ${value.label.toLowerCase()} '
                      'profile. Grit reviews it before athletes can see it.'
                  : 'Coaches, gyms, doctors and physios: choose Professional.',
              key: ValueKey(value.isProfessional),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.authTextHint,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(AccountType type) {
    final selected = type == value;
    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: () {
            if (selected) return;
            HapticFeedback.selectionClick();
            onChanged(type);
          },
          highlightColor: AppColors.pressed,
          splashFactory: NoSplash.splashFactory,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: _iconTile,
                  height: _iconTile,
                  decoration: BoxDecoration(
                    color: type.tint,
                    borderRadius: BorderRadius.circular(AppRadius.small),
                  ),
                  child: Icon(
                    type.icon,
                    size: AppSpacing.md + AppSpacing.xxs,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        type.label,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.white,
                          fontWeight: AppTypography.medium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs / 2),
                      Text(
                        type.description,
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.authTextHint,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                AnimatedScale(
                  scale: selected ? 1 : 0,
                  duration: AppConstants.animFast,
                  curve: Curves.easeOutBack,
                  child: const Icon(
                    Icons.check_rounded,
                    color: AppColors.authSky,
                    size: AppSpacing.lg - AppSpacing.xxs,
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


/// Two-segment control in the auth style.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.professional, required this.onChanged});

  final bool professional;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget segment(String label, bool isPro) {
      final selected = professional == isPro;
      return Expanded(
        child: Semantics(
          button: true,
          selected: selected,
          inMutuallyExclusiveGroup: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onChanged(isPro),
            child: AnimatedContainer(
              duration: AppConstants.animFast,
              curve: Curves.easeOut,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.authSky : AppColors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: selected ? AppColors.white : AppColors.authTextHint,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.authInputFill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.authInputBorder),
      ),
      child: Row(
        children: [
          segment('Athlete', false),
          segment('Professional', true),
        ],
      ),
    );
  }
}
