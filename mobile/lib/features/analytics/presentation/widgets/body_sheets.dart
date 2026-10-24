import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../workouts/domain/entities/workout_enums.dart';
import '../../../workouts/domain/services/weight_units.dart';
import '../../../workouts/presentation/providers/workout_providers.dart';
import '../../domain/entities/body_progress.dart';
import '../../domain/services/body_trend.dart';
import '../providers/analytics_providers.dart';
import 'analytics_chrome.dart';

/// Parses "72,5" or "72.5"; null when blank or not a number.
double? parseDecimal(String raw) {
  final t = raw.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  return double.tryParse(t);
}

/// Shared input styling for the analytics sheets.
InputDecoration analyticsInput({String? label, String? suffix, String? hint}) {
  OutlineInputBorder border(Color c) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        borderSide: BorderSide(color: c),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    suffixText: suffix,
    filled: true,
    fillColor: AppColors.analyticsPanelBottom,
    labelStyle: AppTypography.labelLarge.copyWith(color: AppColors.silverDim),
    hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.silverDeep),
    suffixStyle: AppTypography.labelLarge.copyWith(color: AppColors.silverDim),
    enabledBorder: border(AppColors.analyticsPanelBorder),
    focusedBorder: border(AppColors.analyticsSteel),
    errorBorder: border(AppColors.analyticsCaution),
    focusedErrorBorder: border(AppColors.analyticsCaution),
    errorStyle: AppTypography.caption.copyWith(color: AppColors.analyticsCaution),
    contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
  );
}

final _numberInput = [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))];

Future<DateTime?> pickAnalyticsDate(BuildContext context, DateTime initial,
    {DateTime? first, DateTime? last}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(now.year - 10),
    lastDate: last ?? DateTime(now.year, now.month, now.day),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.analyticsTeal,
              onPrimary: AppColors.analyticsBgBottom,
              surface: AppColors.analyticsPanelTop,
              onSurface: AppColors.silverBright,
            ),
      ),
      child: child!,
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────
// Add measurement
// ─────────────────────────────────────────────────────────────────────

class AddBodyEntrySheet extends ConsumerStatefulWidget {
  const AddBodyEntrySheet({super.key});

  @override
  ConsumerState<AddBodyEntrySheet> createState() => _AddBodyEntrySheetState();
}

class _AddBodyEntrySheetState extends ConsumerState<AddBodyEntrySheet> {
  final _controllers = {
    for (final m in BodyMeasure.values) m: TextEditingController(),
  };
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _more = false;
  bool _saving = false;
  final _errors = <BodyMeasure, String>{};
  String? _formError;

