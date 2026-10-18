import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../../core/widgets/app_filter_chip.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../domain/entities/trackable_exercise.dart';
import '../../domain/entities/workout_enums.dart';
import '../providers/workout_providers.dart';

/// Create a custom exercise (`create_custom_exercise` RPC). Pops with the
/// new exercise; the caller adds it to the workout like any other.
Future<TrackableExercise?> showCreateExerciseSheet(
  BuildContext context, {
  String initialName = '',
}) =>
    showModalBottomSheet<TrackableExercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Same canvas as the dashboard (HubBackground below).
      backgroundColor: AppColors.hubBackgroundBottom,
      barrierColor: AppColors.achScrim,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => HubBackground(
        glowCenter: const Alignment(0.4, -1),
        child: _CreateExerciseForm(initialName: initialName),
      ),
    );

class _CreateExerciseForm extends ConsumerStatefulWidget {
  const _CreateExerciseForm({required this.initialName});

  final String initialName;

  @override
  ConsumerState<_CreateExerciseForm> createState() =>
      _CreateExerciseFormState();
}

class _CreateExerciseFormState extends ConsumerState<_CreateExerciseForm> {
  late final _name = TextEditingController(text: widget.initialName);
  final _equipment = TextEditingController();
  final _bwFactor = TextEditingController(text: '1.0');
  TrackingType _type = TrackingType.weightReps;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _equipment.dispose();
    _bwFactor.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the exercise a name.');
      return;
    }
    double? bw;
    if (_type.isBodyweight) {
      bw = double.tryParse(_bwFactor.text.replaceAll(',', '.'));
      if (bw == null || bw < 0 || bw > 2) {
        setState(() => _error = 'Bodyweight factor must be between 0 and 2.');
        return;
      }
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final result =
        await ref.read(workoutRepositoryProvider).createCustomExercise(
              name: name,
              trackingType: _type,
              equipment: _equipment.text,
              bwFactor: bw,
            );
    if (!mounted) return;
    result.when(
      success: (exercise) => Navigator.of(context).pop(exercise),
      failure: (failure) => setState(() {
        _saving = false;
        _error = failure.message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New exercise', style: AppTypography.headlineSmall),
            const SizedBox(height: AppSpacing.md),
            const _Label('Name'),
            TextField(
              controller: _name,
              autofocus: widget.initialName.isEmpty,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'e.g. Landmine Press',
                counterText: '',
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            const _Label('What do you track?'),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final t in TrackingType.values)
                  AppFilterChip(
                    label: t.label,
                    isSelected: _type == t,
                    onTap: () => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const _Label('Equipment (optional)'),
            TextField(
              controller: _equipment,
              style: AppTypography.bodyLarge,
              decoration: const InputDecoration(hintText: 'e.g. Barbell'),
            ),
            if (_type.isBodyweight) ...[
              const SizedBox(height: AppSpacing.md),
              const _Label('Bodyweight factor'),
              TextField(
                controller: _bwFactor,
                style: AppTypography.bodyLarge,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d?([.,]\d{0,2})?')),
                ],
                decoration: const InputDecoration(
                  helperText:
                      'Share of your bodyweight lifted: 1.0 for a pull-up, '
                      'about 0.65 for a push-up.',
                ),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(_error!,
                  style: AppTypography.bodySmall.copyWith(color: AppColors.error)),
            ],
            const SizedBox(height: AppSpacing.lg),
            PrimaryButton(
              label: 'Create and add',
              isLoading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
        child: Text(text, style: AppTypography.labelLarge),
      );
}
