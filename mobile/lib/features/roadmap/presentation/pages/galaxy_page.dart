import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/roadmap.dart';
import '../../../../core/logic/planet_logic.dart';
import '../../../../core/router/app_router.dart';
import 'package:gym_app/lib/core/theme/app_colors.dart';
import 'package:gym_app/lib/core/theme/app_typography.dart';
import '../../application/roadmap_providers.dart';

/// One Galaxy's (RoadmapCategory's) Skill list. Per PRODUCT.md: "Selecting
/// a Planet zooms into its roadmap. The rest of the universe fades away"
/// — and locked Planets stay visible (not hidden) so the dependency chain
/// is legible.
class GalaxyPage extends ConsumerWidget {
  final String galaxySlug;
  const GalaxyPage({super.key, required this.galaxySlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(roadmapCategoriesProvider);

    return categoriesAsync.when(
      loading: () => const _LoadingScaffold(),
      error: (e, st) => _ErrorScaffold(message: '$e'),
      data: (categories) {
        final category = categories.where((c) => c.slug == galaxySlug).firstOrNull;
        if (category == null) return const _ErrorScaffold(message: 'Galaxy not found');
        return _GalaxyBody(category: category);
      },
    );
  }
}

class _GalaxyBody extends ConsumerWidget {
  final RoadmapCategory category;
  const _GalaxyBody({required this.category});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(skillsForCategoryProvider(category.id));
    final statusAsync = ref.watch(myStatusBySkillIdProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(category.name, style: AppTypography.h3)),
      body: SafeArea(
        top: false,
        child: skillsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Failed to load: $e', style: AppTypography.small)),
          data: (skills) => statusAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Failed to load: $e', style: AppTypography.small)),
            data: (statusBySkillId) => _SkillList(
              skills: skills,
              statusBySkillId: statusBySkillId,
              galaxySlug: category.slug,
            ),
          ),
        ),
      ),
    );
  }
}

class _SkillList extends ConsumerWidget {
  final List<Skill> skills;
  final Map<String, SkillStatus> statusBySkillId;
  final String galaxySlug;
  const _SkillList({required this.skills, required this.statusBySkillId, required this.galaxySlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only top-level skills here — elite challenges surface inside their
    // parent skill's page (planet_page.dart), not this list.
    final visible = skills.where((s) => !s.isEliteChallenge).toList();

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, i) {
        final skill = visible[i];
        return _SkillTile(skill: skill, status: statusBySkillId[skill.id], galaxySlug: galaxySlug);
      },
    );
  }
}

class _SkillTile extends ConsumerWidget {
  final Skill skill;
  final SkillStatus? status;
  final String galaxySlug;
  const _SkillTile({required this.skill, required this.status, required this.galaxySlug});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prereqsAsync = ref.watch(prerequisitesForSkillProvider(skill.id));
    final statusAsync = ref.watch(myStatusBySkillIdProvider);

    return prereqsAsync.when(
      loading: () => const _TileShimmer(),
      error: (e, st) => const SizedBox.shrink(),
      data: (prereqs) => statusAsync.when(
        loading: () => const _TileShimmer(),
        error: (e, st) => const SizedBox.shrink(),
        data: (statusBySkillId) {
          final unlocked = isSkillUnlocked(skill.id, prereqs, statusBySkillId);
          return _SkillTileBody(
            skill: skill,
            unlocked: unlocked,
            status: status,
            galaxySlug: galaxySlug,
            hasPrereqs: prereqs.isNotEmpty,
          );
        },
      ),
    );
  }
}

class _TileShimmer extends StatelessWidget {
  const _TileShimmer();
  @override
  Widget build(BuildContext context) => Container(
        height: 78,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
        ),
      );
}

class _SkillTileBody extends StatelessWidget {
  final Skill skill;
  final bool unlocked;
  final SkillStatus? status;
  final String galaxySlug;
  final bool hasPrereqs;

  const _SkillTileBody({
    required this.skill,
    required this.unlocked,
    required this.status,
    required this.galaxySlug,
    required this.hasPrereqs,
  });

  @override
  Widget build(BuildContext context) {
    final hasCert = status != null && status!.meetsOrExceeds(SkillStatus.completed);
    return Opacity(
      opacity: unlocked ? 1 : 0.5,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: unlocked ? () => context.push(AppRoutes.planetFor(galaxySlug, skill.slug)) : null,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: const BoxDecoration(color: AppColors.surfaceElevated, shape: BoxShape.circle),
                child: unlocked
                    ? const Icon(Icons.fitness_center_rounded, size: 18, color: AppColors.textPrimary)
                    : const Icon(Icons.lock_outline_rounded, size: 17, color: AppColors.textMuted),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(skill.name, style: AppTypography.title),
                    if (!unlocked && hasPrereqs) ...[
                      const SizedBox(height: 3),
                      Text('Locked — complete a prerequisite skill first', style: AppTypography.small),
                    ] else if (hasCert) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: AppColors.certificationColor(status!.name),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(status!.name, style: AppTypography.small),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (unlocked) const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
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
