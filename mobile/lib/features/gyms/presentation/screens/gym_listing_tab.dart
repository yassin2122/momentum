import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../../core/widgets/network_photo.dart';
import '../../domain/entities/gym_entities.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_ui.dart';
import 'gym_admin_screen.dart' show listingTone;

/// Listing: the public profile — cover, logo, details, facilities,
/// gallery — and the publish switch.
class GymListingTab extends ConsumerStatefulWidget {
  const GymListingTab({required this.gymId, required this.role, super.key});

  final String gymId;
  final GymStaffRole role;

  @override
  ConsumerState<GymListingTab> createState() => _GymListingTabState();
}

class _GymListingTabState extends ConsumerState<GymListingTab> {
  bool _busy = false;

  String get _gymId => widget.gymId;

  Future<void> _run(Future<bool> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final ok = await action();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) invalidateGymAdmin(ref, _gymId);
  }

  Future<GymPickedImage?> _pick(int w, int h) async {
    try {
      return await pickGymImage(minWidth: w, minHeight: h);
    } on GymImageError catch (e) {
      if (mounted) gymToast(context, e.message);
      return null;
    }
  }

  Future<bool> _report<T>(Future<Result<T>> result, String success) async {
    final r = await result;
    if (!mounted) return false;
    return r.when(
      success: (_) {
        gymToast(context, success);
        return true;
      },
      failure: (f) {
        gymToast(context, f.message);
        return false;
      },
    );
  }

  Future<void> _changeCover(GymProfile p) async {
    final img = await _pick(1200, 600);
    if (img == null) return;
    await _run(() => _report(
        ref.read(gymRepositoryProvider).setCover(p, img.bytes, img.contentType),
        'Cover updated'));
  }

  Future<void> _changeLogo(GymProfile p) async {
    final img = await _pick(256, 256);
    if (img == null) return;
    await _run(() => _report(
        ref.read(gymRepositoryProvider).setLogo(p, img.bytes, img.contentType),
        'Logo updated'));
  }

  Future<void> _addPhoto() async {
    final img = await _pick(800, 600);
    if (img == null) return;
    await _run(() => _report(
        ref.read(gymRepositoryProvider).addPhoto(_gymId, img.bytes, img.contentType),
        'Photo added'));
  }

  Future<void> _deletePhoto(GymPhoto photo) async {
    final ok = await confirmGymAction(
      context,
      title: 'Delete photo?',
      message: 'It will be removed from your gym page.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok) return;
    await _run(() =>
        _report(ref.read(gymRepositoryProvider).deletePhoto(photo), 'Photo deleted'));
  }

  Future<void> _save(GymProfile p, GymProfilePatch patch, GymListingState state) async {
    if (patch.triggersReview && state == GymListingState.published) {
      final ok = await confirmGymAction(
        context,
        title: 'Send for review?',
        message: 'Changing the name or contact details sends your page back '
            'to Grit for a quick review. It stays hidden until approved.',
        confirmLabel: 'Save',
      );
      if (!ok) return;
    }
    await _run(() =>
        _report(ref.read(gymRepositoryProvider).updateProfile(p, patch), 'Saved'));
  }

  Future<void> _setPublished(bool publish) async {
    if (!publish) {
      final ok = await confirmGymAction(
        context,
        title: 'Hide your gym page?',
        message: 'It disappears from Find a gym. Your coaches and data stay as they are.',
        confirmLabel: 'Hide',
      );
      if (!ok) return;
    }
    await _run(() async {
      final r = await ref.read(gymRepositoryProvider).setPublished(_gymId, publish);
      if (!mounted) return false;
      return r.when(
        success: (state) {
          switch (state) {
            case GymListingState.pendingReview:
              showGymSuccess(
                context,
                title: 'Sent to Grit for review',
                message: 'Grit checks new gym pages before they appear in Find a '
                    'gym. You can keep editing while you wait.',
              );
            case GymListingState.published:
              showGymSuccess(
                context,
                title: 'Your page is live',
                message: 'People can now find your gym and ask about joining.',
              );
            default:
              gymToast(context, 'Your page is hidden');
          }
          return true;
        },
        failure: (f) {
          gymToast(context, f.message);
          return false;
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(gymAdminDetailProvider(_gymId));
    final state = ref.watch(gymOverviewProvider(_gymId)).valueOrNull?.listingState ??
        GymListingState.draft;
    final role = widget.role;

    return detail.when(
      loading: () => const HubPage(children: [
        SizedBox(height: AppSpacing.xl4),
        HubLoading(),
      ]),
      error: (e, _) => HubPage(bottomPadding: AppSpacing.xl3, children: [
        const GymTitleBar(title: 'Listing'),
        const SizedBox(height: AppSpacing.md),
        HubMessageCard(
          icon: LucideIcons.circleAlert,
          title: "Couldn't load your listing",
          message: gymErrorMessage(e),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(gymAdminDetailProvider(_gymId)),
        ),
      ]),
      data: (d) {
        final p = d.profile;
        final edit = role.canEditProfile && !_busy;
        return HubPage(
          bottomPadding: AppSpacing.xl3,
          children: [
            GymTitleBar(
              title: 'Listing',
              trailing: _busy
                  ? const SizedBox(
                      width: AppSizing.iconMd,
                      height: AppSizing.iconMd,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.hubEyebrow),
                    )
                  : GymStatusPill(state.label, tone: listingTone(state)),
            ),
            const SizedBox(height: AppSpacing.md),
            // Cover with the logo overlapping it, like the public page.
            SizedBox(
              height: 200,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  GestureDetector(
                    onTap: edit ? () => _changeCover(p) : null,
                    child: Stack(
                      children: [
                        GymCover(
                          url: p.coverUrl,
                          height: 170,
                          radius: BorderRadius.circular(AppRadius.hubHero),
                        ),
                        if (edit)
                          const Positioned(
                            right: AppSpacing.xs,
                            top: AppSpacing.xs,
                            child: HubPill(
                              label: 'Change cover',
                              icon: LucideIcons.camera,
                              fill: AppColors.achScrim,
                              textColor: AppColors.hubTextBright,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: AppSpacing.md,
                    bottom: 0,
                    child: Semantics(
                      button: edit,
                      label: 'Change logo',
                      child: GestureDetector(
                        onTap: edit ? () => _changeLogo(p) : null,
                        child: GymLogo(name: p.name, url: p.logoUrl, size: 64),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Text(
                edit ? 'Tap the cover or logo to change it. Cover at least '
                    '1200 × 600 px; logo at least 256 × 256 px.' : '',
                style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextFaint),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (role.canPublish)
              GymSection(
                footer: state == GymListingState.suspended
                    ? 'Grit has paused this listing.'
                    : 'Publishing needs a description (20+ characters), a cover '
                        'photo and a branch with opening hours.',
                children: [
                  GymSwitchRow(
                    title: 'Show in Find a gym',
                    subtitle: state == GymListingState.pendingReview
                        ? 'Waiting for Grit review'
                        : null,
                    value: state.isPublishedByOwner,
                    onChanged: _busy || state == GymListingState.suspended
                        ? null
                        : _setPublished,
                  ),
                ],
              ),
            if (role.canPublish) const SizedBox(height: AppSpacing.lg),
            GymSection(
              header: 'Profile',
              children: [
                GymRow(
                  title: 'Name & headline',
                  subtitle: p.headline?.isNotEmpty == true ? p.headline : 'No headline yet',
                  value: p.name,
                  onTap: edit
                      ? () => _editFields(p, state, 'Name & headline', [
                            _Field('name', 'Gym name', p.name, max: 80),
                            _Field('headline', 'Headline', p.headline,
                                optional: true,
                                max: 90,
                                hint: 'One line, e.g. Strength gym in Maadi'),
                          ])
                      : null,
                ),
                GymRow(
                  title: 'About',
                  subtitle: p.description?.isNotEmpty == true
                      ? p.description
                      : 'Tell visitors what makes your gym different',
                  onTap: edit
                      ? () => _editFields(p, state, 'About your gym', [
                            _Field('description', 'Description', p.description,
                                optional: true, max: 1500, lines: 6),
                          ])
                      : null,
                ),
                GymRow(
                  title: 'Contact',
                  subtitle: [
                    if (p.phone?.isNotEmpty == true) p.phone!,
                    if (p.whatsapp?.isNotEmpty == true) 'WhatsApp',
                    if (p.email?.isNotEmpty == true) p.email!,
                  ].join(' · '),
                  onTap: edit
                      ? () => _editFields(p, state, 'Contact', [
                            _Field('phone', 'Phone', p.phone,
                                optional: true, max: 20, keyboard: TextInputType.phone),
                            _Field('whatsapp', 'WhatsApp', p.whatsapp,
                                optional: true, max: 20, keyboard: TextInputType.phone),
                            _Field('email', 'Email', p.email,
                                optional: true,
                                max: 120,
                                keyboard: TextInputType.emailAddress),
                            _Field('website', 'Website or Instagram', p.website,
                                optional: true, max: 200, keyboard: TextInputType.url),
                          ])
                      : null,
                ),
                GymRow(
                  title: 'Location',
                  subtitle: [
                    if (p.address?.isNotEmpty == true) p.address!,
                    if (p.area?.isNotEmpty == true) p.area!,
                    if (p.city?.isNotEmpty == true) p.city!,
                  ].join(', '),
                  onTap: edit
                      ? () => _editFields(p, state, 'Main location', [
                            _Field('address', 'Street address', p.address,
                                optional: true, max: 200),
                            _Field('area', 'Area', p.area, optional: true, max: 60),
                            _Field('city', 'City', p.city, max: 60),
                          ])
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            GymSection(
              header: 'What you offer',
              children: [
                GymRow(
                  title: 'Facilities',
                  value: p.facilities.isEmpty ? 'None' : '${p.facilities.length}',
                  onTap: edit
                      ? () => _editTags(p, state, 'Facilities', kGymFacilities,
                          p.facilities, (v) => GymProfilePatch(facilities: v))
                      : null,
                ),
                GymRow(
                  title: 'Services',
                  value: p.services.isEmpty ? 'None' : '${p.services.length}',
                  onTap: edit
                      ? () => _editTags(p, state, 'Services', kGymServices,
                          p.services, (v) => GymProfilePatch(services: v))
                      : null,
                ),
                GymRow(
                  title: 'Equipment',
                  subtitle: p.equipment.isEmpty ? null : p.equipment.join(', '),
                  value: p.equipment.isEmpty ? 'None' : null,
                  onTap: edit
                      ? () => _editFields(p, state, 'Equipment', [
                            _Field('equipment', 'Equipment', p.equipment.join(', '),
                                optional: true,
                                max: 600,
                                lines: 3,
                                hint: 'Separate with commas, e.g. Power racks, '
                                    'Hammer Strength, Rowers'),
                          ])
                      : null,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            GymSection(
              header: 'Photos',
              trailing: Text('${d.photos.length} of 12',
                  style: AppTypography.labelMedium
                      .copyWith(color: AppColors.hubTextFaint)),
              footer: 'Photos at least 800 × 600 px, up to 8 MB.',
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppSpacing.xs,
                    crossAxisSpacing: AppSpacing.xs,
                    children: [
                      for (final photo in d.photos)
                        Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.medium),
                              child: NetworkPhoto(
                                url: photo.url,
                                cacheWidth: 360,
                                placeholder:
                                    const ColoredBox(color: AppColors.hubCardBottom),
                              ),
                            ),
                            if (edit)
                              Positioned(
                                top: 0,
                                right: 0,
                                child: IconButton(
                                  tooltip: 'Delete photo',
                                  onPressed: () => _deletePhoto(photo),
                                  icon: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppColors.achScrim,
                                      border: Border.all(color: AppColors.hubCardBorderStrong),
                                    ),
                                    child: const Icon(LucideIcons.x,
                                        size: AppSizing.iconSm - 2,
                                        color: AppColors.hubTextBright),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      if (edit && d.photos.length < 12)
                        Semantics(
                          button: true,
                          label: 'Add photo',
                          child: InkWell(
                            onTap: _addPhoto,
                            borderRadius: BorderRadius.circular(AppRadius.medium),
                            child: Ink(
                              decoration: BoxDecoration(
                                color: AppColors.hubIconButton,
                                borderRadius: BorderRadius.circular(AppRadius.medium),
                                border: Border.all(color: AppColors.hubCardBorderStrong),
                              ),
                              child: const Center(
                                child: Icon(LucideIcons.imagePlus,
                                    color: AppColors.hubTextMuted),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (role.canEditOffers) ...[
              const SizedBox(height: AppSpacing.lg),
              GymSection(children: [
                GymRow(
                  icon: LucideIcons.mapPinned,
                  title: 'Branches & offers',
                  value: '${d.branches.length} · ${d.offers.length}',
                  onTap: () => context.push(AppRoutes.gymAdminBranchesPath(_gymId)),
                ),
              ]),
            ],
            if (!role.canEditProfile) ...[
              const SizedBox(height: AppSpacing.lg),
              const GymNote('Your role can view the listing but not edit it.'),
            ],
          ],
        );
      },
    );
  }

  Future<void> _editFields(
      GymProfile p, GymListingState state, String title, List<_Field> fields) async {
    final values = await showGymSheet<Map<String, String>>(
      context,
      _FieldsSheet(title: title, fields: fields),
    );
    if (values == null) return;
    String? changed(String key, String? current) {
      final v = values[key];
      if (v == null) return null;
      return v == (current ?? '') ? null : v;
    }

    final equipmentText = values['equipment'];
    final patch = GymProfilePatch(
      name: changed('name', p.name),
      headline: changed('headline', p.headline),
      description: changed('description', p.description),
      phone: changed('phone', p.phone),
      whatsapp: changed('whatsapp', p.whatsapp),
      email: changed('email', p.email),
      website: changed('website', p.website),
      address: changed('address', p.address),
      area: changed('area', p.area),
      city: changed('city', p.city),
      equipment: equipmentText == null
          ? null
          : equipmentText
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toSet()
              .toList(),
    );
    final unchanged = patch.name == null &&
        patch.headline == null &&
        patch.description == null &&
        patch.phone == null &&
        patch.whatsapp == null &&
        patch.email == null &&
        patch.website == null &&
        patch.address == null &&
        patch.area == null &&
        patch.city == null &&
        (patch.equipment == null ||
            patch.equipment!.join(',') == p.equipment.join(','));
    if (unchanged) return;
    await _save(p, patch, state);
  }

  Future<void> _editTags(GymProfile p, GymListingState state, String title,
      List<String> options, List<String> current,
      GymProfilePatch Function(List<String>) build) async {
    final picked = await showGymSheet<List<String>>(
      context,
      _TagsSheet(title: title, options: options, selected: current),
    );
    if (picked == null) return;
    await _save(p, build(picked), state);
  }
}

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
        _errors[f.key] = !f.optional && v.isEmpty
            ? 'Required'
            : f.key == 'email' && v.isNotEmpty && !v.contains('@')
                ? "That email doesn't look right"
                : null;
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
            textCapitalization: f.keyboard == null
                ? TextCapitalization.sentences
                : TextCapitalization.none,
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        const SizedBox(height: AppSpacing.xs),
        HubGradientButton(
          label: 'Save',
          height: AppSizing.buttonHeight,
          onPressed: _done,
        ),
      ],
    );
  }
}

class _TagsSheet extends StatefulWidget {
  const _TagsSheet({required this.title, required this.options, required this.selected});

  final String title;
  final List<String> options;
  final List<String> selected;

  @override
  State<_TagsSheet> createState() => _TagsSheetState();
}

class _TagsSheetState extends State<_TagsSheet> {
  late final _picked = {...widget.selected};

  @override
  Widget build(BuildContext context) {
    // Keep anything saved earlier that isn't in today's list.
    final options = {...widget.options, ...widget.selected}.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GymSheetHeader(title: widget.title, subtitle: 'Pick everything that applies.'),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final o in options)
              GymChoiceChip(
                label: o,
                selected: _picked.contains(o),
                onTap: () => setState(
                    () => _picked.contains(o) ? _picked.remove(o) : _picked.add(o)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        HubGradientButton(
          label: 'Save',
          height: AppSizing.buttonHeight,
          onPressed: () => Navigator.of(context)
              .pop([for (final o in options) if (_picked.contains(o)) o]),
        ),
      ],
    );
  }
}
