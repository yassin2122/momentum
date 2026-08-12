import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/roadmap.dart';
import '../../../../core/logic/planet_logic.dart';
import 'package:gym_app/lib/core/theme/app_colors.dart';
import 'package:gym_app/lib/core/theme/app_typography.dart';
import '../../application/roadmap_providers.dart';

/// One Skill's ("Planet's") roadmap. Direct implementation of PRODUCT.md's
/// "Skill Roadmap" + "Objective-Based Progression" + "Completion Levels"
/// sections.
///
/// IMPORTANT CHANGE from the mock version: objective checkboxes are now
/// READ-ONLY, reflecting `user_objective_progress` fetched from the
/// server. The old version let you tap to toggle completion locally — that
/// only worked because it was fake local state. Real objective completion
/// needs a `complete_objective` RPC that doesn't exist yet (flagged
/// repeatedly as an open backend item). Wire the tap handler once that
/// RPC exists.
class PlanetPage extends ConsumerWidget {
  final String planetSlug;
  const PlanetPage({super.key, required this.planetSlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(roadmapCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const _LoadingScaffold(),
      error: (e, st) => _ErrorScaffold(message: '$e'),
      data: (categories) {
        // Skill isn't looked up by category directly here — walk every
        // category's skills to find the matching slug (a skill belongs to
        // exactly one category, but we don't know which from the route).
        return _SkillResolver(planetSlug: planetSlug, categoryIds: categories.map((c) => c.id).toList());
      },
    );
  }
}

/// Resolves the slug -> Skill across all categories, then hands off to the
/// real body once found.
class _SkillResolver extends ConsumerWidget {
  final String planetSlug;
  final List<String> categoryIds;
  const _SkillResolver({required this.planetSlug, required this.categoryIds});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    for (final categoryId in categoryIds) {
      final skillsAsync = ref.watch(skillsForCategoryProvider(categoryId));
      final skills = skillsAsync.asData?.value;
      if (skills == null) return const _LoadingScaffold();
      final match = skills.where((s) => s.slug == planetSlug).firstOrNull;
      if (match != null) return _PlanetBody(skill: match);
    }
    return const _ErrorScaffold(message: 'Skill not found');
  }
}

