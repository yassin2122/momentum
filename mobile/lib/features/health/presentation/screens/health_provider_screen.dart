import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../gyms/presentation/providers/gym_providers.dart' show gymAccountProvider;
import '../../../gyms/presentation/widgets/gym_ui.dart';
import '../../domain/entities/health_entities.dart';
import '../providers/health_providers.dart';
import '../widgets/health_ui.dart';

/// A provider's public profile. Every contact action is optional and uses
/// only what the provider published; there is no in-app booking.
class HealthProviderScreen extends ConsumerStatefulWidget {
  const HealthProviderScreen({required this.listingId, super.key});

  final String listingId;

  @override
  ConsumerState<HealthProviderScreen> createState() => _HealthProviderScreenState();
}

class _HealthProviderScreenState extends ConsumerState<HealthProviderScreen> {
  bool? _saved;

  Future<void> _toggleSave(HealthProviderDetail p) async {
    if (!ref.read(gymAccountProvider)) {
      gymToast(context, 'Create a Grit account to save providers.');
      return;
    }
    final next = !(_saved ?? p.isSaved);
    HapticFeedback.selectionClick();
    setState(() => _saved = next);
    final r = await ref.read(healthRepositoryProvider).setSaved(p.listingId, next);
    if (!mounted) return;
    r.when(
      success: (_) => ref.invalidate(savedProvidersProvider),
      failure: (f) {
        setState(() => _saved = !next);
        gymToast(context, f.message);
      },
    );
  }

  void _call(HealthProviderDetail p) =>
      healthLaunch(context, healthCallUri(p.phone!), fallbackCopy: p.phone);

  void _whatsapp(HealthProviderDetail p) =>
      healthLaunch(context, healthWhatsappUri(p.whatsapp!), fallbackCopy: p.whatsapp);

  void _directions(HealthProviderDetail p) {
    final uri = healthMapsUri(p);
    if (uri != null) healthLaunch(context, uri, fallbackCopy: p.addressLabel);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(healthProviderDetailProvider(widget.listingId));
    return async.when(
      loading: () => const HubPage(bottomPadding: AppSpacing.xl2, children: [
        SizedBox(height: AppSpacing.xl4),
        HubLoading(),
      ]),
      error: (e, _) => HubPage(bottomPadding: AppSpacing.xl2, children: [
        GymTitleBar(title: 'Provider', onBack: () => context.pop()),
        const SizedBox(height: AppSpacing.md),
        HubMessageCard(
          icon: LucideIcons.circleAlert,
          title: "Couldn't open this profile",
          message: healthErrorMessage(e),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(healthProviderDetailProvider(widget.listingId)),
        ),
      ]),
      data: (p) => _build(context, p),
    );
  }

