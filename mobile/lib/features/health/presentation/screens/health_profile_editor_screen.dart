import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../gyms/presentation/widgets/gym_ui.dart';
import '../../domain/entities/health_entities.dart';
import '../providers/health_providers.dart';
import '../widgets/health_ui.dart';

/// A provider edits their public profile, qualifications and what contact
/// details are shown, then submits it for Grit's review.
class HealthProfileEditorScreen extends ConsumerStatefulWidget {
  const HealthProfileEditorScreen({required this.listingId, super.key});

  final String listingId;

  @override
  ConsumerState<HealthProfileEditorScreen> createState() => _HealthProfileEditorScreenState();
}

class _HealthProfileEditorScreenState extends ConsumerState<HealthProfileEditorScreen> {
  bool _busy = false;

  /// Switch values shown before the server confirms (Doherty Threshold):
  /// the switch moves at once and rolls back if the save fails.
  final _pending = <String, bool>{};

  Map<String, bool> _server(MyHealthProfile p) => {
        'phone': p.showPhone,
        'wa': p.showWhatsapp,
        'home': p.serviceModes.contains(HealthServiceMode.home),
      };

  Future<void> _toggle(MyHealthProfile p, String key, bool value, HealthProfilePatch patch) async {
    HapticFeedback.selectionClick();
    setState(() => _pending[key] = value);
    final r = await ref.read(healthRepositoryProvider).update(p, patch);
    if (!mounted) return;
    r.when(
      // Keep the pending value until the refreshed profile shows it.
      success: (_) => ref.invalidate(myHealthProfilesProvider),
      failure: (f) {
        setState(() => _pending.remove(key));
        gymToast(context, f.message);
      },
    );
  }

  Future<bool> _run(Future<Result<void>> Function() call, {String? done}) async {
    if (_busy) return false;
    setState(() => _busy = true);
    final r = await call();
    if (!mounted) return false;
    setState(() => _busy = false);
    return r.when(
      success: (_) {
        if (done != null) gymToast(context, done);
        ref
          ..invalidate(myHealthProfilesProvider)
          ..invalidate(healthProviderDetailProvider(widget.listingId));
        return true;
      },
      failure: (f) {
        gymToast(context, f.message);
        return false;
      },
    );
  }

  Future<void> _save(MyHealthProfile p, HealthProfilePatch patch) async {
    if (patch.triggersReview && p.state == HealthProfileState.live) {
      final ok = await confirmGymAction(
        context,
        title: 'Send for review?',
        message: 'Changing your name or contact details sends your profile back '
            'to Grit for a quick review. It\'s hidden until approved.',
        confirmLabel: 'Save',
      );
      if (!ok) return;
    }
    await _run(() => ref.read(healthRepositoryProvider).update(p, patch), done: 'Saved');
  }

  Future<void> _edit(MyHealthProfile p, String title, List<_Field> fields,
      HealthProfilePatch? Function(Map<String, String> v) build) async {
    final values = await showGymSheet<Map<String, String>>(
        context, _FieldsSheet(title: title, fields: fields));
    if (values == null) return;
    final patch = build(values);
    if (patch != null) await _save(p, patch);
  }

  Future<void> _tags(MyHealthProfile p, String title, List<String> options, List<String> current,
      HealthProfilePatch Function(List<String>) build, {bool allowCustom = true}) async {
    final picked = await showGymSheet<List<String>>(
      context,
      _TagsSheet(title: title, options: options, selected: current, allowCustom: allowCustom),
    );
    if (picked == null) return;
    await _save(p, build(picked));
  }

  Future<void> _photo(MyHealthProfile p) async {
    GymPickedImage? img;
    try {
      img = await pickGymImage(minWidth: 400, minHeight: 400);
    } on GymImageError catch (e) {
      if (mounted) gymToast(context, e.message);
      return;
    }
    if (img == null) return;
    final picked = img;
    await _run(
        () => ref.read(healthRepositoryProvider).setPhoto(p, picked.bytes, picked.contentType),
        done: 'Photo updated');
  }

