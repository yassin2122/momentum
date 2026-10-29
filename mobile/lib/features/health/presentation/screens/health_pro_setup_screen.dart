import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
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

/// "List your practice": creates a private draft profile for a doctor or
/// physiotherapist. Grit reviews it before anyone else can see it.
class HealthProSetupScreen extends ConsumerStatefulWidget {
  const HealthProSetupScreen({this.initialKind, super.key});

  final HealthKind? initialKind;

  @override
  ConsumerState<HealthProSetupScreen> createState() => _HealthProSetupScreenState();
}

class _HealthProSetupScreenState extends ConsumerState<HealthProSetupScreen> {
  late HealthKind _kind = widget.initialKind ?? HealthKind.doctor;
  final _name = TextEditingController();
  final _specialty = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  bool _confirmed = false;
  bool _saving = false;
  final _errors = <String, String?>{};

  @override
  void dispose() {
    for (final c in [_name, _specialty, _city, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _create() async {
    setState(() {
      _errors
        ..['name'] = _name.text.trim().length < 2 ? 'Add your professional name' : null
        ..['specialty'] = _specialty.text.trim().length < 2 ? 'Add your main specialty' : null
        ..['city'] = _city.text.trim().isEmpty ? 'Add the city you practise in' : null
        ..['phone'] = _phone.text.replaceAll(RegExp(r'[^0-9]'), '').length < 8
            ? 'Add your clinic or practice phone'
            : null;
    });
    if (_errors.values.any((e) => e != null)) return;
    if (!_confirmed) {
      gymToast(context, 'Confirm that you\'re licensed and these are your own details.');
      return;
    }
    setState(() => _saving = true);
    final r = await ref.read(healthRepositoryProvider).create(
          kind: _kind,
          name: _name.text,
          specialty: _specialty.text,
          city: _city.text,
          phone: _phone.text,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    r.when(
      success: (id) {
        ref.invalidate(myHealthProfilesProvider);
        context.pushReplacement(AppRoutes.healthProOnboardingPath(id));
      },
      failure: (f) => gymToast(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(gymAccountProvider)) {
      return HubPage(bottomPadding: AppSpacing.xl2, children: [
        GymTitleBar(title: 'List your practice', onBack: () => context.pop()),
        const SizedBox(height: AppSpacing.md),
        const HubMessageCard(
          icon: LucideIcons.userRound,
          title: 'Create an account first',
          message: 'Provider profiles are managed from a Grit account.',
        ),
      ]);
    }
    return HubPage(
      bottomPadding: AppSizing.buttonHeight + AppSpacing.xl4,
      bottomBar: HubGradientButton(
        label: 'Create profile',
        height: AppSizing.buttonHeight,
        isLoading: _saving,
        onPressed: _saving ? null : _create,
      ),
      children: [
        GymTitleBar(
          eyebrow: 'Grit for health pros',
          title: 'List your practice',
          onBack: () => context.pop(),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Athletes on Grit can find you and contact you directly. You keep '
          'your own booking: Grit never schedules appointments.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody, height: 1.4),
        ),
        const SizedBox(height: AppSpacing.md),
        GymSection(
          header: 'I am a',
          children: [
            for (final k in HealthKind.values)
              GymRow(
                leading: Icon(
                  _kind == k ? LucideIcons.circleCheck : LucideIcons.circle,
                  size: AppSizing.iconMd,
                  color: _kind == k ? AppColors.hubEyebrow : AppColors.hubTextFaint,
                ),
                title: k.label,
                subtitle: k == HealthKind.doctor
                    ? 'Including sports medicine and orthopedics'
                    : 'Including sports and post-injury rehabilitation',
                showChevron: false,
                onTap: () => setState(() => _kind = k),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GymTextField(
          label: 'Professional name',
          controller: _name,
          error: _errors['name'],
          hint: _kind == HealthKind.doctor ? 'e.g. Dr. Nour Hassan' : 'e.g. Karim Hegazy, PT',
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'Main specialty',
          controller: _specialty,
          error: _errors['specialty'],
          onChanged: (_) => setState(() {}),
          textCapitalization: TextCapitalization.sentences,
          maxLength: 60,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final s in kHealthSpecialties.take(5))
              GymChoiceChip(
                label: s,
                selected: _specialty.text == s,
                onTap: () => setState(() => _specialty.text = s),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GymTextField(
          label: 'City',
          controller: _city,
          error: _errors['city'],
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'Clinic or practice phone',
          controller: _phone,
          error: _errors['phone'],
          hint: 'Shown publicly only if you switch it on later',
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          maxLength: 20,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymSection(children: [
          GymSwitchRow(
            title: 'I\'m licensed to practise',
            subtitle: 'These are my own professional details.',
            value: _confirmed,
            onChanged: (v) => setState(() => _confirmed = v),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        const GymNote(
          'Your profile stays private until Grit reviews it. Add your practising '
          'licence next to get the “License verified” badge.',
          icon: LucideIcons.shieldCheck,
        ),
      ],
    );
  }
}
