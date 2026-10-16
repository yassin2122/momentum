import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/logged_set.dart';
import '../../domain/entities/workout_enums.dart';
import '../../domain/services/weight_units.dart';

/// One set: category badge · load · reps (or seconds) · done checkbox, with
/// the matching set from last session underneath ("Last: 60 kg × 8").
class SetRow extends StatefulWidget {
  const SetRow({
    super.key,
    required this.set,
    required this.workingNumber,
    required this.trackingType,
    required this.unit,
    required this.previous,
    required this.onChanged,
    required this.onSetTypeChanged,
    required this.onToggleCompleted,
    required this.onRemove,
  });

  final LoggedSet set;

  /// 1-based number among working sets (warm-up / drop show W / D).
  final int workingNumber;
  final TrackingType trackingType;
  final WeightUnit unit;
  final PreviousSet? previous;
  final void Function(LoggedSet Function(LoggedSet) update) onChanged;
  final ValueChanged<SetType> onSetTypeChanged;
  final VoidCallback onToggleCompleted;
  final VoidCallback onRemove;

  static const double badgeWidth = 36;
  static const double checkWidth = 40;

  @override
  State<SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<SetRow> {
  final _load = TextEditingController();
  final _reps = TextEditingController();
  final _loadFocus = FocusNode();
  final _repsFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _syncControllers();
  }

  @override
  void didUpdateWidget(SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncControllers();
  }

  @override
  void dispose() {
    _load.dispose();
    _reps.dispose();
    _loadFocus.dispose();
    _repsFocus.dispose();
    super.dispose();
  }

  String get _loadText {
    final s = widget.set;
    if (s.enteredWeight == null) return '';
    return WeightUnits.format(WeightUnits.display(
      entered: s.enteredWeight!,
      enteredUnit: s.enteredUnit ?? WeightUnit.kg,
      kg: s.loadKg!,
      displayUnit: widget.unit,
    ));
  }

  String get _repsText {
    final value = widget.trackingType == TrackingType.duration
        ? widget.set.durationS
        : widget.set.reps;
    return value?.toString() ?? '';
  }

  /// Pulls external changes (pre-fill, unit toggle) into the fields without
  /// fighting the user while they type.
  void _syncControllers() {
    if (!_loadFocus.hasFocus && _load.text != _loadText) _load.text = _loadText;
    if (!_repsFocus.hasFocus && _reps.text != _repsText) _reps.text = _repsText;
  }

  void _onLoadChanged(String text) {
    final value = double.tryParse(text.replaceAll(',', '.'));
    widget.onChanged((s) => s.copyWith(
          enteredWeight: () => value,
          enteredUnit: () => value == null ? null : widget.unit,
        ));
  }

  void _onRepsChanged(String text) {
    final value = int.tryParse(text);
    widget.onChanged((s) => widget.trackingType == TrackingType.duration
        ? s.copyWith(durationS: () => value)
        : s.copyWith(reps: () => value));
  }

  String? get _previousText {
    final p = widget.previous;
    if (p == null) return null;
    final type = widget.trackingType;
    if (type == TrackingType.duration) {
      return p.durationS == null ? null : 'Last: ${p.durationS} s';
    }
    final reps = p.reps == null ? '' : ' × ${p.reps}';
    final load = p.loadIn(widget.unit);
    final loadText = load == null
        ? null
        : '${type == TrackingType.assistedBodyweight ? '−' : type == TrackingType.weightedBodyweight ? '+' : ''}'
            '${WeightUnits.format(load)} ${widget.unit.dbValue}';
    if (type.hasLoadInput && loadText != null) return 'Last: $loadText$reps';
    return p.reps == null ? null : 'Last: ${p.reps} reps';
  }

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final done = set.completed;
    final type = widget.trackingType;
    final previous = _previousText;

    return Dismissible(
      key: ValueKey('dismiss-${set.id}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        color: AppColors.errorContainer,
        child: const Icon(Icons.delete_outline, color: AppColors.error),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: done ? AppColors.successContainer : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _SetTypeBadge(
                  setType: set.setType,
                  workingNumber: widget.workingNumber,
                  onSelected: widget.onSetTypeChanged,
                  onRemove: widget.onRemove,
                ),
                const SizedBox(width: AppSpacing.xs),
                if (type.hasLoadInput) ...[
                  Expanded(
                    child: _NumberField(
                      controller: _load,
                      focusNode: _loadFocus,
                      hint: widget.unit.dbValue,
                      decimal: true,
                      enabled: !done,
                      onChanged: _onLoadChanged,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Expanded(
                  child: _NumberField(
                    controller: _reps,
                    focusNode: _repsFocus,
                    hint: type == TrackingType.duration ? 'sec' : 'reps',
                    enabled: !done,
                    onChanged: _onRepsChanged,
                  ),
                ),
                SizedBox(
                  width: SetRow.checkWidth,
                  child: Checkbox(
                    value: done,
                    onChanged: (_) => widget.onToggleCompleted(),
                    activeColor: AppColors.success,
                    checkColor: AppColors.background,
                    side: const BorderSide(color: AppColors.strokeStrong),
                  ),
                ),
              ],
            ),
            if (previous != null)
              Padding(
                padding: const EdgeInsets.only(
                  left: SetRow.badgeWidth + AppSpacing.xs,
                  top: 2,
                ),
                child: Text(previous, style: AppTypography.caption),
              ),
          ],
        ),
      ),
    );
  }
}

class _SetTypeBadge extends StatelessWidget {
  const _SetTypeBadge({
    required this.setType,
    required this.workingNumber,
    required this.onSelected,
    required this.onRemove,
  });

  final SetType setType;
  final int workingNumber;
  final ValueChanged<SetType> onSelected;
  final VoidCallback onRemove;

  Color get _color => switch (setType) {
        SetType.warmup => AppColors.warning,
        SetType.working => AppColors.textPrimary,
        SetType.drop => AppColors.accent,
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      tooltip: 'Set type',
      color: AppColors.surfaceElevated,
      onSelected: (value) =>
          value is SetType ? onSelected(value) : onRemove(),
      itemBuilder: (context) => [
        for (final t in SetType.values)
          CheckedPopupMenuItem<Object>(
            value: t,
            checked: t == setType,
            child: Text(t.label, style: AppTypography.bodyLarge),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<Object>(
          value: 'remove',
          child: Text(
            'Remove set',
            style: AppTypography.bodyLarge.copyWith(color: AppColors.error),
          ),
        ),
      ],
      child: Container(
        width: SetRow.badgeWidth,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.glassMedium,
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Text(
          setType == SetType.working ? '$workingNumber' : setType.shortLabel,
          style: AppTypography.labelLarge.copyWith(
            color: _color,
            fontWeight: AppTypography.bold,
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.enabled,
    this.decimal = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        textAlign: TextAlign.center,
        style: AppTypography.titleSmall,
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'^\d{0,4}([.,]\d{0,2})?') : RegExp(r'^\d{0,4}')),
        ],
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