  Future<void> _submit(MyHealthProfile p) async {
    final missing = p.missing;
    if (missing.isNotEmpty) {
      gymToast(context, 'Still needed: ${missing.join(', ')}.');
      return;
    }
    final ok = await _run(() => ref.read(healthRepositoryProvider).submit(p.listingId));
    if (ok && mounted) {
      await showGymSuccess(
        context,
        title: 'Sent to Grit for review',
        message: 'Grit checks every profile before athletes can see it. '
            'You can keep editing while you wait.',
      );
    }
  }

  Future<void> _setVisible(MyHealthProfile p, bool visible) async {
    if (!visible) {
      final ok = await confirmGymAction(
        context,
        title: 'Hide your profile?',
        message: 'It disappears from Find a health pro until you show it again.',
        confirmLabel: 'Hide',
      );
      if (!ok) return;
    }
    await _run(() => ref.read(healthRepositoryProvider).setVisible(p.listingId, visible),
        done: visible ? 'Your profile is visible again' : 'Your profile is hidden');
  }

  Future<void> _addCredential(MyHealthProfile p) async {
    final added = await showGymSheet<bool>(context, _CredentialSheet(listingId: p.listingId));
    if (added == true) {
      ref.invalidate(myHealthProfilesProvider);
      if (mounted) gymToast(context, 'Qualification added');
    }
  }

