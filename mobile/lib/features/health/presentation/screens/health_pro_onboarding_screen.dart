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
import '../../../gyms/presentation/widgets/gym_ui.dart';
import '../../domain/entities/health_entities.dart';
import '../providers/health_providers.dart';
import '../widgets/health_ui.dart';

/// First-time setup for a doctor / physiotherapist in four short steps
/// (Hick's Law, Goal-Gradient): About you → Specialties → Practice →
/// Contact → submit. Each step saves as you go, so leaving early loses
/// nothing; the full editor handles every later change.
class HealthProOnboardingScreen extends ConsumerStatefulWidget {
  const HealthProOnboardingScreen({required this.listingId, super.key});

  final String listingId;

  @override
  ConsumerState<HealthProOnboardingScreen> createState() => _HealthProOnboardingScreenState();
}

class _HealthProOnboardingScreenState extends ConsumerState<HealthProOnboardingScreen> {
  static const _titles = ['About you', 'Specialties & services', 'Your practice', 'How people reach you'];

  int _step = 0;
  bool _ready = false;
  bool _saving = false;
  final _errors = <String, String?>{};

  // Step 1
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _years = TextEditingController();
  // Step 2
  final _specialties = <String>{};
  final _services = TextEditingController();
  bool _home = false;
  // Step 3
  final _clinic = TextEditingController();
  final _address = TextEditingController();
  final _area = TextEditingController();
  final _city = TextEditingController();
  final _availability = TextEditingController();
  final _fee = TextEditingController();
  // Step 4
  final _phone = TextEditingController();
  final _whatsapp = TextEditingController();
  final _website = TextEditingController();
  final _booking = TextEditingController();
  bool _showPhone = true;
  bool _showWhatsapp = false;

  List<TextEditingController> get _controllers => [
        _headline, _bio, _years, _services, _clinic, _address, _area, _city,
        _availability, _fee, _phone, _whatsapp, _website, _booking,
      ];

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _prefill(MyHealthProfile p) {
    if (_ready) return;
    _ready = true;
    _headline.text = p.headline ?? '';
    _bio.text = p.description ?? '';
    _years.text = p.experienceYears?.toString() ?? '';
    _specialties.addAll(p.specialties);
    _services.text = p.services.join(', ');
    _home = p.serviceModes.contains(HealthServiceMode.home);
    _clinic.text = p.clinicName ?? '';
    _address.text = p.address ?? '';
    _area.text = p.area ?? '';
    _city.text = p.city ?? '';
    _availability.text = p.availabilityNote ?? '';
    _fee.text = p.consultationFee?.round().toString() ?? '';
    _phone.text = p.phone ?? '';
    _whatsapp.text = p.whatsapp ?? '';
    _website.text = p.website ?? '';
    _booking.text = p.bookingUrl ?? '';
    _showPhone = p.phone == null ? true : p.showPhone;
    _showWhatsapp = p.showWhatsapp;
  }

  List<String> _split(String t) =>
      t.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();

  /// Checks the current step; returns false and shows field errors if not ready.
  bool _validate() {
    _errors.clear();
    switch (_step) {
      case 0:
        if (_headline.text.trim().length < 3) _errors['headline'] = 'Add your professional title';
        if (_bio.text.trim().length < 40) {
          _errors['bio'] = 'Write at least 40 characters (${_bio.text.trim().length} so far)';
        }
      case 1:
        if (_specialties.isEmpty) {
          gymToast(context, 'Pick at least one specialty.');
          return false;
        }
      case 2:
        if (_city.text.trim().isEmpty) _errors['city'] = 'Add your city';
      case 3:
        final reach = (_showPhone && _phone.text.trim().isNotEmpty) ||
            (_showWhatsapp && _whatsapp.text.trim().isNotEmpty) ||
            _website.text.trim().isNotEmpty ||
            _booking.text.trim().isNotEmpty;
        if (!reach) {
          gymToast(context, 'Share at least one way to reach you.');
          return false;
        }
    }
    setState(() {});
    return _errors.values.every((e) => e == null);
  }

