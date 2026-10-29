import 'dart:async';

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
import '../../../../core/widgets/provider_card.dart';
import '../../domain/entities/gym_entities.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_ui.dart';

/// Find a gym: published gym listings, searchable by name or area and
/// filterable by one facility. Nothing here is ranked by payment; partner
/// gyms only carry a badge.
class FindGymScreen extends ConsumerStatefulWidget {
  const FindGymScreen({super.key});

  @override
  ConsumerState<FindGymScreen> createState() => _FindGymScreenState();
}

class _FindGymScreenState extends ConsumerState<FindGymScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  String? _facility;

  static const _filters = [
    'Women\'s area',
    'Open 24 hours',
    'Pool',
    'Group classes',
    'Personal training',
    'Sauna',
    'Parking',
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _query = text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final key = (search: _query, facility: _facility);
    final gyms = ref.watch(gymDirectoryProvider(key));

    return HubPage(
      children: [
        GymTitleBar(
          eyebrow: 'Connect',
          title: 'Find a gym',
          onBack: () => context.pop(),
        ),
        const SizedBox(height: AppSpacing.md),
        _SearchField(controller: _search, onChanged: _onSearch),
        const SizedBox(height: AppSpacing.sm),
        GymFilterRow(
          quick: const ['Women\'s area', 'Open 24 hours', 'Group classes'],
          all: _filters,
          selected: _facility,
          onSelected: (f) => setState(() => _facility = f),
        ),
        const SizedBox(height: AppSpacing.md),
        gyms.when(
          loading: () => const _GymSkeleton(),
          error: (e, _) => HubMessageCard(
            icon: LucideIcons.wifiOff,
            title: "Couldn't load gyms",
            message: gymErrorMessage(e),
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(gymDirectoryProvider(key)),
          ),
          data: (list) {
            if (list.isEmpty) {
              return HubMessageCard(
                icon: LucideIcons.mapPinOff,
                title: _query.isEmpty && _facility == null
                    ? 'No gyms listed yet'
                    : 'No gyms match',
                message: _query.isEmpty && _facility == null
                    ? 'Gyms appear here once they publish their page on Grit.'
                    : 'Try another area or remove the filter.',
              );
            }
            return Column(
              children: [
                for (final g in list) ...[
                  _GymCard(entry: g),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

/// Placeholder cards while gyms load, so the page keeps its shape.
class _GymSkeleton extends StatelessWidget {
  const _GymSkeleton();

  @override
  Widget build(BuildContext context) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: AppColors.hubIconButton,
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
        );
    return Semantics(
      label: 'Loading gyms',
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            HubCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 120,
                    decoration: const BoxDecoration(
                      color: AppColors.hubCardBottom,
                      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.hubCard)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.sm),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(160, 14),
                        const SizedBox(height: AppSpacing.xs),
                        bar(110, 12),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
          borderSide: BorderSide(color: c),
        );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppTypography.bodyLarge.copyWith(color: AppColors.hubTextBright),
      cursorColor: AppColors.hubEyebrow,
      decoration: InputDecoration(
        hintText: 'Gym name or area',
        hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.hubTextFaint),
        prefixIcon: const Icon(LucideIcons.search,
            size: AppSizing.iconSm + 2, color: AppColors.hubTextMuted),
        filled: true,
        fillColor: AppColors.authInputFill,
        contentPadding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        border: border(AppColors.authInputBorder),
        enabledBorder: border(AppColors.authInputBorder),
        focusedBorder: border(AppColors.hubRing),
      ),
    );
  }
}

class _GymCard extends StatelessWidget {
  const _GymCard({required this.entry});

  final GymDirectoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return ProviderCard(
      onTap: () => context.push(AppRoutes.gymDetailPath(e.gymId)),
      leading: GymLogo(name: e.name, url: e.logoUrl, size: 56),
      title: e.name,
      badges: [
        const ProviderTypeChip(label: 'Gym', icon: LucideIcons.dumbbell),
        if (e.isPartner) const GymPartnerBadge(),
      ],
      subtitle: e.headline,
      location: [
        if (e.locationLabel.isNotEmpty) e.locationLabel,
        e.branchCount == 1 ? '1 branch' : '${e.branchCount} branches',
      ].join(' · '),
      fact: e.offersFrom == null
          ? null
          : 'Offers from ${gymPrice(e.offersFrom!, e.currency ?? 'EGP')} · set by the gym',
    );
  }
}
