import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../domain/entities/exercise_entity.dart';
import '../providers/exercise_detail_provider.dart';
import 'exercise_card.dart';
import 'exercise_labels.dart';

/// Bottom sheet with an exercise's images, muscles, equipment, level and
/// step-by-step instructions. [summary] (the list row) renders instantly;
/// the full row with instructions loads behind it.
Future<void> showExerciseDetailSheet(
  BuildContext context, {
  required ExerciseEntity summary,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.hubBackgroundBottom,
    barrierColor: AppColors.achScrim,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: HubBackground(
        glowCenter: const Alignment(-0.4, -1),
        child: _DetailSheet(summary: summary),
      ),
    ),
  );
}

class _DetailSheet extends ConsumerWidget {
  const _DetailSheet({required this.summary});

  final ExerciseEntity summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(exerciseDetailProvider(summary.id));
    final e = detail.valueOrNull ?? summary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  e.name,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Close',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: AppColors.hubTextBody),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xxs,
          runSpacing: AppSpacing.xxs,
          children: [
            if (e.difficulty case final d?) DifficultyPill(difficulty: d),
            if (e.exerciseType.isNotEmpty)
              HubPill(label: ExerciseLabels.title(e.exerciseType)),
            if (e.isCustom)
              const HubPill(
                label: 'Custom',
                fill: AppColors.hubShareOffFill,
                textColor: AppColors.hubTextBody,
              ),
          ],
        ),
        if (e.images.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          _ImageStrip(urls: e.images),
        ],
        const SizedBox(height: AppSpacing.md),
        HubCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _InfoRow(
                icon: LucideIcons.target,
                label: 'Primary muscle',
                value: e.primaryMuscle.isEmpty
                    ? '—'
                    : ExerciseLabels.title(e.primaryMuscle),
              ),
              if (e.secondaryMuscles.isNotEmpty)
                _InfoRow(
                  icon: LucideIcons.circleDot,
                  label: 'Also works',
                  value: e.secondaryMuscles.map(ExerciseLabels.title).join(', '),
                ),
              _InfoRow(
                icon: LucideIcons.dumbbell,
                label: 'Equipment',
                value: e.equipment.isEmpty
                    ? 'Not specified'
                    : e.equipment.map(ExerciseLabels.title).join(', '),
              ),
              if (e.mechanics case final m?)
                _InfoRow(
                  icon: LucideIcons.settings,
                  label: 'Mechanics',
                  value: ExerciseLabels.title(m),
                ),
              if (e.force case final f?)
                _InfoRow(
                  icon: LucideIcons.arrowRight,
                  label: 'Force',
                  value: ExerciseLabels.title(f),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const HubEyebrow('How to do it'),
        const SizedBox(height: AppSpacing.sm),
        detail.when(
          loading: () => const HubLoading(),
          error: (error, _) => HubMessageCard(
            icon: LucideIcons.wifiOff,
            title: "Couldn't load instructions",
            message: ExerciseLabels.errorMessage(error),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(exerciseDetailProvider(summary.id)),
          ),
          data: (full) => _Instructions(text: full.instructions),
        ),
      ],
    );
  }
}

class _ImageStrip extends StatelessWidget {
  const _ImageStrip({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: urls.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) => ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.hubCard),
          child: AspectRatio(
            aspectRatio: 4 / 3,
            child: CachedNetworkImage(
              imageUrl: urls[i],
              fit: BoxFit.cover,
              placeholder: (_, __) =>
                  const ColoredBox(color: AppColors.hubIconButton),
              errorWidget: (_, __, ___) => const ColoredBox(
                color: AppColors.hubIconButton,
                child: Center(
                  child: Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.hubTextFaint,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs + 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizing.iconSm, color: AppColors.hubEyebrow),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppTypography.bodySmall
                  .copyWith(color: AppColors.hubTextMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.hubTextBright,
                fontWeight: AppTypography.medium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Instructions extends StatelessWidget {
  const _Instructions({required this.text});

  final String? text;

  @override
  Widget build(BuildContext context) {
    final steps = (text ?? '')
        .split(RegExp(r'\n\s*\n|\n'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (steps.isEmpty) {
      return Text(
        'No instructions for this exercise yet.',
        style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextMuted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.hubHeroGlow,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${i + 1}',
                    style: AppTypography.labelSmall.copyWith(
                      color: AppColors.hubChipText,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    steps[i],
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.hubTextBody,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