  static final _dayFormat = DateFormat('EEE d MMM yyyy');

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _save(WeightUnit unit) async {
    final values = <BodyMeasure, double>{};
    _errors.clear();
    for (final m in BodyMeasure.values) {
      final raw = _controllers[m]!.text;
      if (raw.trim().isEmpty) continue;
      final parsed = parseDecimal(raw);
      if (parsed == null) {
        _errors[m] = 'Enter a number';
        continue;
      }
      final canonical =
          m == BodyMeasure.weight ? WeightUnits.toKg(parsed, unit) : parsed;
      final (lo, hi) = m.limits;
      if (canonical < lo || canonical > hi) {
        final shownLo = m == BodyMeasure.weight
            ? WeightUnits.format(WeightUnits.fromKg(lo, unit))
            : WeightUnits.format(lo);
        final shownHi = m == BodyMeasure.weight
            ? WeightUnits.format(WeightUnits.fromKg(hi, unit))
            : WeightUnits.format(hi);
        _errors[m] = 'Between $shownLo and $shownHi';
        continue;
      }
      values[m] = canonical;
    }
    if (_errors.isNotEmpty) {
      setState(() => _formError = null);
      return;
    }
    if (values.isEmpty) {
      setState(() => _formError = 'Enter at least one measurement.');
      return;
    }
    setState(() {
      _saving = true;
      _formError = null;
    });
    final result = await ref.read(bodyProgressRepositoryProvider).addEntry(
          NewBodyEntry(loggedOn: _date, values: values, note: _note.text),
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref
          ..invalidate(bodyProgressProvider)
          // The workout logger snapshots the latest bodyweight.
          ..invalidate(workoutDefaultsProvider);
        Navigator.of(context).pop();
      },
      failure: (f) => setState(() {
        _saving = false;
        _formError = f.message;
      }),
    );
  }

  Widget _field(BodyMeasure m, WeightUnit unit) {
    return TextField(
      controller: _controllers[m],
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: _numberInput,
      style: AppTypography.numeric(AppTypography.bodyLarge)
          .copyWith(color: AppColors.silverBright),
      decoration: analyticsInput(
        label: m.label,
        suffix: m == BodyMeasure.weight ? unit.dbValue : m.unit,
      ).copyWith(errorText: _errors[m]),
      onChanged: (_) {
        if (_errors.containsKey(m)) setState(() => _errors.remove(m));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(bodyWeightUnitProvider);
    const lengths = [
      BodyMeasure.waist,
      BodyMeasure.chest,
      BodyMeasure.hips,
      BodyMeasure.arm,
      BodyMeasure.thigh,
      BodyMeasure.calf,
      BodyMeasure.neck,
    ];
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        children: [
          const AnalyticsSheetHeader(
            title: 'New measurement',
            subtitle: 'Fill in any you have — all fields are optional.',
          ),
          const SizedBox(height: AppSpacing.md),
          _DateRow(
            label: _dayFormat.format(_date),
            onTap: () async {
              final picked = await pickAnalyticsDate(context, _date);
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(child: _field(BodyMeasure.weight, unit)),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: _field(BodyMeasure.bodyFat, unit)),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            onTap: () => setState(() => _more = !_more),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Row(
                children: [
                  const Icon(LucideIcons.plus,
                      size: AppSizing.iconSm, color: AppColors.analyticsSteel),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Body measurements (cm)',
                      style: AppTypography.labelLarge
                          .copyWith(color: AppColors.silverBright),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _more ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(LucideIcons.chevronDown,
                        size: AppSizing.iconSm, color: AppColors.silverDim),
                  ),
                ],
              ),
            ),
          ),
          if (_more)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: AppSpacing.sm,
              crossAxisSpacing: AppSpacing.sm,
              childAspectRatio: 2.0,
              children: [for (final m in lengths) _field(m, unit)],
            ),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _note,
            maxLength: 280,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.silverBright),
            decoration: analyticsInput(label: 'Note (optional)'),
          ),
          if (_formError != null) ...[
            Text(_formError!,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.analyticsCaution)),
            const SizedBox(height: AppSpacing.sm),
          ],
          const SizedBox(height: AppSpacing.xs),
          AnalyticsButton(
            label: 'Save',
            accent: AppColors.analyticsSteel,
            expand: true,
            isLoading: _saving,
            onPressed: _saving ? null : () => _save(unit),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.analyticsPanelBottom,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        side: const BorderSide(color: AppColors.analyticsPanelBorder),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.medium),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              const Icon(LucideIcons.calendar,
                  size: AppSizing.iconSm, color: AppColors.silverDim),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(label,
                    style: AppTypography.bodyLarge
                        .copyWith(color: AppColors.silverBright)),
              ),
              Text('Change',
                  style: AppTypography.labelMedium
                      .copyWith(color: AppColors.silverDim)),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Goal
// ─────────────────────────────────────────────────────────────────────

class BodyGoalSheet extends ConsumerStatefulWidget {
  const BodyGoalSheet({required this.data, super.key});

  final BodyProgressData data;

  @override
  ConsumerState<BodyGoalSheet> createState() => _BodyGoalSheetState();
}

class _BodyGoalSheetState extends ConsumerState<BodyGoalSheet> {
  late final TextEditingController _target;
  DateTime? _date;
  bool _saving = false;
  String? _error;
  static final _dayFormat = DateFormat('d MMM yyyy');

  @override
  void initState() {
    super.initState();
    final g = widget.data.goal;
    final unit = ref.read(bodyWeightUnitProvider);
    _target = TextEditingController(
      text: g == null
          ? ''
          : WeightUnits.format(WeightUnits.fromKg(g.targetWeightKg, unit)),
    );
    _date = g?.targetDate;
  }

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _save(WeightUnit unit) async {
    final v = parseDecimal(_target.text);
    if (v == null) {
      setState(() => _error = 'Enter your target weight');
      return;
    }
    final kg = WeightUnits.toKg(v, unit);
    final (lo, hi) = BodyMeasure.weight.limits;
    if (kg < lo || kg > hi) {
      setState(() => _error = 'That target looks out of range');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final existing = widget.data.goal;
    final latest = BodyTrend.latest(widget.data.entries, BodyMeasure.weight);
    // Keep the original start while editing; a new goal starts from today.
    final start = existing?.startWeightKg ?? latest?.value;
    final result = await ref.read(bodyProgressRepositoryProvider).saveGoal(
          targetWeightKg: kg,
          startWeightKg: start,
          targetDate: _date,
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(bodyProgressProvider);
        Navigator.of(context).pop();
      },
      failure: (f) => setState(() {
        _saving = false;
        _error = f.message;
      }),
    );
  }

