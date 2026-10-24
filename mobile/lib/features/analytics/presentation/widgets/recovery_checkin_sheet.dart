import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/recovery.dart';
import '../providers/analytics_providers.dart';
import 'analytics_chrome.dart';
import 'body_sheets.dart' show analyticsInput;

/// The quick daily check-in: sleep, soreness, energy, fatigue (+ optional
/// sleep quality and note). Re-opening it the same day edits that day.
class RecoveryCheckinSheet extends ConsumerStatefulWidget {
  const RecoveryCheckinSheet({this.existing, super.key});

  final RecoveryCheckin? existing;

  @override
  ConsumerState<RecoveryCheckinSheet> createState() =>
      _RecoveryCheckinSheetState();
}

class _RecoveryCheckinSheetState extends ConsumerState<RecoveryCheckinSheet> {
  late double _sleep =
      (widget.existing?.sleepHours ?? 7.5).clamp(0.0, 12.0).toDouble();
  late int? _quality = widget.existing?.sleepQuality;
  late int? _soreness = widget.existing?.soreness;
  late int? _energy = widget.existing?.energy;
  late int? _fatigue = widget.existing?.fatigue;
  late final _note = TextEditingController(text: widget.existing?.note ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  bool get _complete => _soreness != null && _energy != null && _fatigue != null;

  Future<void> _save() async {
    if (!_complete) {
      setState(() => _error = 'Rate soreness, energy and fatigue to save.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final result = await ref.read(recoveryRepositoryProvider).saveCheckin(
          RecoveryCheckin(
            id: widget.existing?.id,
            date: widget.existing?.date ?? DateTime(now.year, now.month, now.day),
            sleepHours: _sleep,
            sleepQuality: _quality,
            soreness: _soreness!,
            energy: _energy!,
            fatigue: _fatigue!,
            note: _note.text,
          ),
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(recoveryOverviewProvider);
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
    final hours = _sleep == _sleep.roundToDouble()
        ? _sleep.toStringAsFixed(0)
        : _sleep.toStringAsFixed(1);
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        children: [
          AnalyticsSheetHeader(
            title: widget.existing == null ? 'How are you today?' : 'Edit today',
            subtitle: 'About 20 seconds. Only you can see this.',
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('SLEEP',
                  style: AppTypography.overline
                      .copyWith(color: AppColors.silverDim)),
              const Spacer(),
              MetalText(hours,
                  style: AppTypography.numeric(AppTypography.displaySmall)),
              const SizedBox(width: AppSpacing.xxs),
              Text('h',
                  style: AppTypography.titleMedium
                      .copyWith(color: AppColors.silverDim)),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.analyticsDusk,
              inactiveTrackColor: AppColors.analyticsTrack,
              thumbColor: AppColors.silverBright,
              overlayColor: AppColors.analyticsDuskSoft,
              trackHeight: 4,
            ),
            child: Slider(
              value: _sleep,
              min: 0,
              max: 12,
              divisions: 24,
              label: '$hours h',
              semanticFormatterCallback: (v) => '${v.toStringAsFixed(1)} hours',
              onChanged: (v) => setState(() => _sleep = v),
            ),
          ),
          _Scale(
            title: 'Sleep quality',
            optional: true,
            low: 'Poor',
            high: 'Great',
            value: _quality,
            onChanged: (v) => setState(() => _quality = _quality == v ? null : v),
          ),
          _Scale(
            title: 'Muscle soreness',
            low: 'None',
            high: 'Very sore',
            value: _soreness,
            onChanged: (v) => setState(() => _soreness = v),
          ),
          _Scale(
            title: 'Energy',
            low: 'Very low',
            high: 'High',
            value: _energy,
            onChanged: (v) => setState(() => _energy = v),
          ),
          _Scale(
            title: 'Fatigue',
            low: 'Fresh',
            high: 'Exhausted',
            value: _fatigue,
            onChanged: (v) => setState(() => _fatigue = v),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _note,
            maxLength: 280,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.silverBright),
            decoration: analyticsInput(label: 'Note (optional)'),
          ),
          if (_error != null) ...[
            Text(_error!,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.analyticsCaution)),
            const SizedBox(height: AppSpacing.sm),
          ],
          AnalyticsButton(
            label: 'Save check-in',
            accent: AppColors.analyticsDusk,
            expand: true,
            isLoading: _saving,
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}

class _Scale extends StatelessWidget {
  const _Scale({
    required this.title,
    required this.low,
    required this.high,
    required this.value,
    required this.onChanged,
    this.optional = false,
  });

  final String title;
  final String low;
  final String high;
  final int? value;
  final ValueChanged<int> onChanged;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(title.toUpperCase(),
                  style: AppTypography.overline
                      .copyWith(color: AppColors.silverDim)),
              if (optional)
                Text('  · optional',
                    style: AppTypography.labelSmall
                        .copyWith(color: AppColors.silverDeep)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              for (var i = 1; i <= 5; i++) ...[
                if (i > 1) const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: value == i,
                    label: '$title $i of 5',
                    child: Material(
                      color: value == i
                          ? AppColors.analyticsDusk
                          : AppColors.analyticsPanelBottom,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        side: BorderSide(
                          color: value == i
                              ? AppColors.analyticsDusk
                              : AppColors.analyticsPanelBorder,
                        ),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                        onTap: () => onChanged(i),
                        child: SizedBox(
                          height: 44,
                          child: Center(
                            child: Text(
                              '$i',
                              style: AppTypography.numeric(AppTypography.titleMedium)
                                  .copyWith(
                                color: value == i
                                    ? AppColors.analyticsBgBottom
                                    : AppColors.silver,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Row(
            children: [
              Text(low,
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.silverDim)),
              const Spacer(),
              Text(high,
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.silverDim)),
            ],
          ),
        ],
      ),
    );
  }
}