  /// Swipe-to-delete asks first; returns whether the row was removed.
  Future<bool> _removeCredential(HealthCredential c) async {
    final ok = await confirmGymAction(
      context,
      title: 'Remove ${c.title}?',
      message: c.status == HealthCredentialStatus.verified
          ? 'It loses its verified badge. Adding it again means another review.'
          : 'It disappears from your profile.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return false;
    return _run(() => ref.read(healthRepositoryProvider).deleteCredential(c), done: 'Removed');
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myHealthProfilesProvider);
    return mine.when(
      loading: () => const HubPage(children: [SizedBox(height: AppSpacing.xl4), HubLoading()]),
      error: (e, _) => HubPage(bottomPadding: AppSpacing.xl2, children: [
        GymTitleBar(title: 'Your profile', onBack: () => context.pop()),
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
            GymTitleBar(title: 'Your profile', onBack: () => context.pop()),
            const SizedBox(height: AppSpacing.md),
            const HubMessageCard(
              icon: LucideIcons.userX,
              title: 'Profile not found',
              message: 'It may have been removed. Contact Grit support if this looks wrong.',
            ),
          ]);
        }
        return _build(context, p);
      },
    );
  }

  Widget _build(BuildContext context, MyHealthProfile p) {
    final server = _server(p);
    _pending.removeWhere((k, v) => server[k] == v);
    bool val(String k) => _pending[k] ?? server[k]!;
    final state = p.state;
    final (tone, dot) = switch (state) {
      HealthProfileState.live => (GymTone.positive, AppColors.hubShareOnText),
      HealthProfileState.inReview => (GymTone.caution, AppColors.hubWaitText),
      HealthProfileState.suspended => (GymTone.negative, AppColors.hubDanger),
      _ => (GymTone.neutral, AppColors.hubTextMuted),
    };
    final submitted = p.submittedAt != null;

    return HubPage(
      bottomPadding: state == HealthProfileState.draft
          ? AppSizing.buttonHeight + AppSpacing.xl4
          : AppSpacing.xl2,
      bottomBar: state == HealthProfileState.draft
          ? HubGradientButton(
              label: 'Submit for review',
              height: AppSizing.buttonHeight,
              isLoading: _busy,
              onPressed: _busy ? null : () => _submit(p),
            )
          : null,
      children: [
        GymTitleBar(
          eyebrow: 'Your ${p.kind.label.toLowerCase()} profile',
          title: 'Edit profile',
          onBack: () => context.pop(),
          trailing: _busy
              ? const SizedBox(
                  width: AppSizing.iconMd,
                  height: AppSizing.iconMd,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.hubEyebrow),
                )
              : HubSquareIconButton(
                  icon: LucideIcons.eye,
                  semanticLabel: 'Preview profile',
                  onPressed: () => context.push(AppRoutes.healthProviderPath(p.listingId)),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        HubCard(
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(shape: BoxShape.circle, color: dot),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(state.title,
                        style: AppTypography.titleSmall.copyWith(
                          color: AppColors.hubTextBright,
                          fontWeight: AppTypography.bold,
                        )),
                    Text(state.explainer,
                        style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextMuted)),
                  ],
                ),
              ),
              GymStatusPill(
                switch (state) {
                  HealthProfileState.draft => 'Draft',
                  HealthProfileState.inReview => 'In review',
                  HealthProfileState.live => 'Live',
                  HealthProfileState.hidden => 'Hidden',
                  HealthProfileState.suspended => 'Suspended',
                },
                tone: tone,
              ),
            ],
          ),
        ),
        if (state != HealthProfileState.suspended && !_steps(p).every((s) => s.$2)) ...[
          const SizedBox(height: AppSpacing.sm),
          _ProgressCard(steps: _steps(p)),
        ],
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            GestureDetector(
              onTap: _busy ? null : () => _photo(p),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  HealthAvatar(name: p.name, kind: p.kind, url: p.photoUrl, size: 72),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.ctaGradientEnd,
                        border: Border.all(color: AppColors.hubBackgroundBottom, width: 2),
                      ),
                      child: const Icon(LucideIcons.camera,
                          size: AppSizing.iconSm - 2, color: AppColors.hubTextBright),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.name,
                      style: AppTypography.titleMedium.copyWith(
                        color: AppColors.hubTextBright,
                        fontWeight: AppTypography.bold,
                      )),
                  Text(
                    [p.kind.label, if (p.specialties.isNotEmpty) p.specialties.first].join(' · '),
                    style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextMuted),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _photo(p),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, AppSizing.minTouchTarget),
                      alignment: Alignment.centerLeft,
                    ),
                    child: const Text('Change photo'),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GymSection(
          header: 'Professional',
          children: [
            GymRow(
              title: 'Name & title',
              subtitle: p.headline ?? 'Add your title, e.g. Sports medicine physician',
              value: p.name,
              onTap: () => _edit(p, 'Name & title', [
                _Field('name', 'Professional name', p.name, max: 80),
                _Field('headline', 'Professional title', p.headline,
                    hint: 'e.g. Sports medicine physician', max: 120),
              ], (v) {
                final name = v['name']!;
                final headline = v['headline']!;
                if (name == p.name && headline == (p.headline ?? '')) return null;
                return HealthProfilePatch(
                  name: name == p.name ? null : name,
                  headline: headline == (p.headline ?? '') ? null : headline,
                );
              }),
            ),
            GymRow(
              title: 'Specialties',
              value: p.specialties.isEmpty ? 'None' : '${p.specialties.length}',
              subtitle: p.specialties.join(', '),
              onTap: () => _tags(p, 'Specialties', kHealthSpecialties, p.specialties,
                  (v) => HealthProfilePatch(specialties: v)),
            ),
            GymRow(
              title: 'Biography',
              subtitle: p.description ?? 'Who you work with and how',
              onTap: () => _edit(p, 'Biography', [
                _Field('description', 'Biography', p.description, optional: true, max: 1000, lines: 6,
                    hint: 'Who you work with, your approach, what to expect. No medical claims.'),
              ], (v) => v['description'] == (p.description ?? '')
                  ? null
                  : HealthProfilePatch(description: v['description'])),
            ),
            GymRow(
              title: 'Experience & languages',
              value: p.experienceYears == null ? null : '${p.experienceYears} years',
              subtitle: p.languages.isEmpty ? null : p.languages.join(', '),
              onTap: () => _edit(p, 'Experience & languages', [
                _Field('years', 'Years in practice', p.experienceYears?.toString(),
                    optional: true, max: 2, keyboard: TextInputType.number),
                _Field('languages', 'Languages', p.languages.join(', '),
                    optional: true, max: 120, hint: 'e.g. Arabic, English'),
              ], (v) {
                final years = int.tryParse(v['years']!);
                return HealthProfilePatch(
                  experienceYears: years,
                  clearExperience: v['years']!.isEmpty,
                  languages: _split(v['languages']!),
                );
              }),
            ),
            GymRow(
              title: 'Services',
              subtitle: p.services.isEmpty ? 'What you help people with' : p.services.join(', '),
              onTap: () => _edit(p, 'Services', [
                _Field('services', 'Services you offer', p.services.join(', '),
                    optional: true, max: 400, lines: 3,
                    hint: 'Separate with commas, e.g. Sports injury assessment, Return-to-training plans'),
              ], (v) => HealthProfilePatch(services: _split(v['services']!))),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GymSection(
          header: 'Qualifications',
          footer: 'Documents you upload are seen only by Grit\'s reviewers, never by athletes. '
              'Swipe left on a qualification to remove it.',
          children: [
            for (final c in p.credentials)
              Dismissible(
                key: ValueKey('credential-${c.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) => _removeCredential(c),
                background: Container(
                  color: AppColors.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: AppSpacing.lg),
                  child: const Icon(LucideIcons.trash2, color: AppColors.hubDanger),
                ),
                child: GymRow(
                  icon: LucideIcons.award,
                  title: c.title,
                  subtitle: [
                    c.kind.label,
                    if (c.subtitle.isNotEmpty) c.subtitle,
                    if (c.reviewNote != null) c.reviewNote!,
                  ].join(' · '),
                  showChevron: false,
                  trailing: switch (c.status) {
                    HealthCredentialStatus.verified => const HealthVerifiedBadge(label: 'Verified'),
                    HealthCredentialStatus.pending => const GymStatusPill('In review', tone: GymTone.caution),
                    HealthCredentialStatus.rejected => const GymStatusPill('Not verified', tone: GymTone.negative),
                    HealthCredentialStatus.submitted => const HealthSubmittedPill(),
                  },
                ),
              ),
            GymRow(
              icon: LucideIcons.plus,
              title: 'Add qualification',
              onTap: () => _addCredential(p),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GymSection(
          header: 'Practice',
          children: [
            GymRow(
              title: 'Clinic & location',
              subtitle: [
                if (p.clinicName != null) p.clinicName!,
                [p.address, p.area, p.city].whereType<String>().join(', '),
              ].where((s) => s.isNotEmpty).join(' · '),
              onTap: () => _edit(p, 'Clinic & location', [
                _Field('clinic', 'Clinic or practice name', p.clinicName, optional: true, max: 120),
                _Field('address', 'Street address', p.address, optional: true, max: 200),
                _Field('area', 'Area', p.area, optional: true, max: 80),
                _Field('city', 'City', p.city, max: 80),
              ], (v) => HealthProfilePatch(
                    clinicName: v['clinic'] == (p.clinicName ?? '') ? null : v['clinic'],
                    address: v['address'] == (p.address ?? '') ? null : v['address'],
                    area: v['area'] == (p.area ?? '') ? null : v['area'],
                    city: v['city'] == (p.city ?? '') ? null : v['city'],
                  )),
            ),
            GymSwitchRow(
              title: 'Home visits',
              subtitle: 'Shown alongside clinic visits',
              value: val('home'),
              onChanged: (v) => _toggle(
                  p,
                  'home',
                  v,
                  HealthProfilePatch(serviceModes: [
                    HealthServiceMode.clinic,
                    if (v) HealthServiceMode.home,
                  ])),
            ),
            GymRow(
              title: 'General availability',
              subtitle: p.availabilityNote ?? 'e.g. Sun–Thu · 4 pm – 10 pm',
              onTap: () => _edit(p, 'General availability', [
                _Field('note', 'When you usually see people', p.availabilityNote,
                    optional: true, max: 200,
                    hint: 'Shown as general availability, not bookable slots'),
              ], (v) => HealthProfilePatch(availabilityNote: v['note'])),
            ),
            GymRow(
              title: 'Consultation fee',
              value: p.consultationFee == null ? 'Not shown' : gymPrice(p.consultationFee!, p.feeCurrency),
              subtitle: 'Optional · shown as “set by the provider”',
              onTap: () => _edit(p, 'Consultation fee', [
                _Field('fee', 'Fee in ${p.feeCurrency}', p.consultationFee?.round().toString(),
                    optional: true, max: 8, keyboard: TextInputType.number,
                    hint: 'Leave empty to not show a fee'),
              ], (v) {
                final fee = double.tryParse(v['fee']!.replaceAll(',', ''));
                return HealthProfilePatch(consultationFee: fee, clearFee: v['fee']!.isEmpty);
              }),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        GymSection(
          header: 'Public contact',
          footer: 'Only what you switch on appears on your profile. Changing your name '
              'or contact details sends the profile back for a quick review.',
          children: [
            GymSwitchRow(
              title: 'Show phone',
              subtitle: p.phone == null
                  ? 'Add a number first'
                  : '${p.phone}${p.phoneVerified ? ' · checked by Grit' : ''}',
              value: val('phone'),
              onChanged: p.phone == null
                  ? null
                  : (v) => _toggle(p, 'phone', v, HealthProfilePatch(showPhone: v)),
            ),
            GymRow(
              title: 'Phone number',
              value: p.phone ?? 'Add',
              onTap: () => _edit(p, 'Phone number', [
                _Field('phone', 'Clinic or practice phone', p.phone,
                    optional: true, max: 20, keyboard: TextInputType.phone),
              ], (v) => v['phone'] == (p.phone ?? '') ? null : HealthProfilePatch(phone: v['phone'])),
            ),
            GymSwitchRow(
              title: 'Show WhatsApp',
              subtitle: p.whatsapp ?? 'Add a number first',
              value: val('wa'),
              onChanged: p.whatsapp == null
                  ? null
                  : (v) => _toggle(p, 'wa', v, HealthProfilePatch(showWhatsapp: v)),
            ),
            GymRow(
              title: 'WhatsApp number',
              value: p.whatsapp ?? 'Add',
              onTap: () => _edit(p, 'WhatsApp number', [
                _Field('wa', 'WhatsApp number', p.whatsapp,
                    optional: true, max: 20, keyboard: TextInputType.phone),
              ], (v) => v['wa'] == (p.whatsapp ?? '') ? null : HealthProfilePatch(whatsapp: v['wa'])),
            ),
            GymRow(
              title: 'Website',
              value: p.website == null ? 'Add' : Uri.tryParse(p.website!)?.host,
              onTap: () => _edit(p, 'Website', [
                _Field('web', 'Website', p.website, optional: true, max: 200, keyboard: TextInputType.url),
              ], (v) => v['web'] == (p.website ?? '') ? null : HealthProfilePatch(website: v['web'])),
            ),
            GymRow(
              title: 'External booking link',
              value: p.bookingUrl == null ? 'Optional' : Uri.tryParse(p.bookingUrl!)?.host,
              subtitle: 'Shown as an external website. Grit never books for you.',
              onTap: () => _edit(p, 'External booking link', [
                _Field('book', 'Your booking page', p.bookingUrl,
                    optional: true, max: 500, keyboard: TextInputType.url),
              ], (v) => v['book'] == (p.bookingUrl ?? '') ? null : HealthProfilePatch(bookingUrl: v['book'])),
            ),
          ],
        ),
        if (submitted && state != HealthProfileState.suspended) ...[
          const SizedBox(height: AppSpacing.lg),
          GymSection(children: [
            GymSwitchRow(
              title: 'Show in Find a health pro',
              subtitle: state == HealthProfileState.inReview ? 'Visible once Grit approves it' : null,
              value: p.isPublished,
              onChanged: _busy ? null : (v) => _setVisible(p, v),
            ),
          ]),
        ],
      ],
    );
  }
}

/// Setup steps shown as a progress bar (Goal-Gradient): the four the review
/// needs, plus a photo and a practising licence, which build trust.
List<(String, bool, bool)> _steps(MyHealthProfile p) => [
      ('Professional title', (p.headline ?? '').trim().length >= 3, true),
      ('Biography (40+ characters)', (p.description ?? '').trim().length >= 40, true),
      ('At least one specialty', p.specialties.isNotEmpty, true),
      ('A public way to reach you', !p.missing.contains('A public way to reach you'), true),
      ('Profile photo', p.photoUrl != null, false),
      ('Practising licence', p.credentials.any((c) => c.kind == HealthCredentialKind.license), false),
    ];

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.steps});

  /// (label, done, required)
  final List<(String, bool, bool)> steps;

  @override
  Widget build(BuildContext context) {
    final done = steps.where((s) => s.$2).length;
    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('Your profile',
                  style: AppTypography.titleSmall.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.bold,
                  )),
              const Spacer(),
              Text('$done of ${steps.length}',
                  style: AppTypography.labelLarge.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.semiBold,
                  )),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          HubProgressBar(value: done / steps.length),
          const SizedBox(height: AppSpacing.sm),
          for (final (label, ok, needed) in steps)
            if (!ok)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(LucideIcons.circle,
                        size: AppSizing.iconSm,
                        color: needed ? AppColors.hubWaitText : AppColors.hubTextFaint),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(label,
                          style: AppTypography.labelLarge.copyWith(color: AppColors.hubTextBody)),
                    ),
                    Text(needed ? 'Needed to submit' : 'Recommended',
                        style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextFaint)),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

