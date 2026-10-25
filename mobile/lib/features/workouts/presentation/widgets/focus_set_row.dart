import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/logged_set.dart';
import '../../domain/entities/workout_enums.dart';
import '../../domain/services/weight_units.dart';

/// Column widths shared by the header and every row of the set table, so
/// they line up: SET · PREVIOUS · LOAD · REPS · ✓.
abstract final class FocusSetColumns {
  static const double set = 44;
  static const double field = 72;
  static const double check = 48;
  static const double gap = AppSpacing.xs;
}

/// One row of the set table on the active-workout screen: set badge (tap
/// for warm-up / drop / remove), last session's numbers, load and reps
/// fields, and a round check. A done row tints blue and locks its fields.
class FocusSetRow extends StatefulWidget {
  const FocusSetRow({
    super.key,
    required this.set,
    required this.workingNumber,
    required this.trackingType,
    required this.unit,
    required this.previous,
    required this.isNext,
    required this.onChanged,
    required this.onSetTypeChanged,
    required this.onToggleCompleted,
    required this.onRemove,
    this.swipeToRemove = true,
  });

  final LoggedSet set;

  /// 1-based number among working sets (warm-up / drop show W / D).
  final int workingNumber;
  final TrackingType trackingType;
  final WeightUnit unit;
  final PreviousSet? previous;

  /// The first unfinished set — its fields get a highlight.
  final bool isNext;
  final void Function(LoggedSet Function(LoggedSet) update) onChanged;
  final ValueChanged<SetType> onSetTypeChanged;
  final VoidCallback onToggleCompleted;
  final VoidCallback onRemove;

  /// Swipe left to delete the set. Turn off where a horizontal swipe means
  /// something else (the paged active-workout screen); "Remove set" stays
  /// in the set badge's menu either way.
  final bool swipeToRemove;

  /// Text for the PREVIOUS column, e.g. "70 × 8", "BW × 12", "45 s".
  static String previousText(
    PreviousSet? p,
    TrackingType type,
    WeightUnit unit,
  ) {
    if (p == null) return '—';
    if (type == TrackingType.duration) {
      return p.durationS == null ? '—' : '${p.durationS} s';
    }
    final reps = p.reps?.toString() ?? '–';
    if (!type.hasLoadInput) return 'BW × $reps';
    final load = p.loadIn(unit);
    if (load == null) return '— × $reps';
    final sign = switch (type) {
      TrackingType.weightedBodyweight => '+',
      TrackingType.assistedBodyweight => '−',
      _ => '',
    };
    return '$sign${WeightUnits.format(load)} × $reps';
  }

  @override
  State<FocusSetRow> createState() => _FocusSetRowState();
}

