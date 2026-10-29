import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/error/result.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../domain/entities/gym_entities.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_ui.dart';

/// Branches & offers editor. Branches carry address, hours and facilities;
/// offers are the gym's own public prices (optional — "Ask the gym" when
/// left blank). Nothing here is a membership or a payment.
class GymBranchesScreen extends ConsumerWidget {
  const GymBranchesScreen({required this.gymId, super.key});

  final String gymId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(gymAdminDetailProvider(gymId));
    final role = ref.watch(gymOverviewProvider(gymId)).valueOrNull?.role;
    final canBranches = role?.canManageBranches ?? false;
    final canOffers = role?.canEditOffers ?? false;

    Future<void> openBranch(GymAdminDetail d, [GymBranch? b]) async {
      final saved = await showGymSheet<bool>(context, _BranchSheet(gymId: gymId, branch: b));
      if (saved == true && context.mounted) invalidateGymAdmin(ref, gymId);
    }

    Future<void> openOffer(GymAdminDetail d, [GymOffer? o]) async {
      final saved = await showGymSheet<bool>(
          context, _OfferSheet(gymId: gymId, offer: o, branches: d.branches));
      if (saved == true && context.mounted) invalidateGymAdmin(ref, gymId);
    }

    return async.when(
      loading: () => const HubPage(children: [
        SizedBox(height: AppSpacing.xl4),
        HubLoading(),
      ]),
      error: (e, _) => HubPage(bottomPadding: AppSpacing.xl2, children: [
        GymTitleBar(title: 'Branches & offers', onBack: () => context.pop()),
        const SizedBox(height: AppSpacing.md),
        HubMessageCard(
          icon: LucideIcons.circleAlert,
          title: "Couldn't load branches",
          message: gymErrorMessage(e),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(gymAdminDetailProvider(gymId)),
        ),
      ]),
      data: (d) {
        final branchName = {for (final b in d.branches) b.id: b.name};
        return HubPage(
          bottomPadding: AppSpacing.xl2,
          children: [
            GymTitleBar(
              eyebrow: d.profile.name,
              title: 'Branches & offers',
              onBack: () => context.pop(),
            ),
            const SizedBox(height: AppSpacing.md),
            GymSection(
              header: 'Branches',
              trailing: canBranches
                  ? HubLink(label: 'Add', onTap: () => openBranch(d))
                  : null,
              footer: 'A branch shows on your page once it has opening hours '
                  'and "Show on page" is on.',
              children: d.branches.isEmpty
                  ? [
                      GymRow(
                        icon: LucideIcons.plus,
                        title: 'Add your first branch',
                        onTap: canBranches ? () => openBranch(d) : null,
                      ),
                    ]
                  : [
                      for (final b in d.branches)
                        GymRow(
                          title: b.name,
                          subtitle: '${b.addressLabel}\n${b.hoursLabel}',
                          trailing: b.isPublished
                              ? null
                              : const GymStatusPill('Hidden'),
                          showChevron: canBranches,
                          onTap: canBranches ? () => openBranch(d, b) : null,
                        ),
                    ],
            ),
            const SizedBox(height: AppSpacing.lg),
            GymSection(
              header: 'Offers',
              trailing:
                  canOffers ? HubLink(label: 'Add', onTap: () => openOffer(d)) : null,
              footer: 'Show only prices you actually offer. Leave the price '
                  'blank to show "Ask the gym". Members join and pay at your gym.',
              children: d.offers.isEmpty
                  ? [
                      GymRow(
                        icon: LucideIcons.plus,
                        title: 'Add an offer',
                        subtitle: 'E.g. Monthly · 900 EGP, or a free trial day',
                        onTap: canOffers ? () => openOffer(d) : null,
                      ),
                    ]
                  : [
                      for (final o in d.offers)
                        GymRow(
                          title: o.name,
                          subtitle: [
                            if (o.durationText.isNotEmpty) o.durationText,
                            o.branchIds.isEmpty
                                ? 'All branches'
                                : o.branchIds
                                    .map((id) => branchName[id] ?? 'Removed branch')
                                    .join(', '),
                          ].join(' · '),
                          value: o.priceAmount == null
                              ? 'Ask the gym'
                              : gymPrice(o.priceAmount!, o.currency),
                          trailing: o.isVisible ? null : const GymStatusPill('Hidden'),
                          showChevron: canOffers,
                          onTap: canOffers ? () => openOffer(d, o) : null,
                        ),
                    ],
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Branch sheet
// ---------------------------------------------------------------------------

class _BranchSheet extends ConsumerStatefulWidget {
  const _BranchSheet({required this.gymId, this.branch});

  final String gymId;
  final GymBranch? branch;

  @override
  ConsumerState<_BranchSheet> createState() => _BranchSheetState();
}

class _BranchSheetState extends ConsumerState<_BranchSheet> {
  late final _name = TextEditingController(text: widget.branch?.name ?? '');
  late final _address = TextEditingController(text: widget.branch?.address ?? '');
  late final _area = TextEditingController(text: widget.branch?.area ?? '');
  late final _city = TextEditingController(text: widget.branch?.city ?? '');
  late final _phone = TextEditingController(text: widget.branch?.phone ?? '');
  late bool _open24h = widget.branch?.open24h ?? false;
  late bool _published = widget.branch?.isPublished ?? true;
  late final _hours = [...?widget.branch?.hours];
  late final _facilities = {...?widget.branch?.facilities};
  final _errors = <String, String?>{};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _address, _area, _city, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _errors
        ..['name'] = _name.text.trim().isEmpty ? 'Name the branch' : null
        ..['city'] = _city.text.trim().isEmpty ? 'Add the city' : null;
    });
    if (_errors.values.any((e) => e != null)) return;
    if (_published && !_open24h && _hours.isEmpty) {
      gymToast(context, 'Add opening hours, or turn on Open 24 hours, to show this branch.');
      return;
    }
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final draft = GymBranchDraft(
      name: _name.text.trim(),
      address: opt(_address),
      area: opt(_area),
      city: _city.text.trim(),
      phone: opt(_phone),
      open24h: _open24h,
      hours: _open24h ? const [] : _hours,
      facilities: [for (final f in kGymFacilities) if (_facilities.contains(f)) f],
      isPublished: _published,
    );
    setState(() => _saving = true);
    final r = await ref
        .read(gymRepositoryProvider)
        .saveBranch(widget.gymId, draft, branchId: widget.branch?.id);
    if (!mounted) return;
    setState(() => _saving = false);
    r.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (f) => gymToast(context, f.message),
    );
  }

  Future<void> _delete() async {
    final ok = await confirmGymAction(
      context,
      title: 'Delete ${widget.branch!.name}?',
      message: 'It disappears from your page. Offers linked only to it stop '
          'showing for that branch.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _saving = true);
    final r = await ref.read(gymRepositoryProvider).deleteBranch(widget.branch!.id);
    if (!mounted) return;
    setState(() => _saving = false);
    r.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (f) => gymToast(context, f.message),
    );
  }

  Future<void> _addHours() async {
    final rule = await showGymSheet<GymHours>(context, const _HoursSheet());
    if (rule != null) setState(() => _hours.add(rule));
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.branch != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GymSheetHeader(title: editing ? 'Edit branch' : 'New branch'),
        GymTextField(
          label: 'Branch name',
          controller: _name,
          error: _errors['name'],
          hint: 'E.g. Maadi',
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
            label: 'Street address', controller: _address, optional: true, maxLength: 200),
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
                maxLength: 60,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: GymTextField(
                label: 'City',
                controller: _city,
                error: _errors['city'],
                textCapitalization: TextCapitalization.words,
                maxLength: 60,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'Branch phone',
          controller: _phone,
          optional: true,
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          maxLength: 20,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymSection(
          header: 'Opening hours',
          children: [
            GymSwitchRow(
              title: 'Open 24 hours',
              value: _open24h,
              onChanged: (v) => setState(() => _open24h = v),
            ),
            if (!_open24h) ...[
              for (var i = 0; i < _hours.length; i++)
                GymRow(
                  title: _hours[i].label,
                  showChevron: false,
                  trailing: IconButton(
                    tooltip: 'Remove these hours',
                    icon: const Icon(LucideIcons.x,
                        size: AppSizing.iconSm + 2, color: AppColors.hubTextMuted),
                    onPressed: () => setState(() => _hours.removeAt(i)),
                  ),
                ),
              GymRow(
                icon: LucideIcons.plus,
                title: _hours.isEmpty ? 'Add opening hours' : 'Add more hours',
                onTap: _addHours,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Facilities at this branch',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.hubTextBody,
              fontWeight: AppTypography.semiBold,
            )),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final f in kGymFacilities)
              GymChoiceChip(
                label: f,
                selected: _facilities.contains(f),
                onTap: () => setState(() =>
                    _facilities.contains(f) ? _facilities.remove(f) : _facilities.add(f)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GymSection(children: [
          GymSwitchRow(
            title: 'Show on page',
            value: _published,
            onChanged: (v) => setState(() => _published = v),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        HubGradientButton(
          label: editing ? 'Save branch' : 'Add branch',
          height: AppSizing.buttonHeight,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
        if (editing) ...[
          const SizedBox(height: AppSpacing.xs),
          _DeleteButton(label: 'Delete branch', onPressed: _saving ? null : _delete),
        ],
      ],
    );
  }
}

/// Pick days + open/close time for one hours rule.
class _HoursSheet extends StatefulWidget {
  const _HoursSheet();

  @override
  State<_HoursSheet> createState() => _HoursSheetState();
}

class _HoursSheetState extends State<_HoursSheet> {
  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  /// Common Egyptian gym schedules (weekend = Fri & Sat), one tap each.
  static const _presets = <(String, List<int>, TimeOfDay, TimeOfDay)>[
    ('Every day · 6 am–11 pm', [0, 1, 2, 3, 4, 5, 6], TimeOfDay(hour: 6, minute: 0), TimeOfDay(hour: 23, minute: 0)),
    ('Sun–Thu · 7 am–11 pm', [0, 1, 2, 3, 4], TimeOfDay(hour: 7, minute: 0), TimeOfDay(hour: 23, minute: 0)),
    ('Fri & Sat · 10 am–10 pm', [5, 6], TimeOfDay(hour: 10, minute: 0), TimeOfDay(hour: 22, minute: 0)),
  ];
  final _picked = <int>{0, 1, 2, 3, 4};
  TimeOfDay _open = const TimeOfDay(hour: 6, minute: 0);
  TimeOfDay _close = const TimeOfDay(hour: 23, minute: 0);

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _pickTime(bool open) async {
    final t = await showTimePicker(
      context: context,
      initialTime: open ? _open : _close,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (t == null) return;
    setState(() {
      if (open) {
        _open = t;
      } else {
        _close = t;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GymSheetHeader(
          title: 'Opening hours',
          subtitle: 'Pick the days, then the times. Add another rule for days with different hours.',
        ),
        Text('Quick pick',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.hubTextMuted,
              fontWeight: AppTypography.semiBold,
            )),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (label, days, open, close) in _presets)
              GymChoiceChip(
                label: label,
                selected: _picked.length == days.length &&
                    _picked.containsAll(days) &&
                    _open == open &&
                    _close == close,
                onTap: () => setState(() {
                  _picked
                    ..clear()
                    ..addAll(days);
                  _open = open;
                  _close = close;
                }),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('Days',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.hubTextMuted,
              fontWeight: AppTypography.semiBold,
            )),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (var d = 0; d < 7; d++)
              GymChoiceChip(
                label: _days[d],
                selected: _picked.contains(d),
                onTap: () =>
                    setState(() => _picked.contains(d) ? _picked.remove(d) : _picked.add(d)),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GymSection(children: [
          GymRow(title: 'Opens', value: _fmt(_open), onTap: () => _pickTime(true)),
          GymRow(title: 'Closes', value: _fmt(_close), onTap: () => _pickTime(false)),
        ]),
        const SizedBox(height: AppSpacing.md),
        HubGradientButton(
          label: 'Add hours',
          height: AppSizing.buttonHeight,
          onPressed: _picked.isEmpty
              ? null
              : () => Navigator.of(context).pop(GymHours(
                    days: _picked.toList()..sort(),
                    open: _fmt(_open),
                    close: _fmt(_close),
                  )),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Offer sheet
// ---------------------------------------------------------------------------

class _OfferSheet extends ConsumerStatefulWidget {
  const _OfferSheet({required this.gymId, required this.branches, this.offer});

  final String gymId;
  final List<GymBranch> branches;
  final GymOffer? offer;

  @override
  ConsumerState<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends ConsumerState<_OfferSheet> {
  static const _durations = <(int?, String)>[
    (1, '1 day'),
    (30, '1 month'),
    (90, '3 months'),
    (180, '6 months'),
    (365, '1 year'),
    (null, 'No set length'),
  ];

  late final _name = TextEditingController(text: widget.offer?.name ?? '');
  late final _price = TextEditingController(
    text: widget.offer?.priceAmount == null
        ? ''
        : (widget.offer!.priceAmount! == widget.offer!.priceAmount!.roundToDouble()
            ? widget.offer!.priceAmount!.round().toString()
            : widget.offer!.priceAmount!.toString()),
  );
  late final _benefits =
      TextEditingController(text: widget.offer?.benefits.join('\n') ?? '');
  late int? _duration = widget.offer == null ? 30 : widget.offer!.durationDays;
  late bool _visible = widget.offer?.isVisible ?? true;
  late final _branchIds = {...?widget.offer?.branchIds};
  String? _nameError;
  String? _priceError;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _benefits.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final priceText = _price.text.trim().replaceAll(',', '');
    final price = priceText.isEmpty ? null : double.tryParse(priceText);
    setState(() {
      _nameError = _name.text.trim().isEmpty ? 'Name the offer' : null;
      _priceError = priceText.isNotEmpty && (price == null || price < 0)
          ? 'Enter a number, or leave it blank'
          : null;
    });
    if (_nameError != null || _priceError != null) return;
    final draft = GymOfferDraft(
      name: _name.text.trim(),
      priceAmount: price,
      durationDays: _duration,
      benefits: _benefits.text
          .split('\n')
          .map((b) => b.trim())
          .where((b) => b.isNotEmpty)
          .take(8)
          .toList(),
      branchIds: _branchIds.toList(),
      isVisible: _visible,
    );
    await _commit(
        ref.read(gymRepositoryProvider).saveOffer(widget.gymId, draft, offerId: widget.offer?.id));
  }

  Future<void> _delete() async {
    final ok = await confirmGymAction(
      context,
      title: 'Delete ${widget.offer!.name}?',
      message: 'It disappears from your page.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    await _commit(ref.read(gymRepositoryProvider).deleteOffer(widget.offer!.id));
  }

  Future<void> _commit(Future<Result<void>> call) async {
    setState(() => _saving = true);
    final r = await call;
    if (!mounted) return;
    setState(() => _saving = false);
    r.when(
      success: (_) => Navigator.of(context).pop(true),
      failure: (f) => gymToast(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.offer != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GymSheetHeader(title: editing ? 'Edit offer' : 'New offer'),
        GymTextField(
          label: 'Offer name',
          controller: _name,
          error: _nameError,
          hint: 'E.g. Monthly membership',
          maxLength: 60,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'Price (EGP)',
          controller: _price,
          error: _priceError,
          optional: true,
          hint: 'Blank shows "Ask the gym"',
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textCapitalization: TextCapitalization.none,
          maxLength: 9,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Length',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.hubTextBody,
              fontWeight: AppTypography.semiBold,
            )),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: [
            for (final (days, label) in _durations)
              GymChoiceChip(
                label: label,
                selected: _duration == days,
                onTap: () => setState(() => _duration = days),
              ),
            if (_duration != null && !_durations.any((d) => d.$1 == _duration))
              GymChoiceChip(
                label: '$_duration days',
                selected: true,
                onTap: null,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        GymTextField(
          label: 'What\'s included',
          controller: _benefits,
          optional: true,
          hint: 'One per line, e.g. Access to all classes',
          maxLines: 4,
          minLines: 2,
          maxLength: 400,
        ),
        if (widget.branches.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Text('Branches',
              style: AppTypography.labelLarge.copyWith(
                color: AppColors.hubTextBody,
                fontWeight: AppTypography.semiBold,
              )),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              GymChoiceChip(
                label: 'All branches',
                selected: _branchIds.isEmpty,
                onTap: () => setState(_branchIds.clear),
              ),
              for (final b in widget.branches)
                GymChoiceChip(
                  label: b.name,
                  selected: _branchIds.contains(b.id),
                  onTap: () => setState(() => _branchIds.contains(b.id)
                      ? _branchIds.remove(b.id)
                      : _branchIds.add(b.id)),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        GymSection(children: [
          GymSwitchRow(
            title: 'Show on page',
            value: _visible,
            onChanged: (v) => setState(() => _visible = v),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        HubGradientButton(
          label: editing ? 'Save offer' : 'Add offer',
          height: AppSizing.buttonHeight,
          isLoading: _saving,
          onPressed: _saving ? null : _save,
        ),
        if (editing) ...[
          const SizedBox(height: AppSpacing.xs),
          _DeleteButton(label: 'Delete offer', onPressed: _saving ? null : _delete),
        ],
      ],
    );
  }
}

class _DeleteButton extends StatelessWidget {
  const _DeleteButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: AppColors.hubDanger,
        minimumSize: const Size.fromHeight(AppSizing.minTouchTarget),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.pill)),
      ),
      child: Text(label,
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.hubDanger,
            fontWeight: AppTypography.semiBold,
          )),
    );
  }
}