  Widget _build(BuildContext context, HealthProviderDetail p) {
    final saved = _saved ?? p.isSaved;
    final maps = healthMapsUri(p);
    final verifiedLicense = p.credentials
        .where((c) => c.verified && c.kind == HealthCredentialKind.license)
        .firstOrNull;

    return HubPage(
      bottomPadding: p.hasAnyContact ? AppSizing.buttonHeight + AppSpacing.xl4 : AppSpacing.xl2,
      bottomBar: p.hasAnyContact && !p.isPreview
          ? HubGradientButton(
              label: 'Contact ${_shortName(p.name)}',
              icon: LucideIcons.messageCircle,
              height: AppSizing.buttonHeight,
              onPressed: () => showGymSheet<void>(context, _ContactSheet(provider: p)),
            )
          : null,
      children: [
        Row(
          children: [
            HubBackButton(onPressed: () => context.pop()),
            const Spacer(),
            if (!p.isPreview)
              Semantics(
                button: true,
                selected: saved,
                label: saved ? 'Remove from saved' : 'Save provider',
                child: ExcludeSemantics(
                  child: InkResponse(
                    onTap: () => _toggleSave(p),
                    radius: AppSizing.minTouchTarget / 2,
                    child: Container(
                      width: AppSizing.minTouchTarget,
                      height: AppSizing.minTouchTarget,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: saved ? AppColors.errorContainer : AppColors.authBackButton,
                        border: Border.all(color: AppColors.hubCardBorderStrong),
                      ),
                      child: Icon(LucideIcons.heart,
                          size: AppSizing.iconMd,
                          color: saved ? AppColors.hubDanger : AppColors.hubTextBright),
                    ),
                  ),
                ),
              ),
          ],
        ),
        if (p.isPreview) ...[
          const SizedBox(height: AppSpacing.sm),
          const GymNote('Preview — only you can see this until Grit approves your profile.',
              icon: LucideIcons.eye),
        ],
        const SizedBox(height: AppSpacing.md),
        HealthAvatar(name: p.name, kind: p.kind, url: p.photoUrl, size: 92),
        const SizedBox(height: AppSpacing.sm),
        Text(p.name,
            style: AppTypography.headlineMedium.copyWith(
              color: AppColors.hubTextBright,
              fontWeight: AppTypography.extraBold,
            )),
        if (p.headline != null)
          Text(p.headline!,
              style: AppTypography.bodyLarge.copyWith(color: AppColors.hubTextBody)),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            HealthKindChip(p.kind),
            if (verifiedLicense != null) const HealthVerifiedBadge(),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            HealthActionButton(
                icon: LucideIcons.phone,
                label: 'Call',
                onTap: p.phone == null ? null : () => _call(p)),
            HealthActionButton(
                icon: LucideIcons.messageCircle,
                label: 'WhatsApp',
                onTap: p.whatsapp == null ? null : () => _whatsapp(p)),
            HealthActionButton(
                icon: LucideIcons.navigation,
                label: 'Directions',
                onTap: maps == null ? null : () => _directions(p)),
            HealthActionButton(
                icon: LucideIcons.globe,
                label: 'Website',
                onTap: p.website == null
                    ? null
                    : () => healthOpenExternal(context, p.website!, booking: false)),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        if (p.description != null || p.experienceYears != null || p.languages.isNotEmpty) ...[
          GymSection(
            header: 'About',
            children: [
              if (p.description != null)
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Text(p.description!,
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.hubTextBody, height: 1.45)),
                ),
              if (p.experienceYears != null)
                GymRow(
                  title: 'Experience',
                  value: p.experienceYears == 1 ? '1 year' : '${p.experienceYears} years',
                  showChevron: false,
                  trailing: const HealthSubmittedPill(),
                ),
              if (p.languages.isNotEmpty)
                GymRow(title: 'Languages', value: p.languages.join(', '), showChevron: false),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (p.specialties.isNotEmpty || p.services.isNotEmpty) ...[
          _Tags(title: 'Specialties', tags: p.specialties),
          _Tags(title: 'Services', tags: [
            ...p.services,
            for (final m in p.serviceModes) m.label,
          ]),
        ],
        if (p.credentials.isNotEmpty) ...[
          GymSection(
            header: 'Qualifications',
            footer: '“Verified” means Grit checked it. Everything marked '
                'provider-submitted is shown as the provider entered it.',
            children: [
              for (final c in p.credentials)
                GymRow(
                  icon: LucideIcons.award,
                  title: c.title,
                  subtitle: [
                    if (c.subtitle.isNotEmpty) c.subtitle,
                    if (c.verified && c.verifiedAt != null)
                      'checked by Grit, ${gymShortDate(c.verifiedAt!)}',
                  ].join(' · '),
                  showChevron: false,
                  trailing: c.verified
                      ? const HealthVerifiedBadge(label: 'Verified')
                      : const HealthSubmittedPill(),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (p.hasLocation || p.availabilityNote != null || p.consultationFee != null) ...[
          GymSection(
            header: p.clinicName ?? 'Practice',
            children: [
              if (p.hasLocation)
                GymRow(
                  icon: LucideIcons.mapPin,
                  title: p.addressLabel,
                  value: maps == null ? null : 'Directions',
                  onTap: maps == null ? null : () => _directions(p),
                  showChevron: false,
                ),
              if (p.availabilityNote != null)
                GymRow(
                  icon: LucideIcons.clock,
                  title: p.availabilityNote!,
                  subtitle: 'General availability, as listed by the provider. '
                      'Contact them to arrange a visit.',
                  showChevron: false,
                ),
              if (p.consultationFee != null)
                GymRow(
                  icon: LucideIcons.tag,
                  title: 'Consultation · ${gymPrice(p.consultationFee!, p.feeCurrency)}',
                  subtitle: 'Set by the provider. Confirm with them.',
                  showChevron: false,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        if (p.bookingUrl != null) ...[
          GymSection(
            footer: 'Appointments are arranged with the provider directly. Grit '
                'doesn\'t book or confirm them.',
            children: [
              GymRow(
                icon: LucideIcons.externalLink,
                title: 'Book on their website',
                trailing: const HealthExternalPill(),
                onTap: () => healthOpenExternal(context, p.bookingUrl!, booking: true),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
        const GymNote(
          'Grit doesn\'t give medical advice or diagnoses. In an emergency, call 123.',
          icon: LucideIcons.circleAlert,
        ),
      ],
    );
  }
}

String _shortName(String name) {
  final parts = name.split(' ');
  if (parts.first.startsWith('Dr') && parts.length > 1) return 'Dr. ${parts[1]}';
  return parts.first.replaceAll(',', '');
}

class _Tags extends StatelessWidget {
  const _Tags({required this.title, required this.tags});

  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.xs),
            child: Text(title.toUpperCase(),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.hubTextMuted,
                  letterSpacing: 0.6,
                  fontWeight: AppTypography.semiBold,
                )),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final t in tags)
                HubPill(label: t, fill: AppColors.hubIconButton, textColor: AppColors.hubTextBody),
            ],
          ),
        ],
      ),
    );
  }
}

/// Only the ways the provider chose to share.
class _ContactSheet extends StatelessWidget {
  const _ContactSheet({required this.provider});

  final HealthProviderDetail provider;

  @override
  Widget build(BuildContext context) {
    final p = provider;
    final maps = healthMapsUri(p);
    // Close the sheet first so any confirmation shows on its own.
    void then(void Function(BuildContext) action) {
      final parent = Navigator.of(context, rootNavigator: true).context;
      Navigator.of(context).pop();
      action(parent);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GymSheetHeader(
          title: 'Contact ${_shortName(p.name)}',
          subtitle: 'Only the ways they chose to share are shown.',
        ),
        GymSection(
          children: [
            if (p.phone != null)
              GymRow(
                icon: LucideIcons.phone,
                title: 'Call',
                subtitle: p.phoneVerified ? '${p.phone} · checked by Grit' : p.phone,
                onTap: () => then((c) => healthLaunch(c, healthCallUri(p.phone!), fallbackCopy: p.phone)),
              ),
            if (p.whatsapp != null)
              GymRow(
                icon: LucideIcons.messageCircle,
                title: 'WhatsApp',
                subtitle: p.whatsapp,
                onTap: () => then((c) =>
                    healthLaunch(c, healthWhatsappUri(p.whatsapp!), fallbackCopy: p.whatsapp)),
              ),
            if (maps != null)
              GymRow(
                icon: LucideIcons.navigation,
                title: 'Directions',
                subtitle: 'Opens in your maps app',
                onTap: () => then((c) => healthLaunch(c, maps, fallbackCopy: p.addressLabel)),
              ),
            if (p.website != null)
              GymRow(
                icon: LucideIcons.globe,
                title: 'Website',
                subtitle: Uri.tryParse(p.website!)?.host ?? p.website,
                trailing: const HealthExternalPill(),
                onTap: () => then((c) => healthOpenExternal(c, p.website!, booking: false)),
              ),
            if (p.bookingUrl != null)
              GymRow(
                icon: LucideIcons.externalLink,
                title: 'Book on their website',
                subtitle: 'Appointments are arranged by the provider',
                trailing: const HealthExternalPill(),
                onTap: () => then((c) => healthOpenExternal(c, p.bookingUrl!, booking: true)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        HubOutlineButton(
          label: 'Cancel',
          height: AppSizing.buttonHeight,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