class _FocusSetRowState extends State<FocusSetRow> {
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
  void didUpdateWidget(FocusSetRow oldWidget) {
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

  /// Pulls outside changes (pre-fill, unit switch, "fill from last time")
  /// into the fields without fighting the user while they type.
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

  @override
  Widget build(BuildContext context) {
    final set = widget.set;
    final done = set.completed;
    final type = widget.trackingType;
    final previous =
        FocusSetRow.previousText(widget.previous, type, widget.unit);

    return Dismissible(
      key: ValueKey('dismiss-${set.id}'),
      direction: widget.swipeToRemove
          ? DismissDirection.endToStart
          : DismissDirection.none,
      onDismissed: (_) => widget.onRemove(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.errorContainer,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: const Icon(LucideIcons.trash2, color: AppColors.error),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
        decoration: BoxDecoration(
          color: done
              ? AppColors.accentProgress.withValues(alpha: 0.10)
              : AppColors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.medium),
        ),
        child: Row(
          children: [
            SizedBox(
              width: FocusSetColumns.set,
              child: Center(
                child: _SetBadge(
                  setType: set.setType,
                  workingNumber: widget.workingNumber,
                  done: done,
                  onSelected: widget.onSetTypeChanged,
                  onRemove: widget.onRemove,
                ),
              ),
            ),
            const SizedBox(width: FocusSetColumns.gap),
            Expanded(
              child: Text(
                previous,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.numeric(AppTypography.bodyMedium)
                    .copyWith(color: AppColors.hubTextMuted),
              ),
            ),
            if (type.hasLoadInput) ...[
              const SizedBox(width: FocusSetColumns.gap),
              _NumberField(
                key: ValueKey('load-${set.id}'),
                controller: _load,
                focusNode: _loadFocus,
                hint: widget.unit.dbValue,
                decimal: true,
                enabled: !done,
                highlight: widget.isNext,
                onChanged: _onLoadChanged,
              ),
            ],
            const SizedBox(width: FocusSetColumns.gap),
            _NumberField(
              key: ValueKey('reps-${set.id}'),
              controller: _reps,
              focusNode: _repsFocus,
              hint: type == TrackingType.duration ? 'sec' : 'reps',
              enabled: !done,
              highlight: widget.isNext,
              onChanged: _onRepsChanged,
            ),
            const SizedBox(width: FocusSetColumns.gap),
            SizedBox(
              width: FocusSetColumns.check,
              child: Center(
                child: _CheckButton(
                  key: ValueKey('check-${set.id}'),
                  done: done,
                  label: done
                      ? 'Set ${widget.workingNumber} done, tap to undo'
                      : 'Mark set ${widget.workingNumber} done',
                  onTap: widget.onToggleCompleted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetBadge extends StatelessWidget {
  const _SetBadge({
    required this.setType,
    required this.workingNumber,
    required this.done,
    required this.onSelected,
    required this.onRemove,
  });

  final SetType setType;
  final int workingNumber;
  final bool done;
  final ValueChanged<SetType> onSelected;
  final VoidCallback onRemove;

  Color get _color => switch (setType) {
        SetType.warmup => AppColors.warning,
        SetType.drop => AppColors.skillViolet,
        SetType.working =>
          done ? AppColors.accentProgress : AppColors.hubTextBright,
      };

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<Object>(
      tooltip: 'Set type',
      color: AppColors.achSheet,
      onSelected: (value) => value is SetType ? onSelected(value) : onRemove(),
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
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.hubTrackStrong,
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        child: Text(
          setType == SetType.working ? '$workingNumber' : setType.shortLabel,
          style: AppTypography.titleSmall.copyWith(
            color: _color,
            fontWeight: AppTypography.semiBold,
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.onChanged,
    required this.enabled,
    required this.highlight,
    this.decimal = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final bool highlight;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.medium - 2);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: c),
        );
    return SizedBox(
      width: FocusSetColumns.field,
      height: 46,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: enabled,
        textAlign: TextAlign.center,
        style: AppTypography.numeric(AppTypography.titleMedium).copyWith(
          color: AppColors.hubTextBright,
          fontWeight: AppTypography.semiBold,
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        textInputAction: TextInputAction.next,
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              decimal ? RegExp(r'^\d{0,4}([.,]\d{0,2})?') : RegExp(r'^\d{0,4}')),
        ],
        cursorColor: AppColors.accentProgress,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              AppTypography.bodyMedium.copyWith(color: AppColors.hubTextFaint),
          isDense: true,
          filled: true,
          fillColor: enabled ? AppColors.hubIconButton : AppColors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          enabledBorder: border(
            highlight ? AppColors.accentAction : AppColors.transparent,
          ),
          disabledBorder: border(AppColors.transparent),
          focusedBorder: border(AppColors.accentProgress),
        ),
        onChanged: onChanged,
      ),
    );
  }
}

class _CheckButton extends StatelessWidget {
  const _CheckButton({
    super.key,
    required this.done,
    required this.label,
    required this.onTap,
  });

  final bool done;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      checked: done,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? AppColors.accentProgress : AppColors.hubTrackStrong,
          ),
          child: Icon(
            LucideIcons.check,
            size: AppSizing.iconSm + 2,
            color: done ? AppColors.hubBackgroundBottom : AppColors.hubTextBright,
          ),
        ),
      ),
    );
  }
}