class _PlanetBody extends ConsumerWidget {
  final Skill skill;
  const _PlanetBody({required this.skill});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stagesAsync = ref.watch(stagesForSkillProvider(skill.id));
    final objectivesAsync = ref.watch(objectivesForSkillProvider(skill.id));
    final objectiveProgressAsync = ref.watch(myObjectiveProgressForSkillProvider(skill.id));
    final statusAsync = ref.watch(myStatusBySkillIdProvider);
    final eliteAsync = ref.watch(eliteChallengesForSkillProvider(skill.id));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(skill.name, style: AppTypography.h3)),
      body: SafeArea(
        top: false,
        child: stagesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Failed to load: $e', style: AppTypography.small)),
          data: (stages) => objectivesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Failed to load: $e', style: AppTypography.small)),
            data: (objectives) => objectiveProgressAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Failed to load: $e', style: AppTypography.small)),
              data: (objectiveProgress) => statusAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Failed to load: $e', style: AppTypography.small)),
                data: (statusBySkillId) {
                  final status = statusBySkillId[skill.id];
                  final objectivesByStage = <String, List<RoadmapObjective>>{};
                  for (final o in objectives) {
                    if (o.skillStageId == null) continue;
                    objectivesByStage.putIfAbsent(o.skillStageId!, () => []).add(o);
                  }
                  final roadmap = buildRoadmapState(stages, objectivesByStage, objectiveProgress);
                  final eliteUnlocked = eliteChallengesUnlocked(status);

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
                    children: [
                      _CertificationRow(current: status),
                      const SizedBox(height: 28),
                      for (var i = 0; i < stages.length; i++)
                        _StageRow(
                          stage: stages[i],
                          objectives: objectivesByStage[stages[i].id] ?? const [],
                          completedObjectiveIds: roadmap.completedObjectiveIds,
                          index: i,
                          isLast: i == stages.length - 1,
                          unlocked: roadmap.isUnlocked(i),
                          done: roadmap.isDone(i),
                        ),
                      if (eliteUnlocked)
                        eliteAsync.when(
                          loading: () => const SizedBox.shrink(),
                          error: (e, st) => const SizedBox.shrink(),
                          data: (challenges) => challenges.isEmpty
                              ? const SizedBox.shrink()
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text('Hidden Elite Challenges', style: AppTypography.h3),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Optional. Not required for progression — for athletes chasing the ceiling.',
                                      style: AppTypography.small,
                                    ),
                                    const SizedBox(height: 16),
                                    for (final challenge in challenges) _EliteChallengeTile(skill: challenge),
                                  ],
                                ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CertificationRow extends StatelessWidget {
  final SkillStatus? current;
  const _CertificationRow({required this.current});

  static final _tiers = [SkillStatus.completed, SkillStatus.master, SkillStatus.legendary];
  static final _labels = {
    SkillStatus.completed: 'Complete',
    SkillStatus.master: 'Master',
    SkillStatus.legendary: 'Legendary',
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final level in _tiers) ...[
            Expanded(
              child: _CertPlaque(
                label: _labels[level]!,
                colorKey: level.name,
                achieved: current != null && current!.meetsOrExceeds(level),
              ),
            ),
            if (level != _tiers.last) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _CertPlaque extends StatelessWidget {
  final String label;
  final String colorKey;
  final bool achieved;
  const _CertPlaque({required this.label, required this.colorKey, required this.achieved});

  @override
  Widget build(BuildContext context) {
    final color = achieved ? AppColors.certificationColor(colorKey) : AppColors.roadmapLockedNode;
    return Column(
      children: [
        Icon(achieved ? Icons.verified_rounded : Icons.circle_outlined, size: 22, color: color),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.small.copyWith(
            color: achieved ? AppColors.textPrimary : AppColors.textMuted,
            fontWeight: achieved ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _StageRow extends ConsumerWidget {
  final SkillStage stage;
  final List<RoadmapObjective> objectives;
  final Set<String> completedObjectiveIds;
  final int index;
  final bool isLast;
  final bool unlocked;
  final bool done;

  const _StageRow({
    required this.stage,
    required this.objectives,
    required this.completedObjectiveIds,
    required this.index,
    required this.isLast,
    required this.unlocked,
    required this.done,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 14,
                height: 14,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done
                      ? AppColors.textPrimary
                      : unlocked
                          ? AppColors.background
                          : AppColors.roadmapLockedNode,
                  border: Border.all(
                    color: done
                        ? AppColors.textPrimary
                        : unlocked
                            ? AppColors.textPrimary
                            : AppColors.roadmapLockedNode,
                    width: 2,
                  ),
                ),
              ),
              if (!isLast) Expanded(child: Container(width: 2, color: AppColors.roadmapLine)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 28),
              child: Opacity(
                opacity: unlocked ? 1 : 0.45,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(stage.name, style: AppTypography.title),
                      if ((stage.description ?? '').isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(stage.description!, style: AppTypography.small),
                      ],
                      const SizedBox(height: 12),
                      for (final objective in objectives)
                        _ObjectiveRow(
                          objective: objective,
                          checked: completedObjectiveIds.contains(objective.id),
                        ),
                      const SizedBox(height: 10),
                      _StageXpBar(stage: stage, skillId: stage.skillId),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  final RoadmapObjective objective;
  final bool checked;
  const _ObjectiveRow({required this.objective, required this.checked});

  @override
  Widget build(BuildContext context) {
    // Read-only for now — see the file-level doc comment on why tapping
    // doesn't do anything yet.
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            checked ? Icons.check_circle_rounded : Icons.circle_outlined,
            size: 18,
            color: checked ? AppColors.textPrimary : AppColors.textMuted,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              objective.title,
              style: AppTypography.caption.copyWith(
                color: checked ? AppColors.textPrimary : AppColors.textSecondary,
                decoration: checked ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Visual-only progress bar, driven by the real `user_skill_stage_progress`
/// row (migration 0019) rather than a computed objective ratio — matches
/// PRODUCT.md's node-level XP bar exactly ("High Pull-Up — 680/800 XP").
class _StageXpBar extends ConsumerWidget {
  final SkillStage stage;
  final String skillId;
  const _StageXpBar({required this.stage, required this.skillId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stageProgressAsync = ref.watch(myStageProgressForSkillProvider(skillId));

    return stageProgressAsync.when(
      loading: () => const SizedBox(height: 21),
      error: (e, st) => const SizedBox.shrink(),
      data: (progressList) {
        final mine = progressList.where((p) => p.skillStageId == stage.id).firstOrNull;
        final earnedXp = mine?.currentXp ?? 0;
        final pct = stageXpPct(stage, earnedXp);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 5,
                backgroundColor: AppColors.roadmapLockedNode,
                valueColor: const AlwaysStoppedAnimation(AppColors.textSecondary),
              ),
            ),
            const SizedBox(height: 4),
            Text('$earnedXp / ${stage.xpTarget} XP', style: AppTypography.small),
          ],
        );
      },
    );
  }
}

class _EliteChallengeTile extends StatelessWidget {
  final Skill skill;
  const _EliteChallengeTile({required this.skill});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.gold.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_border_rounded, size: 18, color: AppColors.gold),
          const SizedBox(width: 12),
          Text(skill.name, style: AppTypography.body),
        ],
      ),
    );
  }
}

class _LoadingScaffold extends StatelessWidget {
  const _LoadingScaffold();
  @override
  Widget build(BuildContext context) => const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
}

class _ErrorScaffold extends StatelessWidget {
  final String message;
  const _ErrorScaffold({required this.message});
  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: Text(message, style: AppTypography.small)),
      );
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
