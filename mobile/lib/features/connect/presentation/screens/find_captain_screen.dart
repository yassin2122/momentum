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
import '../../domain/entities/connect_entities.dart';
import '../providers/connect_providers.dart';

/// Coach tab → "Find coaches": the live coach directory with search and
/// specialty filters.
class FindCaptainScreen extends ConsumerStatefulWidget {
  const FindCaptainScreen({super.key});

  @override
  ConsumerState<FindCaptainScreen> createState() => _FindCaptainScreenState();
}

class _FindCaptainScreenState extends ConsumerState<FindCaptainScreen> {
  final _search = TextEditingController();
  String _query = '';
  String? _specialty;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool _matches(CoachDirectoryEntry c) {
    if (_specialty != null && !c.specialties.contains(_specialty)) {
      return false;
    }
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final haystack = [
      c.displayName,
      c.username,
      c.headline,
      ...c.specialties,
    ].whereType<String>().join(' ').toLowerCase();
    return haystack.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(coachDirectoryProvider(null));
    final myCoachId =
        ref.watch(myCaptainProvider).valueOrNull?.relationship.coachId;

    final all = directory.valueOrNull ?? const <CoachDirectoryEntry>[];
    final specialties = <String>{for (final c in all) ...c.specialties}.toList()
      ..sort();

    return HubPage(
      glowCenter: const Alignment(-0.6, -0.9),
      children: [
        Row(
          children: [
            HubBackButton(
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.connect),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HubEyebrow('Coach hub'),
                  Text(
                    'Find a Coach',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.hubTextBright,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        _SearchField(
          controller: _search,
          onChanged: (v) => setState(() => _query = v),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          height: AppSizing.minTouchTarget - AppSpacing.xs - 2,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _FilterChip(
                label: 'All',
                selected: _specialty == null,
                onTap: () => setState(() => _specialty = null),
              ),
              for (final s in specialties)
                _FilterChip(
                  label: s,
                  selected: _specialty == s,
                  onTap: () => setState(() => _specialty = s),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        ...directory.when(
          loading: () => const [HubLoading()],
          error: (e, _) => [
            HubMessageCard(
              icon: LucideIcons.wifiOff,
              title: "Couldn't load coaches",
              message: connectErrorMessage(e),
              actionLabel: 'Retry',
              onAction: () => ref.invalidate(coachDirectoryProvider(null)),
            ),
          ],
          data: (list) {
            final shown = list.where(_matches).toList();
            if (shown.isEmpty) {
              return [
                HubMessageCard(
                  icon: LucideIcons.search,
                  title: list.isEmpty ? 'No coaches yet' : 'No matches',
                  message: list.isEmpty
                      ? 'Approved coaches will show up here.'
                      : 'Try a different name or skill.',
                ),
              ];
            }
            return [
              for (final c in shown) ...[
                _CoachCard(coach: c, isMine: c.coachId == myCoachId),
                const SizedBox(height: AppSpacing.sm - 2),
              ],
            ];
          },
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      borderSide: const BorderSide(color: AppColors.authInputBorder),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppTypography.titleSmall.copyWith(color: AppColors.hubTextBright),
      cursorColor: AppColors.hubEyebrow,
      decoration: InputDecoration(
        hintText: 'Search by name or skill',
        hintStyle:
            AppTypography.titleSmall.copyWith(color: AppColors.hubTextMuted),
        prefixIcon: const Icon(
          LucideIcons.search,
          size: AppSizing.iconSm + 2,
          color: AppColors.hubTextMuted,
        ),
        filled: true,
        fillColor: AppColors.authInputFill,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: const BorderSide(color: AppColors.hubRing),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? AppColors.hubHeroGlow : AppColors.authInputFill,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? AppColors.hubRing : AppColors.authInputBorder,
            ),
          ),
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md - 2),
              child: Center(
                child: Text(
                  label,
                  style: AppTypography.labelMedium.copyWith(
                    color: selected
                        ? AppColors.hubTextBright
                        : AppColors.hubTextBody,
                    fontWeight:
                        selected ? AppTypography.semiBold : AppTypography.medium,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CoachCard extends StatelessWidget {
  const _CoachCard({required this.coach, required this.isMine});

  final CoachDirectoryEntry coach;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final name = coach.displayName ?? coach.username ?? 'Coach';
    final specialties = coach.specialties.take(2).join(' · ');
    final years = coach.experienceYears;
    final meta = [
      if (years != null) '$years yrs coaching',
      '${coach.athleteCount} athletes',
    ].join(' · ');

    final HubPill status;
    if (isMine) {
      status = const HubPill(
        label: 'Your Coach',
        fill: AppColors.hubDayDone,
      );
    } else if (coach.acceptingAthletes) {
      status = const HubPill(
        label: 'Open',
        fill: AppColors.hubShareOnFill,
        textColor: AppColors.hubShareOnText,
      );
    } else {
      status = const HubPill(
        label: 'Waitlist',
        fill: AppColors.hubWaitFill,
        textColor: AppColors.hubWaitText,
      );
    }

    void open() => context.push(AppRoutes.captainProfilePath(coach.coachId));

    return HubCard(
      onTap: open,
      padding: const EdgeInsets.all(AppSpacing.md - 2),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HubAvatar(
                name: name,
                imageUrl: coach.avatarUrl,
                size: 52,
                ringColor: null,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.titleMedium.copyWith(
                              color: AppColors.hubTextBright,
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs + 2),
                        const Icon(
                          LucideIcons.badgeCheck,
                          size: AppSizing.iconSm - 2,
                          color: AppColors.hubEyebrow,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xxs - 1),
                    if (specialties.isNotEmpty || coach.headline != null)
                      Text(
                        specialties.isNotEmpty ? specialties : coach.headline!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.labelLarge
                            .copyWith(color: AppColors.hubTextBody),
                      ),
                    const SizedBox(height: AppSpacing.xxs - 1),
                    Text(
                      meta,
                      style: AppTypography.labelMedium
                          .copyWith(color: AppColors.hubTextMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              status,
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: HubOutlineButton(
              label: 'View profile',
              height: 38,
              onPressed: open,
            ),
          ),
        ],
      ),
    );
  }
}
