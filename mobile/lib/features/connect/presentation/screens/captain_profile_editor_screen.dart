import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../auth/presentation/providers/auth_state_notifier.dart';
import '../../domain/entities/connect_entities.dart';
import '../providers/connect_providers.dart';
import '../widgets/coach_sheets.dart';

/// Create or edit the signed-in user's Captain profile (`coach_profiles`).
///
/// A new profile is inserted as `pending` — an admin approves it in the
/// Supabase dashboard. Status is never sent from here; a database trigger
/// rejects status changes by non-admins anyway.
class CaptainProfileEditorScreen extends ConsumerStatefulWidget {
  const CaptainProfileEditorScreen({super.key});

  @override
  ConsumerState<CaptainProfileEditorScreen> createState() =>
      _CaptainProfileEditorScreenState();
}

class _CaptainProfileEditorScreenState
    extends ConsumerState<CaptainProfileEditorScreen> {
  /// Offered as one-tap chips; Captains can type their own too.
  static const _suggestedSpecialties = [
    'Calisthenics',
    'Strength',
    'Hypertrophy',
    'Mobility',
    'Muscle-Up',
    'Handstand',
    'Front Lever',
    'Planche',
    'Beginners',
  ];

  final _formKey = GlobalKey<FormState>();
  final _headline = TextEditingController();
  final _bio = TextEditingController();
  final _approach = TextEditingController();
  final _certifications = TextEditingController();
  final _experience = TextEditingController();
  final _maxAthletes = TextEditingController();
  final _customSpecialty = TextEditingController();

  final _specialties = <String>[];
  bool _accepting = true;
  bool _listed = true;
  bool _isNew = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final hub = ref.read(captainHubProvider).valueOrNull;
    if (hub != null) {
      final p = hub.profile;
      _isNew = false;
      _headline.text = p.headline ?? '';
      _bio.text = p.bio ?? '';
      _approach.text = p.approach ?? '';
      _certifications.text = p.certifications.join(', ');
      _experience.text = p.experienceYears?.toString() ?? '';
      _maxAthletes.text = p.maxAthletes?.toString() ?? '';
      _specialties.addAll(p.specialties);
      _accepting = p.acceptingAthletes;
      _listed = p.isListed;
    }
  }

  @override
  void dispose() {
    for (final c in [
      _headline,
      _bio,
      _approach,
      _certifications,
      _experience,
      _maxAthletes,
      _customSpecialty,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _back() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.captainHub);

  void _toggleSpecialty(String s) => setState(() {
        if (!_specialties.remove(s)) _specialties.add(s);
      });

  void _addCustomSpecialty() {
    final s = _customSpecialty.text.trim();
    if (s.isEmpty) return;
    setState(() {
      if (!_specialties.contains(s)) _specialties.add(s);
      _customSpecialty.clear();
    });
  }

  int? _int(TextEditingController c) => int.tryParse(c.text.trim());

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_specialties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick at least one specialty')),
      );
      return;
    }
    final user = ref.read(authStateProvider).valueOrNull;
    if (user == null || user.isGuest) return;

    setState(() => _saving = true);
    final draft = CaptainProfileDraft(
      headline: _headline.text,
      bio: _bio.text,
      approach: _approach.text,
      specialties: List.unmodifiable(_specialties),
      certifications: _certifications.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      experienceYears: _int(_experience),
      maxAthletes: _int(_maxAthletes),
      acceptingAthletes: _accepting,
      isListed: _listed,
    );
    final result = await ref
        .read(connectRepositoryProvider)
        .saveCoachProfile(userId: user.id, draft: draft, isNew: _isNew);
    if (!mounted) return;
    setState(() => _saving = false);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    result.when(
      success: (_) {
        ref
          ..invalidate(captainHubProvider)
          ..invalidate(coachDirectoryProvider);
        messenger.showSnackBar(SnackBar(
          content: Text(_isNew
              ? 'Profile sent for review'
              : 'Coach profile saved'),
        ));
        _back();
      },
      failure: (f) => messenger.showSnackBar(SnackBar(content: Text(f.message))),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hint,
    int maxLength = 80,
    int maxLines = 1,
    bool number = false,
    String? Function(String)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: TextFormField(
        controller: controller,
        maxLength: maxLength,
        minLines: maxLines > 1 ? 3 : 1,
        maxLines: maxLines,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        inputFormatters:
            number ? [FilteringTextInputFormatter.digitsOnly] : null,
        textCapitalization: number
            ? TextCapitalization.none
            : TextCapitalization.sentences,
        style: AppTypography.bodyLarge.copyWith(color: AppColors.hubTextBright),
        cursorColor: AppColors.hubEyebrow,
        decoration: hubInputDecoration(label: label, hint: hint),
        validator: validator == null ? null : (v) => validator(v ?? ''),
      ),
    );
  }

  Widget _switch(String title, String subtitle, bool value,
      ValueChanged<bool> onChanged) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: _saving ? null : onChanged,
      activeTrackColor: AppColors.hubRing,
      title: Text(
        title,
        style: AppTypography.titleSmall.copyWith(color: AppColors.hubTextBright),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall.copyWith(color: AppColors.hubTextMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chips = <String>{..._suggestedSpecialties, ..._specialties}.toList();
    return HubPage(
      glowCenter: const Alignment(0, -0.9),
      bottomPadding: AppSpacing.xl4 + AppSpacing.xl,
      bottomBar: HubGradientButton(
        label: _isNew ? 'Submit for review' : 'Save profile',
        height: AppSizing.buttonHeight,
        isLoading: _saving,
        onPressed: _save,
      ),
      children: [
        Row(
          children: [
            HubBackButton(onPressed: _back),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _isNew ? 'Become a Coach' : 'Edit Coach profile',
                style: AppTypography.headlineMedium
                    .copyWith(color: AppColors.hubTextBright),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HubCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HubEyebrow('About you'),
                    const SizedBox(height: AppSpacing.sm),
                    _field(
                      _headline,
                      'Headline',
                      hint: 'Calisthenics coach · Muscle-Up specialist',
                      validator: (v) =>
                          v.trim().isEmpty ? 'Add a short headline' : null,
                    ),
                    _field(
                      _bio,
                      'Bio',
                      hint: 'Who you are and who you coach',
                      maxLength: 600,
                      maxLines: 6,
                    ),
                    _field(
                      _approach,
                      'Coaching approach',
                      hint: 'How you plan, check in and progress athletes',
                      maxLength: 600,
                      maxLines: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              HubCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HubEyebrow('Specialties'),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.xs,
                      runSpacing: AppSpacing.xs,
                      children: [
                        for (final s in chips)
                          FilterChip(
                            label: Text(s),
                            selected: _specialties.contains(s),
                            onSelected:
                                _saving ? null : (_) => _toggleSpecialty(s),
                            selectedColor: AppColors.hubShareOnFill,
                            backgroundColor: AppColors.hubTrack,
                            labelStyle: AppTypography.labelLarge.copyWith(
                              color: _specialties.contains(s)
                                  ? AppColors.hubShareOnText
                                  : AppColors.hubTextBody,
                            ),
                            showCheckmark: false,
                            side: BorderSide.none,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _customSpecialty,
                      maxLength: 30,
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => _addCustomSpecialty(),
                      style: AppTypography.bodyLarge
                          .copyWith(color: AppColors.hubTextBright),
                      cursorColor: AppColors.hubEyebrow,
                      decoration: hubInputDecoration(
                        label: 'Add your own',
                        hint: 'e.g. Human Flag',
                      ).copyWith(
                        suffixIcon: IconButton(
                          tooltip: 'Add specialty',
                          onPressed: _addCustomSpecialty,
                          icon: const Icon(LucideIcons.plus,
                              color: AppColors.hubEyebrow),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              HubCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HubEyebrow('Experience'),
                    const SizedBox(height: AppSpacing.sm),
                    _field(
                      _experience,
                      'Years coaching',
                      maxLength: 2,
                      number: true,
                      validator: (v) {
                        final n = int.tryParse(v.trim());
                        if (v.trim().isEmpty) return 'Add your years coaching';
                        return n == null || n > 60 ? 'Enter 0–60' : null;
                      },
                    ),
                    _field(
                      _certifications,
                      'Certifications (optional)',
                      hint: 'Separate with commas',
                      maxLength: 200,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              HubCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const HubEyebrow('Availability'),
                    const SizedBox(height: AppSpacing.sm),
                    _field(
                      _maxAthletes,
                      'Athlete limit (optional)',
                      hint: 'Leave empty for no limit',
                      maxLength: 3,
                      number: true,
                      validator: (v) {
                        if (v.trim().isEmpty) return null;
                        final n = int.tryParse(v.trim());
                        return n == null || n < 1 ? 'Enter 1 or more' : null;
                      },
                    ),
                    _switch(
                      'Accept new requests',
                      'Athletes in the directory can ask you to coach them',
                      _accepting,
                      (v) => setState(() => _accepting = v),
                    ),
                    _switch(
                      'Listed in the directory',
                      'Turn off to coach only the athletes you invite',
                      _listed,
                      (v) => setState(() => _listed = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