  HealthProfilePatch _patch() => switch (_step) {
        0 => HealthProfilePatch(
            headline: _headline.text,
            description: _bio.text,
            experienceYears: int.tryParse(_years.text.trim()),
            clearExperience: _years.text.trim().isEmpty,
          ),
        1 => HealthProfilePatch(
            specialties: _specialties.toList(),
            services: _split(_services.text),
            serviceModes: [HealthServiceMode.clinic, if (_home) HealthServiceMode.home],
          ),
        2 => HealthProfilePatch(
            clinicName: _clinic.text,
            address: _address.text,
            area: _area.text,
            city: _city.text,
            availabilityNote: _availability.text,
            consultationFee: double.tryParse(_fee.text.trim().replaceAll(',', '')),
            clearFee: _fee.text.trim().isEmpty,
          ),
        _ => HealthProfilePatch(
            phone: _phone.text,
            whatsapp: _whatsapp.text,
            website: _website.text,
            bookingUrl: _booking.text,
            showPhone: _showPhone && _phone.text.trim().isNotEmpty,
            showWhatsapp: _showWhatsapp && _whatsapp.text.trim().isNotEmpty,
          ),
      };

  Future<bool> _saveStep(MyHealthProfile p) async {
    setState(() => _saving = true);
    final r = await ref.read(healthRepositoryProvider).update(p, _patch());
    if (!mounted) return false;
    setState(() => _saving = false);
    return r.when(
      success: (_) => true,
      failure: (f) {
        gymToast(context, f.message);
        return false;
      },
    );
  }

  Future<void> _next(MyHealthProfile p) async {
    if (!_validate()) return;
    if (!await _saveStep(p)) return;
    if (_step < _titles.length - 1) {
      setState(() => _step++);
      return;
    }
    // Last step: submit for review.
    setState(() => _saving = true);
    final r = await ref.read(healthRepositoryProvider).submit(p.listingId);
    if (!mounted) return;
    setState(() => _saving = false);
    ref.invalidate(myHealthProfilesProvider);
    await r.when(
      success: (_) async {
        await showGymSuccess(
          context,
          title: 'Sent to Grit for review',
          message: 'Grit checks every profile before athletes can see it. Add your '
              'practising licence in the meantime to get the "License verified" badge.',
          doneLabel: 'Go to my profile',
        );
        if (mounted) context.pushReplacement(AppRoutes.healthProEditorPath(p.listingId));
      },
      failure: (f) async => gymToast(context, f.message),
    );
  }

  Future<void> _finishLater(MyHealthProfile p) async {
    if (!await _saveStep(p)) return;
    ref.invalidate(myHealthProfilesProvider);
    if (mounted) context.pushReplacement(AppRoutes.healthProEditorPath(p.listingId));
  }