List<String> _split(String text) =>
    text.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet().toList();

class _Field {
  const _Field(this.key, this.label, this.initial,
      {this.optional = false, this.max, this.lines = 1, this.hint, this.keyboard});

  final String key;
  final String label;
  final String? initial;
  final bool optional;
  final int? max;
  final int lines;
  final String? hint;
  final TextInputType? keyboard;
}

class _FieldsSheet extends StatefulWidget {
  const _FieldsSheet({required this.title, required this.fields});

  final String title;
  final List<_Field> fields;

  @override
  State<_FieldsSheet> createState() => _FieldsSheetState();
}

class _FieldsSheetState extends State<_FieldsSheet> {
  late final _controllers = {
    for (final f in widget.fields) f.key: TextEditingController(text: f.initial ?? ''),
  };
  final _errors = <String, String?>{};

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _done() {
    setState(() {
      for (final f in widget.fields) {
        final v = _controllers[f.key]!.text.trim();
        _errors[f.key] = !f.optional && v.isEmpty ? 'Required' : null;
      }
    });
    if (_errors.values.any((e) => e != null)) return;
    Navigator.of(context).pop({
      for (final f in widget.fields) f.key: _controllers[f.key]!.text.trim(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GymSheetHeader(title: widget.title),
        for (final f in widget.fields) ...[
          GymTextField(
            label: f.label,
            controller: _controllers[f.key]!,
            error: _errors[f.key],
            optional: f.optional,
            maxLength: f.max,
            maxLines: f.lines,
            minLines: f.lines > 1 ? 2 : null,
            hint: f.hint,
            keyboardType: f.lines > 1 ? TextInputType.multiline : f.keyboard,
            textCapitalization:
                f.keyboard == null ? TextCapitalization.sentences : TextCapitalization.none,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        HubGradientButton(label: 'Save', height: AppSizing.buttonHeight, onPressed: _done),
      ],
    );
  }
}

class _TagsSheet extends StatefulWidget {
  const _TagsSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.allowCustom,
  });

  final String title;
  final List<String> options;
  final List<String> selected;
  final bool allowCustom;

  @override
  State<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<_TagsSheet> {
  late final _options = {...widget.options, ...widget.selected}.toList();
  late final _picked = {...widget.selected};
  final _custom = TextEditingController();

  @override
  void dispose() {
    _custom.dispose();
    super.dispose();
  }

  void _addCustom() {
    final t = _custom.text.trim();
    if (t.length < 2) return;
    setState(() {
      if (!_options.contains(t)) _options.add(t);
      _picked.add(t);
      _custom.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GymSheetHeader(title: widget.title, subtitle: 'Pick everything that applies.'),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final o in _options)
              GymChoiceChip(
                label: o,
                selected: _picked.contains(o),
                onTap: () => setState(() => _picked.contains(o) ? _picked.remove(o) : _picked.add(o)),
              ),
          ],
        ),
        if (widget.allowCustom) ...[
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: GymTextField(label: 'Add your own', controller: _custom, maxLength: 60),
              ),
              const SizedBox(width: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                child: HubSquareIconButton(
                  icon: LucideIcons.plus,
                  semanticLabel: 'Add',
                  onPressed: _addCustom,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        HubGradientButton(
          label: 'Save',
          height: AppSizing.buttonHeight,
          onPressed: () => Navigator.of(context)
              .pop([for (final o in _options) if (_picked.contains(o)) o]),
        ),
      ],
    );
  }
}

/// Add a qualification; optionally attach a photo or scan for Grit to
/// verify (private — reviewers only).
class _CredentialSheet extends ConsumerStatefulWidget {
  const _CredentialSheet({required this.listingId});

