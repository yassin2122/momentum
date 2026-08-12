import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:gym_app/lib/core/theme/app_colors.dart';
import 'package:gym_app/lib/core/theme/app_typography.dart';

import 'package:gym_app/lib/shared/widgets/progress_ring_widget.dart';
import 'package:gym_app/lib/shared/widgets/week_chain_widget.dart';
import '../../../roadmap/application/roadmap_providers.dart';
import '../../application/dashboard_providers.dart';

/// Ties Train + Progress together on one home screen (Connect/friends-feed
/// section REMOVED — Connect is deferred, see MIGRATION_NOTES.md).
///
/// IMPORTANT CHANGE: `todaysTemplateProvider` (a hardcoded "Pull Day" mock)
/// had no real replacement — there's no server-side "active template"
/// concept yet. The "Today's Workout" card is now a generic "Start a
/// workout" CTA pointing at the template list instead of guessing at one.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekPatternAsync = ref.watch(weekTrainingPatternProvider);
    final streakAsync = ref.watch(myStreakProvider);
    final disciplineAsync = ref.watch(disciplineScoreProvider);
    final disciplineTierAsync = ref.watch(disciplineTierProvider);
    final categoriesAsync = ref.watch(roadmapCategoriesProvider);

    // TODO: swap for `profiles.display_name` once a profile provider
    // exists — currently reads Supabase Auth metadata directly, which is
    // only populated if your sign-up flow passes it.
    final userName = supabase.auth.currentUser?.userMetadata?['full_name'] as String? ?? 'Athlete';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            // --- Header ---
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome back,', style: AppTypography.caption),
                      Text(userName, style: AppTypography.h1),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => context.go(AppRoutes.profile),
                  customBorder: const CircleBorder(),
                  child: CircleAvatar(
                    radius: 22,
                    backgroundColor: AppColors.surfaceElevated,
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : '?',
                      style: AppTypography.title,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // --- Streak chain ---
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: AppColors.warning, size: 18),
                      const SizedBox(width: 6),
                      streakAsync.when(
                        loading: () => Text('… day streak', style: AppTypography.title),
                        error: (e, st) => Text('— day streak', style: AppTypography.title),
                        data: (streak) =>
                            Text('${streak?.currentStreak ?? 0} day streak', style: AppTypography.title),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  weekPatternAsync.when(
                    loading: () => const SizedBox(height: 32),
                    error: (e, st) => const SizedBox.shrink(),
                    data: (pattern) => WeekChainWidget(trainedDays: pattern),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- Discipline ring ---
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: disciplineAsync.when(
                loading: () => const SizedBox(height: 72, child: Center(child: CircularProgressIndicator())),
                error: (e, st) => Text('Failed to load: $e', style: AppTypography.small),
                data: (discipline) => Row(
                  children: [
                    ProgressRingWidget(
                      pct: discipline / 100,
                      size: 72,
                      strokeWidth: 8,
                      center: Text('$discipline%', style: AppTypography.title.copyWith(fontSize: 15)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Discipline Score', style: AppTypography.title),
                          const SizedBox(height: 4),
                          disciplineTierAsync.when(
                            loading: () => const SizedBox.shrink(),
                            error: (e, st) => const SizedBox.shrink(),
                            data: (tier) => Text(tier.message, style: AppTypography.small),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Start a workout (was "Today's Workout" bound to a fake
            // template — no real "active template" concept exists yet) ---
            Text('Train', style: AppTypography.h3),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => context.push(AppRoutes.templates),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryButtonGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Text('🏋️', style: TextStyle(fontSize: 28)),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Start a workout', style: AppTypography.title.copyWith(color: Colors.white)),
                          const SizedBox(height: 2),
                          Text(
                            'Pick a template or log a free session',
                            style: AppTypography.small.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // --- Progress summary (Galaxies) ---
            Row(
              children: [
                Expanded(child: Text('Your Progress', style: AppTypography.h3)),
                TextButton(
                  onPressed: () => context.go(AppRoutes.roadmap),
                  child: Text('See all', style: AppTypography.small.copyWith(color: AppColors.primaryLight)),
                ),
              ],
            ),
            SizedBox(
              height: 92,
              child: categoriesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, st) => Center(child: Text('Failed to load: $e', style: AppTypography.small)),
                data: (categories) => ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, i) {
                    final c = categories[i];
                    return InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => context.push(AppRoutes.galaxyFor(c.slug)),
                      child: Container(
                        width: 96,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.public_rounded, color: AppColors.primaryLight, size: 20),
                            const SizedBox(height: 8),
                            Text(c.name, textAlign: TextAlign.center, style: AppTypography.small),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            // Friend Activity section REMOVED — Connect pillar deferred.
          ],
        ),
      ),
    );
  }
}
