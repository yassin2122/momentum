import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../domain/entities/trackable_exercise.dart';
import '../providers/workout_providers.dart';
import 'create_exercise_sheet.dart';

/// Bottom sheet to pick an exercise from the library (or create a custom
/// one). Pops with the chosen [TrackableExercise].
Future<TrackableExercise?> showExercisePicker(
  BuildContext context, {
  required String title,
}) =>
    showModalBottomSheet<TrackableExercise>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.backgroundElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.9,
        child: _ExercisePicker(title: title),
      ),
    );

class _ExercisePicker extends ConsumerStatefulWidget {
  const _ExercisePicker({required this.title});

  final String title;

  @override
  ConsumerState<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<_ExercisePicker> {
  Timer? _debounce;
  String _query = '';
  bool _loading = true;
  String? _error;
  List<TrackableExercise> _results = const [];
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _search);
  }

  Future<void> _search() async {
    final id = ++_requestId;
    setState(() => _loading = true);
    final result =
        await ref.read(workoutRepositoryProvider).searchExercises(_query);
    if (!mounted || id != _requestId) return;
    setState(() {
      _loading = false;
      _error = result.failureOrNull?.message;
      _results = result.valueOrNull ?? const [];
    });
  }

  Future<void> _createCustom() async {
    final created = await showCreateExerciseSheet(
      context,
      initialName: _query.trim(),
    );
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(widget.title, style: AppTypography.headlineSmall),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          AppSearchField(
            hintText: 'Search exercises',
            onChanged: _onQueryChanged,
            onClear: () => _onQueryChanged(''),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton.icon(
            onPressed: _createCustom,
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Create custom exercise'),
            style: TextButton.styleFrom(
              alignment: Alignment.centerLeft,
              foregroundColor: AppColors.primaryBright,
              textStyle: AppTypography.labelLarge,
            ),
          ),
          const Divider(),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_loading && _results.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryBright),
      );
    }
    if (_error != null) {
      return _Message(
        text: _error!,
        actionLabel: 'Try again',
        onAction: _search,
      );
    }
    if (_results.isEmpty) {
      return _Message(
        text: _query.isEmpty
            ? 'The exercise library is empty.'
            : 'No exercises match "$_query".',
        actionLabel: 'Create "${_query.isEmpty ? 'custom exercise' : _query}"',
        onAction: _createCustom,
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, i) {
        final exercise = _results[i];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(exercise.name, style: AppTypography.titleMedium),
          subtitle: Text(
            [
              exercise.trackingType.label,
              if (exercise.equipment != null) exercise.equipment!,
            ].join(' · '),
            style: AppTypography.caption,
          ),
          trailing: exercise.isCustom
              ? Text('Custom',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.primaryBright))
              : null,
          onTap: () => Navigator.of(context).pop(exercise),
        );
      },
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: AppTypography.bodyMedium, textAlign: TextAlign.center),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(foregroundColor: AppColors.primaryBright),
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }
}
