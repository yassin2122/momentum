import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../auth/presentation/widgets/gradient_pill_button.dart';
import '../../domain/entities/trackable_exercise.dart';
import '../providers/workout_providers.dart';
import '../widgets/exercise_picker_sheet.dart';

/// Build a workout template from scratch: name it, pick exercises from the
/// library, set how many sets each starts with, save. The new template
/// shows up in "Your Plan" and in the START sheet right away.
class CreateTemplateScreen extends ConsumerStatefulWidget {
  const CreateTemplateScreen({super.key});

  @override
  ConsumerState<CreateTemplateScreen> createState() =>
      _CreateTemplateScreenState();
}

class _Item {
  _Item(this.exercise);

  final TrackableExercise exercise;
  int sets = 3;
}

class _CreateTemplateScreenState extends ConsumerState<CreateTemplateScreen> {
  final _name = TextEditingController();
  final _items = <_Item>[];
  bool _saving = false;

  static const int _minSets = 1;
  static const int _maxSets = 10;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _canSave =>
      !_saving && _name.text.trim().isNotEmpty && _items.isNotEmpty;

  Future<void> _addExercise() async {
    final picked = await showExercisePicker(context, title: 'Add exercise');
    if (picked == null || !mounted) return;
    setState(() => _items.add(_Item(picked)));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    if (!_canSave) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final result = await ref.read(workoutRepositoryProvider).createTemplate(
          name: name,
          exercises: [
            for (final i in _items) (exerciseId: i.exercise.id, sets: i.sets),
          ],
        );
    if (!mounted) return;
    result.when(
      success: (_) {
        ref.invalidate(workoutTemplatesProvider);
        _toast('"$name" saved to your templates');
        context.pop();
      },
      failure: (f) {
        setState(() => _saving = false);
        _toast(f.message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final totalSets = _items.fold<int>(0, (sum, i) => sum + i.sets);
    return HubPage(
      bottomPadding: AppSizing.buttonHeight + AppSpacing.xl3,
      bottomBar: Opacity(
        opacity: _canSave ? 1 : 0.5,
        child: IgnorePointer(
          ignoring: !_canSave,
          child: GradientPillButton(
            label: _saving ? 'Saving…' : 'Save template',
            isLoading: _saving,
            onPressed: _save,
          ),
        ),
      ),
      children: [
        Row(
          children: [
            HubBackButton(onPressed: () => context.pop()),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const HubEyebrow('TEMPLATES'),
                  Text(
                    'New template',
                    style: AppTypography.headlineMedium.copyWith(
                      color: AppColors.hubTextBright,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const _Label('Name'),
        const SizedBox(height: AppSpacing.xs),
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          maxLength: 40,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.hubTextBright),
          cursorColor: AppColors.accentProgress,
          decoration: InputDecoration(
            hintText: 'e.g. Push Day',
            hintStyle:
                AppTypography.bodyLarge.copyWith(color: AppColors.hubTextFaint),
            counterText: '',
            filled: true,
            fillColor: AppColors.hubIconButton,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm + 2,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.hubCard),
              borderSide: const BorderSide(color: AppColors.hubCardBorderStrong),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.hubCard),
              borderSide: const BorderSide(color: AppColors.accentProgress),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Row(
          children: [
            const Expanded(child: _Label('Exercises')),
            if (_items.isNotEmpty)
              Text(
                '${_items.length} exercises · $totalSets sets',
                style: AppTypography.labelMedium
                    .copyWith(color: AppColors.hubTextMuted),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        if (_items.isEmpty)
          HubCard(
            child: Text(
              'No exercises yet. Add the moves you want in this workout — '
              'you can set how many sets each one starts with.',
              style:
                  AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
            ),
          ),
        for (var i = 0; i < _items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: _ExerciseRow(
              index: i,
              item: _items[i],
              onMinus: _items[i].sets > _minSets
                  ? () => setState(() => _items[i].sets--)
                  : null,
              onPlus: _items[i].sets < _maxSets
                  ? () => setState(() => _items[i].sets++)
                  : null,
              onRemove: () => setState(() => _items.removeAt(i)),
            ),
          ),
        const SizedBox(height: AppSpacing.xs),
        HubOutlineButton(
          label: '+  Add exercise',
          onPressed: _saving ? null : _addExercise,
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.titleSmall.copyWith(
        color: AppColors.hubTextBright,
        fontWeight: AppTypography.semiBold,
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.index,
    required this.item,
    required this.onMinus,
    required this.onPlus,
    required this.onRemove,
  });

  final int index;
  final _Item item;
  final VoidCallback? onMinus;
  final VoidCallback? onPlus;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return HubCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.xxs,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          SizedBox(
            width: AppSpacing.lg,
            child: Text(
              '${index + 1}',
              style: AppTypography.numeric(AppTypography.labelLarge)
                  .copyWith(color: AppColors.accentProgress),
            ),
          ),
          Expanded(
            child: Text(
              item.exercise.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.hubTextBright),
            ),
          ),
          _StepButton(
            icon: LucideIcons.minus,
            label: 'One set fewer',
            onTap: onMinus,
          ),
          SizedBox(
            width: AppSpacing.xl + AppSpacing.xs,
            child: Text(
              '${item.sets} ${item.sets == 1 ? 'set' : 'sets'}',
              textAlign: TextAlign.center,
              style: AppTypography.numeric(AppTypography.labelMedium)
                  .copyWith(color: AppColors.hubTextBright),
            ),
          ),
          _StepButton(
            icon: LucideIcons.plus,
            label: 'One more set',
            onTap: onPlus,
          ),
          IconButton(
            tooltip: 'Remove ${item.exercise.name}',
            onPressed: onRemove,
            icon: const Icon(
              LucideIcons.x,
              size: AppSizing.iconSm,
              color: AppColors.hubTextMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: AppSpacing.lg,
        child: Container(
          width: AppSpacing.xl - 2,
          height: AppSpacing.xl - 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.hubIconButton,
            border: Border.all(color: AppColors.hubCardBorderStrong),
          ),
          child: Icon(
            icon,
            size: AppSizing.iconSm - 2,
            color: onTap == null ? AppColors.hubTextFaint : AppColors.hubTextBright,
          ),
        ),
      ),
    );
  }
}