  final String listingId;

  @override
  ConsumerState<_CredentialSheet> createState() => _CredentialSheetState();
}

class _CredentialSheetState extends ConsumerState<_CredentialSheet> {
  HealthCredentialKind _kind = HealthCredentialKind.license;
  final _title = TextEditingController();
  final _issuer = TextEditingController();
  final _year = TextEditingController();
  bool _verify = true;
  Uint8List? _doc;
  String? _docType;
  String? _docName;
  String? _titleError;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _issuer.dispose();
    _year.dispose();
    super.dispose();
  }

  Future<void> _pickDocument() async {
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.lengthInBytes > 10 * 1024 * 1024) {
        if (mounted) gymToast(context, 'That file is over 10 MB.');
        return;
      }
      setState(() {
        _doc = bytes;
        _docType = file.name.toLowerCase().endsWith('.png') ? 'image/png' : 'image/jpeg';
        _docName = file.name;
      });
    } catch (_) {
      if (mounted) gymToast(context, "Couldn't open your photos. Check Grit's photo permission.");
    }
  }

  Future<void> _save() async {
    setState(() => _titleError = _title.text.trim().length < 2 ? 'Add the title' : null);
    if (_titleError != null) return;
    if (_verify && _doc == null) {
      gymToast(context, 'Add a photo of the document, or turn off "Ask Grit to verify".');
      return;
    }
    setState(() => _saving = true);
    final r = await ref.read(healthRepositoryProvider).addCredential(
          widget.listingId,
          HealthCredentialDraft(
            kind: _kind,
            title: _title.text,
            issuer: _issuer.text,
            year: int.tryParse(_year.text.trim()),
          ),
          document: _verify ? _doc : null,
          documentType: _docType,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    r.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (f) => gymToast(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GymSheetHeader(title: 'Add qualification'),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final k in HealthCredentialKind.values)
              GymChoiceChip(
                label: k.label,
                selected: _kind == k,
                onTap: () => setState(() => _kind = k),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GymTextField(
          label: 'Title',
          controller: _title,
          error: _titleError,
          hint: _kind == HealthCredentialKind.license ? 'e.g. Licence to practise medicine' : null,
          maxLength: 120,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(label: 'Issued by', controller: _issuer, optional: true, maxLength: 120),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'Year',
          controller: _year,
          optional: true,
          keyboardType: TextInputType.number,
          textCapitalization: TextCapitalization.none,
          maxLength: 4,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymSection(
          children: [
            GymSwitchRow(
              title: 'Ask Grit to verify',
              subtitle: 'Upload a photo or scan for our reviewers',
              value: _verify,
              onChanged: (v) => setState(() => _verify = v),
            ),
            if (_verify)
              GymRow(
                icon: LucideIcons.fileUp,
                title: _docName ?? 'Add a photo of the document',
                subtitle: _doc == null ? 'JPG or PNG, up to 10 MB · private' : 'Private · reviewers only',
                onTap: _pickDocument,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          _verify
              ? 'Shown as “In review” until checked, then with a verified badge.'
              : 'It will appear on your profile marked “Provider-submitted”.',
          style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextMuted),
        ),
        const SizedBox(height: AppSpacing.sm),
        const GymNote(
          'Don\'t upload patient information. Grit only needs proof of the qualification itself.',
          icon: LucideIcons.lock,
        ),
        const SizedBox(height: AppSpacing.md),
        HubGradientButton(
          label: 'Add',
          height: AppSizing.buttonHeight,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
