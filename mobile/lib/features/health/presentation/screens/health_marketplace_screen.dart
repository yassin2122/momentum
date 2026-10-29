import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import '../../../gyms/presentation/providers/gym_providers.dart' show gymAccountProvider;
import '../../../gyms/presentation/widgets/gym_ui.dart';
import '../../domain/entities/health_entities.dart';
import '../providers/health_providers.dart';
import '../widgets/health_ui.dart';

/// Find a health pro: doctors and physiotherapists Grit has approved.
/// Discovery only — people contact providers themselves.
class HealthMarketplaceScreen extends ConsumerStatefulWidget {
  const HealthMarketplaceScreen({super.key});

  @override
  ConsumerState<HealthMarketplaceScreen> createState() => _HealthMarketplaceScreenState();
}

/// One filter chip: a specialty, a service mode, or "verified only".
typedef _Filter = ({String label, String? specialty, HealthServiceMode? mode, bool verified});

class _HealthMarketplaceScreenState extends ConsumerState<HealthMarketplaceScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  String _query = '';
  HealthKind? _kind;
  int _filter = 0;

  /// Local save state so the heart responds instantly.
  final _saved = <String, bool>{};

  static const _filters = <_Filter>[
    (label: 'All specialties', specialty: null, mode: null, verified: false),
    (label: 'Sports medicine', specialty: 'Sports', mode: null, verified: false),
    (label: 'Rehabilitation', specialty: 'rehab', mode: null, verified: false),
    (label: 'Orthopedics', specialty: 'Ortho', mode: null, verified: false),
    (label: 'Home visits', specialty: null, mode: HealthServiceMode.home, verified: false),
    (label: 'Clinic visits', specialty: null, mode: HealthServiceMode.clinic, verified: false),
    (label: 'Verified only', specialty: null, mode: null, verified: true),
  ];

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  HealthQuery get _key {
    final f = _filters[_filter];
    return (
      search: _query,
      kind: _kind,
      specialty: f.specialty,
      mode: f.mode,
      verifiedOnly: f.verified,
    );
  }

  Future<void> _toggleSave(HealthDirectoryEntry e) async {
    if (!ref.read(gymAccountProvider)) {
      gymToast(context, 'Create a Grit account to save providers.');
      return;
    }
    final next = !(_saved[e.listingId] ?? e.isSaved);
    HapticFeedback.selectionClick();
    setState(() => _saved[e.listingId] = next);
    final r = await ref.read(healthRepositoryProvider).setSaved(e.listingId, next);
    if (!mounted) return;
    r.when(
      success: (_) => ref.invalidate(savedProvidersProvider),
      failure: (f) {
        setState(() => _saved[e.listingId] = !next);
        gymToast(context, f.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final key = _key;
    final list = ref.watch(healthDirectoryProvider(key));
    final noFilters = _query.isEmpty && _kind == null && _filter == 0;

    return HubPage(
      children: [
        GymTitleBar(
          eyebrow: 'Connect',
          title: 'Find a health pro',
          onBack: () => context.pop(),
          trailing: HubSquareIconButton(
            icon: LucideIcons.heart,
            semanticLabel: 'Saved providers',
            onPressed: () => context.push(AppRoutes.savedProviders),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        _SearchField(
          controller: _search,
          onChanged: (t) {
            _debounce?.cancel();
            _debounce = Timer(const Duration(milliseconds: 350), () {
              if (mounted) setState(() => _query = t.trim());
            });
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        GymSegmented<HealthKind?>(
          options: [
            (null, 'All'),
            for (final k in HealthKind.values) (k, k.plural),
          ],
          value: _kind,
          onChanged: (k) => setState(() => _kind = k),
        ),
        const SizedBox(height: AppSpacing.sm),
        GymFilterRow(
          quick: const ['Sports medicine', 'Rehabilitation', 'Home visits'],
          all: [for (final f in _filters.skip(1)) f.label],
          selected: _filter == 0 ? null : _filters[_filter].label,
          onSelected: (label) => setState(() => _filter =
              label == null ? 0 : _filters.indexWhere((f) => f.label == label)),
        ),
        const SizedBox(height: AppSpacing.md),
        list.when(
          loading: () => const _Skeleton(),
          error: (e, _) => HubMessageCard(
            icon: LucideIcons.circleAlert,
            title: "Couldn't load providers",
            message: healthErrorMessage(e),
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(healthDirectoryProvider(key)),
          ),
          data: (entries) {
            if (entries.isEmpty) {
              return HubMessageCard(
                icon: noFilters ? LucideIcons.stethoscope : LucideIcons.searchX,
                title: noFilters ? 'No providers listed yet' : 'No providers match',
                message: noFilters
                    ? 'Doctors and physiotherapists appear here once Grit has reviewed their profiles.'
                    : 'Try another specialty or area, or clear the filters.',
                actionLabel: noFilters ? null : 'Clear filters',
                onAction: noFilters
                    ? null
                    : () {
                        _search.clear();
                        setState(() {
                          _query = '';
                          _kind = null;
                          _filter = 0;
                        });
                      },
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.xs),
                  child: Text(
                    '${entries.length} ${entries.length == 1 ? 'provider' : 'providers'}',
                    style: AppTypography.labelLarge.copyWith(color: AppColors.hubTextMuted),
                  ),
                ),
                for (final e in entries) ...[
                  HealthProviderCard(
                    entry: e.copyWith(isSaved: _saved[e.listingId] ?? e.isSaved),
                    onSave: () => _toggleSave(e),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        const GymNote(
          'Grit lists providers so you can contact them yourself. It doesn\'t '
          'book appointments or give medical advice.',
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
        hintText: 'Name or specialty',
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

/// A provider in a list (marketplace and saved).
class HealthProviderCard extends StatelessWidget {
  const HealthProviderCard({required this.entry, required this.onSave, super.key});

  final HealthDirectoryEntry entry;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    return ProviderCard(
      onTap: () => context.push(AppRoutes.healthProviderPath(e.listingId)),
      leading: HealthAvatar(name: e.name, kind: e.kind, url: e.photoUrl, size: 56),
      title: e.name,
      badges: [
        HealthKindChip(e.kind),
        if (e.licenseVerified) const HealthVerifiedBadge(),
      ],
      subtitle: e.specialtyLabel,
      location: [
        if (e.locationLabel.isNotEmpty) e.locationLabel,
        if (e.serviceModes.contains(HealthServiceMode.home)) 'Home visits',
      ].join(' · '),
      fact: e.consultationFee == null
          ? null
          : '${gymPrice(e.consultationFee!, e.feeCurrency)} consultation · set by provider',
      trailing: ProviderSaveButton(saved: e.isSaved, name: e.name, onPressed: onSave),
    );
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();

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
      label: 'Loading providers',
      child: Column(
        children: [
          for (var i = 0; i < 3; i++) ...[
            HubCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                        shape: BoxShape.circle, color: AppColors.hubIconButton),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(150, 14),
                      const SizedBox(height: AppSpacing.xs),
                      bar(90, 12),
                      const SizedBox(height: AppSpacing.xs),
                      bar(190, 12),
                    ],
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