  void _back() {
    if (_step == 0) {
      context.pop();
    } else {
      setState(() => _step--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myHealthProfilesProvider);
    return mine.when(
      loading: () => const HubPage(children: [SizedBox(height: AppSpacing.xl4), HubLoading()]),
      error: (e, _) => HubPage(bottomPadding: AppSpacing.xl2, children: [
        GymTitleBar(title: 'Set up your profile', onBack: () => context.pop()),
        const SizedBox(height: AppSpacing.md),
        HubMessageCard(
          icon: LucideIcons.circleAlert,
          title: "Couldn't load your profile",
          message: healthErrorMessage(e),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(myHealthProfilesProvider),
        ),
      ]),
      data: (list) {
        final p = list.where((x) => x.listingId == widget.listingId).firstOrNull;
        if (p == null) {
          return HubPage(bottomPadding: AppSpacing.xl2, children: [
            GymTitleBar(title: 'Set up your profile', onBack: () => context.pop()),
            const SizedBox(height: AppSpacing.md),
            const HubMessageCard(
              icon: LucideIcons.userX,
              title: 'Profile not found',
              message: 'It may have been removed.',
            ),
          ]);
        }
        _prefill(p);
        final last = _step == _titles.length - 1;
        return PopScope(
          canPop: _step == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _back();
          },
          child: HubPage(
            bottomPadding: AppSizing.buttonHeight * 2 + AppSpacing.xl4,
            bottomBar: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HubGradientButton(
                  label: last ? 'Submit for review' : 'Continue',
                  height: AppSizing.buttonHeight,
                  isLoading: _saving,
                  onPressed: _saving ? null : () => _next(p),
                ),
                TextButton(
                  onPressed: _saving ? null : () => _finishLater(p),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(AppSizing.minTouchTarget),
                  ),
                  child: const Text('Save and finish later'),
                ),
              ],
            ),
            children: [
              GymTitleBar(
                eyebrow: 'Step ${_step + 1} of ${_titles.length}',
                title: _titles[_step],
                onBack: _back,
              ),
              const SizedBox(height: AppSpacing.sm),
              HubProgressBar(value: (_step + 1) / _titles.length),
              const SizedBox(height: AppSpacing.lg),
              ...switch (_step) {
                0 => _aboutStep(p),
                1 => _specialtiesStep(),
                2 => _practiceStep(),
                _ => _contactStep(),
              },
            ],
          ),
        );
      },
    );
  }

  List<Widget> _aboutStep(MyHealthProfile p) => [
        GymTextField(
          label: 'Professional title',
          controller: _headline,
          error: _errors['headline'],
          hint: p.kind == HealthKind.doctor ? 'e.g. Sports medicine physician' : 'e.g. Sports physiotherapist',
          maxLength: 120,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'Biography',
          controller: _bio,
          error: _errors['bio'],
          hint: 'Who you work with, your approach, what a first visit looks like.',
          maxLines: 6,
          minLines: 3,
          maxLength: 1000,
          keyboardType: TextInputType.multiline,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'Years in practice',
          controller: _years,
          optional: true,
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
          maxLength: 2,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Describe what you do, not outcomes. Grit doesn\'t allow medical claims or guarantees.',
          style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextMuted),
        ),
      ];

  List<Widget> _specialtiesStep() {
    final options = {...kHealthSpecialties, ..._specialties}.toList();
    return [
      Text('Pick everything that applies.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody)),
      const SizedBox(height: AppSpacing.sm),
      Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xs,
        children: [
          for (final o in options)
            GymChoiceChip(
              label: o,
              selected: _specialties.contains(o),
              onTap: () => setState(
                  () => _specialties.contains(o) ? _specialties.remove(o) : _specialties.add(o)),
            ),
        ],
      ),
      const SizedBox(height: AppSpacing.lg),
      GymTextField(
        label: 'Services you offer',
        controller: _services,
        optional: true,
        hint: 'Separate with commas, e.g. Injury assessment, Return-to-training plans',
        maxLines: 3,
        minLines: 2,
        maxLength: 400,
        keyboardType: TextInputType.multiline,
      ),
      const SizedBox(height: AppSpacing.sm),
      GymSection(children: [
        GymSwitchRow(
          title: 'I also do home visits',
          value: _home,
          onChanged: (v) => setState(() => _home = v),
        ),
      ]),
    ];
  }

  List<Widget> _practiceStep() => [
        GymTextField(label: 'Clinic or practice name', controller: _clinic, optional: true, maxLength: 120),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(label: 'Street address', controller: _address, optional: true, maxLength: 200),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GymTextField(
                label: 'Area',
                controller: _area,
                optional: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: GymTextField(
                label: 'City',
                controller: _city,
                error: _errors['city'],
                textCapitalization: TextCapitalization.words,
                maxLength: 80,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'General availability',
          controller: _availability,
          optional: true,
          hint: 'e.g. Sun–Thu · 4 pm – 10 pm',
          maxLength: 200,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'Consultation fee (EGP)',
          controller: _fee,
          optional: true,
          hint: 'Leave empty to not show a fee',
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
          maxLength: 8,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Availability is shown as general hours, not bookable slots.',
          style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextMuted),
        ),
      ];

  List<Widget> _contactStep() => [
        Text('Only what you switch on is shown on your profile.',
            style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody)),
        const SizedBox(height: AppSpacing.md),
        GymTextField(
          label: 'Clinic or practice phone',
          controller: _phone,
          optional: true,
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          maxLength: 20,
        ),
        GymSection(children: [
          GymSwitchRow(
            title: 'Show phone on my profile',
            value: _showPhone,
            onChanged: (v) => setState(() => _showPhone = v),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        GymTextField(
          label: 'WhatsApp number',
          controller: _whatsapp,
          optional: true,
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          maxLength: 20,
        ),
        GymSection(children: [
          GymSwitchRow(
            title: 'Show WhatsApp on my profile',
            value: _showWhatsapp,
            onChanged: (v) => setState(() => _showWhatsapp = v),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        GymTextField(
          label: 'Website',
          controller: _website,
          optional: true,
          keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none,
          maxLength: 200,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'External booking link',
          controller: _booking,
          optional: true,
          hint: 'Your own booking page. Grit never books for you.',
          keyboardType: TextInputType.url,
          textCapitalization: TextCapitalization.none,
          maxLength: 500,
        ),
      ];
}
