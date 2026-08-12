import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/models/roadmap.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:gym_app/lib/core/theme/app_colors.dart';
import 'package:gym_app/lib/core/theme/app_typography.dart';
import '../../application/roadmap_providers.dart';

/// "Fitness Universe" overview — the top level of the Progress pillar.
class RoadmapPage extends ConsumerWidget {
  const RoadmapPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(roadmapCategoriesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Fitness Universe', style: AppTypography.h1),
                      const SizedBox(height: 4),
                      Text(
                        'Every galaxy is a discipline. Every planet is a skill worth mastering.',
                        style: AppTypography.caption,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => context.push(AppRoutes.achievements),
                  icon: const Icon(Icons.emoji_events_outlined, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(height: 24),
            categoriesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, st) => Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text('Failed to load: $e', style: AppTypography.small),
              ),
              data: (categories) => Column(
                children: [for (final c in categories) _GalaxyCard(id: c.id, slug: c.slug, name: c.name)],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GalaxyCard extends ConsumerWidget {
  final String id;
  final String slug;
  final String name;
  const _GalaxyCard({required this.id, required this.slug, required this.name});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(skillsForCategoryProvider(id));

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(AppRoutes.galaxyFor(slug)),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.public_rounded, color: AppColors.primaryLight, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.title),
                    const SizedBox(height: 3),
                    skillsAsync.when(
                      loading: () => Text('…', style: AppTypography.small),
                      error: (e, st) => Text('—', style: AppTypography.small),
                      data: (skills) {
                        final count = skills.where((s) => !s.isEliteChallenge).length;
                        return Text('$count skill${count == 1 ? '' : 's'}', style: AppTypography.small);
                      },
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
