import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../widgets/activity_rings_card.dart';
import '../widgets/community_feed_section.dart';
import '../widgets/greeting_header.dart';
import '../widgets/hero_mascot_compact.dart';
import '../widgets/skill_level_card.dart';
import '../widgets/streak_card.dart';
import '../widgets/workout_banner_card.dart';

/// MOTRA Dashboard — "command center, not spreadsheet."
///
/// Five distinct content zones stacked with generous separation, each
/// with its own accent colour so the eye can parse the page without
/// reading every word (spec §1 design philosophy).
///
/// Visual hierarchy (spec §16):
///   1. Greeting + mascot — emotional/personal hook (largest bold text)
///   2. Activity rings — high colour saturation, immediate second stop
///   3. "Push Day" headline — largest headline + warm-gradient button
///   4. Skill/Level card — violet accent + "Muscle Up" headline
///   5. Community feed — social proof; placed last after the self→today→
///      growth funnel is complete
///
/// Screen-enter stagger (spec §15):
///   • Greeting + mascot fade+slide first, 400 ms easeOutCubic.
///   • Cards stagger top-to-bottom at 200 ms each, 60 ms step.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // ── Stagger helper ──────────────────────────────────────────────────────

  /// Wraps [child] in a staggered fadeIn + slideY entrance.
  /// [index] × 60 ms gives the per-row delay; the first content element
  /// (index=0) leads, later cards trail naturally behind it.
  Widget _staggered(Widget child, int index) {
    const cardDuration = Duration(milliseconds: 200);
    final delay = Duration(milliseconds: 60 * index);
    return child
        .animate()
        .fadeIn(
          delay: delay,
          duration: cardDuration,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.07,
          end: 0,
          delay: delay,
          duration: cardDuration,
          curve: Curves.easeOutCubic,
        );
  }

  // ── Background decoration ───────────────────────────────────────────────

  static const _bgDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.bgGradientTop,
        AppColors.bgGradientBottom,
      ],
    ),
  );

  // ── Stub data ───────────────────────────────────────────────────────────
  // Placeholder values; will be replaced by real data providers in Phase 2.

  static final List<CommunityPost> _posts = [
    const CommunityPost(
      authorName: 'Alex M.',
      authorInitials: 'AM',
      timestamp: '2h ago',
      caption: 'Planche training 🔥',
      likeCount: 84,
      commentCount: 12,
    ),
    const CommunityPost(
      authorName: 'Sarah K.',
      authorInitials: 'SK',
      timestamp: '4h ago',
      caption: 'Front lever progress!',
      likeCount: 61,
      commentCount: 8,
    ),
    const CommunityPost(
      authorName: 'Omar T.',
      authorInitials: 'OT',
      timestamp: '6h ago',
      caption: 'Muscle up PR 💪',
      likeCount: 120,
      commentCount: 23,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _bgDecoration,
      child: SafeArea(
        bottom: false, // nav bar clearance handled by SizedBox at bottom
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.md),

              // ── 1. Greeting header ──────────────────────────────────
              _staggered(
                const GreetingHeader(
                  userName: 'Yassin',
                  unreadNotifications: 3,
                ),
                0,
              ),

              const SizedBox(height: AppSpacing.xs),

              // ── 2. Compact mascot hero ──────────────────────────────
              const HeroMascotCompact()
                  .animate()
                  .fadeIn(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  )
                  .scaleXY(
                    begin: 0.96,
                    end: 1.0,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  ),

              const SizedBox(height: AppSpacing.sm),

              // ── 3. Top stats row: streak + rings ────────────────────
              _staggered(
                const IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Streak card (left)
                      Expanded(
                        child: StreakCard(
                          streakDays: 7,
                          subtext: 'Keep going!',
                        ),
                      ),

                      SizedBox(width: AppSpacing.sm), // 12 px gutter

                      // Activity rings card (right)
                      Expanded(
                        flex: 2,
                        child: ActivityRingsCard(
                          moveProgress: 0.775,    // 620/800 kcal
                          exerciseProgress: 0.60, // 30/50 min
                          standProgress: 0.833,   // 10/12 hrs
                          moveLabel: '620 / 800 kcal',
                          exerciseLabel: '30 / 50 min',
                          standLabel: '10 / 12 hrs',
                        ),
                      ),
                    ],
                  ),
                ),
                1,
              ),

              const SizedBox(height: AppSpacing.md),

              // ── 4. Next workout card ────────────────────────────────
              _staggered(
                const WorkoutBannerCard(
                  workoutName: 'Push Day',
                  exerciseCount: 7,
                  estimatedMinutes: 52,
                ),
                2,
              ),

              const SizedBox(height: AppSpacing.md),

              // ── 5. Skill / level card ───────────────────────────────
              _staggered(
                const SkillLevelCard(
                  skillTitle: 'Calisthenics Level',
                  skillName: 'Muscle Up',
                  level: 8,
                  xpCurrent: 350,
                  xpMax: 500,
                  nextMilestone: 'Slow Muscle Up',
                ),
                3,
              ),

              const SizedBox(height: AppSpacing.md),

              // ── 6. Community feed ───────────────────────────────────
              _staggered(
                CommunityFeedSection(posts: _posts),
                4,
              ),

              // Bottom clearance above floating nav bar (≈ 80 px nav
              // height + 16 px extra breathing room)
              const SizedBox(height: 96),
            ],
          ),
        ),
      ),
    );
  }
}