  Future<void> _remove() async {
    setState(() => _saving = true);
    final result = await ref.read(bodyProgressRepositoryProvider).clearGoal();
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(bodyProgressProvider);
        Navigator.of(context).pop();
      },
      failure: (f) => setState(() {
        _saving = false;
        _error = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(bodyWeightUnitProvider);
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AnalyticsSheetHeader(
            title: 'Bodyweight goal',
            subtitle: 'Optional. Progress is measured from your weight when '
                'you set it.',
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _target,
            autofocus: widget.data.goal == null,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: _numberInput,
            style: AppTypography.numeric(AppTypography.bodyLarge)
                .copyWith(color: AppColors.silverBright),
            decoration: analyticsInput(
                    label: 'Target weight', suffix: unit.dbValue)
                .copyWith(errorText: _error),
          ),
          const SizedBox(height: AppSpacing.sm),
          _DateRow(
            label: _date == null
                ? 'No target date'
                : 'By ${_dayFormat.format(_date!)}',
            onTap: () async {
              final picked = await pickAnalyticsDate(
                context,
                _date ?? DateTime(now.year, now.month + 3, now.day),
                first: DateTime(now.year, now.month, now.day),
                last: DateTime(now.year + 5),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          if (_date != null)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _date = null),
                child: Text('Clear date',
                    style: AppTypography.labelMedium
                        .copyWith(color: AppColors.silverDim)),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          AnalyticsButton(
            label: widget.data.goal == null ? 'Set goal' : 'Update goal',
            accent: AppColors.analyticsTeal,
            expand: true,
            isLoading: _saving,
            onPressed: _saving ? null : () => _save(unit),
          ),
          if (widget.data.goal != null) ...[
            const SizedBox(height: AppSpacing.sm),
            AnalyticsButton(
              label: 'Remove goal',
              outlined: true,
              expand: true,
              onPressed: _saving ? null : _remove,
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Photo
// ─────────────────────────────────────────────────────────────────────

class AddPhotoSheet extends ConsumerStatefulWidget {
  const AddPhotoSheet({super.key});

  @override
  ConsumerState<AddPhotoSheet> createState() => _AddPhotoSheetState();
}

class _AddPhotoSheetState extends ConsumerState<AddPhotoSheet> {
  PhotoPose _pose = PhotoPose.front;
  bool _busy = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    XFile? file;
    try {
      file = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1800,
        maxHeight: 1800,
        imageQuality: 85,
        requestFullMetadata: false,
      );
    } catch (_) {
      file = null;
      if (mounted) {
        setState(() => _error = source == ImageSource.camera
            ? "Couldn't open the camera. Check Grit's camera permission."
            : "Couldn't open your photos. Check Grit's photo permission.");
      }
    }
    if (!mounted) return;
    if (file == null) {
      setState(() => _busy = false);
      return;
    }
    final bytes = await file.readAsBytes();
    final name = file.name;
    final dot = name.lastIndexOf('.');
    final ext = dot < 0 ? 'jpg' : name.substring(dot + 1);
    final result = await ref.read(bodyProgressRepositoryProvider).addPhoto(
          bytes: bytes,
          fileExtension: ext,
          pose: _pose,
          takenOn: DateTime.now(),
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(bodyProgressProvider);
        Navigator.of(context).pop();
      },
      failure: (f) => setState(() {
        _busy = false;
        _error = f.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AnalyticsSheetHeader(
            title: 'Progress photo',
            subtitle: 'Stored privately — only you can see it. Your Captain '
                'never gets access to photos.',
          ),
          const SizedBox(height: AppSpacing.md),
          const AnalyticsLabel('Pose'),
          Wrap(
            spacing: AppSpacing.xs,
            children: [
              for (final p in PhotoPose.values)
                ChoiceChip(
                  label: Text(p.label),
                  selected: _pose == p,
                  onSelected: _busy ? null : (_) => setState(() => _pose = p),
                  labelStyle: AppTypography.labelLarge.copyWith(
                    color: _pose == p
                        ? AppColors.analyticsBgBottom
                        : AppColors.silver,
                  ),
                  selectedColor: AppColors.analyticsSteel,
                  backgroundColor: AppColors.analyticsPanelBottom,
                  side: const BorderSide(color: AppColors.analyticsPanelBorder),
                  showCheckmark: false,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_error != null) ...[
            Text(_error!,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.analyticsCaution)),
            const SizedBox(height: AppSpacing.sm),
          ],
          Row(
            children: [
              Expanded(
                child: AnalyticsButton(
                  label: 'Camera',
                  icon: LucideIcons.camera,
                  accent: AppColors.analyticsSteel,
                  isLoading: _busy,
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AnalyticsButton(
                  label: 'Library',
                  outlined: true,
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
