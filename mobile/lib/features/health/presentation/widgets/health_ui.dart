import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../../core/widgets/provider_card.dart';
import '../../../gyms/presentation/widgets/gym_ui.dart';
import '../../domain/entities/health_entities.dart';

/// Badges, avatars and contact helpers for the health screens. Layout
/// building blocks (sections, rows, sheets, fields) come from gym_ui.dart.

/// Specialty suggestions (providers can type their own too).
const kHealthSpecialties = <String>[
  'Sports medicine',
  'Orthopedics',
  'Physical medicine & rehabilitation',
  'Sports physiotherapy',
  'Post-injury rehabilitation',
  'Spine & back',
  'Manual therapy',
  'Neurological rehabilitation',
];

/// Grit checked this credential.
class HealthVerifiedBadge extends StatelessWidget {
  const HealthVerifiedBadge({this.label = 'License verified', super.key});

  final String label;

  @override
  Widget build(BuildContext context) => HubPill(
        label: label,
        icon: LucideIcons.shieldCheck,
        fill: AppColors.hubShareOnFill,
        textColor: AppColors.hubShareOnText,
      );
}

/// Shown exactly as the provider entered it; Grit hasn't checked it.
class HealthSubmittedPill extends StatelessWidget {
  const HealthSubmittedPill({super.key});

  @override
  Widget build(BuildContext context) => const HubPill(
        label: 'Provider-submitted',
        fill: AppColors.hubShareOffFill,
        textColor: AppColors.hubTextMuted,
      );
}

class HealthKindChip extends StatelessWidget {
  const HealthKindChip(this.kind, {super.key});

  final HealthKind kind;

  @override
  Widget build(BuildContext context) => ProviderTypeChip(
        label: kind.label,
        icon: kind == HealthKind.doctor ? LucideIcons.stethoscope : LucideIcons.activity,
      );
}

class HealthExternalPill extends StatelessWidget {
  const HealthExternalPill({super.key});

  @override
  Widget build(BuildContext context) => const HubPill(
        label: 'External website',
        icon: LucideIcons.externalLink,
        fill: AppColors.hubShareOffFill,
        textColor: AppColors.hubTextMuted,
      );
}

/// Round photo with a ring in the provider type's colour.
class HealthAvatar extends StatelessWidget {
  const HealthAvatar({required this.name, required this.kind, this.url, this.size = 56, super.key});

  final String name;
  final HealthKind kind;
  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) => HubAvatar(
        name: name.replaceFirst(RegExp(r'^Dr\.?\s+'), ''),
        imageUrl: url,
        size: size,
        ringColor: kind == HealthKind.doctor ? AppColors.hubRing : AppColors.hubSkyLight,
      );
}

/// One of the round contact buttons under a provider's name.
class HealthActionButton extends StatelessWidget {
  const HealthActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Expanded(
      child: Semantics(
        button: true,
        enabled: enabled,
        label: enabled ? label : '$label, not provided',
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Opacity(
              opacity: enabled ? 1 : 0.35,
              child: Column(
                children: [
                  Container(
                    width: AppSizing.minTouchTarget + 8,
                    height: AppSizing.minTouchTarget + 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.hubCardBottom,
                      border: Border.all(color: AppColors.hubCardBorderStrong),
                    ),
                    child: Icon(icon, size: AppSizing.iconMd, color: AppColors.hubSkyLight),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(label,
                      style: AppTypography.labelMedium.copyWith(
                        color: AppColors.hubTextBright,
                        fontWeight: AppTypography.semiBold,
                      )),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Contact actions — always the provider's own published details
// ---------------------------------------------------------------------------

String _digits(String phone) => phone.replaceAll(RegExp(r'[^0-9+]'), '');

Uri healthCallUri(String phone) => Uri(scheme: 'tel', path: _digits(phone));

/// wa.me needs the number without "+" or spaces.
Uri healthWhatsappUri(String phone) =>
    Uri.parse('https://wa.me/${_digits(phone).replaceAll('+', '')}');

/// Opens the clinic in the device's maps app (or the browser).
Uri? healthMapsUri(HealthProviderDetail p) {
  final lat = p.latitude;
  final lng = p.longitude;
  final query = lat != null && lng != null
      ? '$lat,$lng'
      : [if (p.clinicName != null) p.clinicName!, p.addressLabel]
          .where((s) => s.isNotEmpty)
          .join(', ');
  if (query.isEmpty) return null;
  return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query});
}

/// Launches [uri] outside Grit; falls back to copying [fallbackCopy].
Future<void> healthLaunch(BuildContext context, Uri uri, {String? fallbackCopy}) async {
  bool ok;
  try {
    ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    ok = false;
  }
  if (ok || !context.mounted) return;
  if (fallbackCopy != null) {
    await Clipboard.setData(ClipboardData(text: fallbackCopy));
    if (context.mounted) gymToast(context, "Couldn't open it here, so it's copied instead.");
  } else {
    gymToast(context, "Couldn't open that link on this device.");
  }
}

/// "You're leaving Grit" before any external website or booking page.
Future<void> healthOpenExternal(BuildContext context, String url, {required bool booking}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') {
    gymToast(context, "That link can't be opened safely.");
    return;
  }
  final go = await showGymSheet<bool>(
    context,
    _LeavingSheet(host: uri.host, booking: booking),
  );
  if (go == true && context.mounted) await healthLaunch(context, uri, fallbackCopy: url);
}

class _LeavingSheet extends StatelessWidget {
  const _LeavingSheet({required this.host, required this.booking});

  final String host;
  final bool booking;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GymSheetHeader(title: "You're leaving Grit"),
        Text(
          booking
              ? "The provider's booking page opens in your browser. Grit doesn't "
                  'see, book or manage appointments you make there.'
              : "The provider's website opens in your browser. It isn't run by Grit.",
          style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.md),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.authInputFill,
              borderRadius: BorderRadius.circular(AppRadius.pill),
              border: Border.all(color: AppColors.hubCardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(LucideIcons.lock, size: AppSizing.iconSm - 2, color: AppColors.hubSkyLight),
                const SizedBox(width: AppSpacing.xxs),
                Text(host, style: AppTypography.labelLarge.copyWith(color: AppColors.hubSkyLight)),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        HubGradientButton(
          label: 'Open website',
          icon: LucideIcons.externalLink,
          height: AppSizing.buttonHeight,
          onPressed: () => Navigator.of(context).pop(true),
        ),
        const SizedBox(height: AppSpacing.xs),
        HubOutlineButton(
          label: 'Stay in Grit',
          height: AppSizing.buttonHeight,
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ],
    );
  }
}
