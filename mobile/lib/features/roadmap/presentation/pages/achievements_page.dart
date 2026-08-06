import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/models/achievement.dart';
import 'package:gym_app/lib/core/theme/app_colors.dart';
import 'package:gym_app/lib/core/theme/app_typography.dart';
import '../../application/achievements_providers.dart';

/// Achievements shelf. Per PRODUCT.md: "Achievements recognize progress
/// but never replace skill requirements" — every tile here is read-only
/// reflection of state earned elsewhere (workouts, streaks, certifications).
class AchievementsPage extends ConsumerWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(achievementCatalogProvider);
    final earnedAsync = ref.watch(earnedAchievementIdsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('Achievements', style: AppTypography.h3)),
      body: SafeArea(
        top: false,
        child: catalogAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text('Failed to load: $e', style: AppTypography.small)),
          data: (catalog) => earnedAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => Center(child: Text('Failed to load: $e', style: AppTypography.small)),
            data: (earned) => ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                Text('${earned.length} of ${catalog.length} unlocked', style: AppTypography.caption),
                const SizedBox(height: 18),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: catalog.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.82,
                  ),
                  itemBuilder: (context, i) {
                    final achievement = catalog[i];
                    return _AchievementTile(
                      achievement: achievement,
                      earned: earned.contains(achievement.id),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  final Achievement achievement;
  final bool earned;
  const _AchievementTile({required this.achievement, required this.earned});

  @override
  Widget build(BuildContext context) {
    // `achievement_category` enum values, not the old scaffold's invented
    // 'legendaryCertification' — 'legendary' is the real value.
    final isLegendary = achievement.category == AchievementCategory.legendary;
    final accent = earned
        ? (isLegendary ? AppColors.gold : AppColors.textPrimary)
        : AppColors.roadmapLockedNode;

    return Opacity(
      opacity: earned ? 1 : 0.5,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: earned ? 1.5 : 1),
            ),
            child: !earned
                ? const Icon(Icons.lock_outline_rounded, size: 18, color: AppColors.textMuted)
                : (achievement.iconUrl != null
                    ? ClipOval(
                        child: Image.network(
                          achievement.iconUrl!,
                          width: 28,
                          height: 28,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              Icon(Icons.emoji_events_rounded, size: 20, color: accent),
                        ),
                      )
                    : Icon(Icons.emoji_events_rounded, size: 20, color: accent)),
          ),
          const SizedBox(height: 8),
          Text(
            achievement.name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.small.copyWith(
              color: earned ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: earned ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
