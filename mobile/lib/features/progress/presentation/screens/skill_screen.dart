import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../connect/presentation/providers/connect_providers.dart';
import '../sample/progress_sample_data.dart';
import '../widgets/skill_ring.dart';

/// Skill detail: progress ring, certification tiers, objectives and the
/// Captain's latest note, with a CTA into the Train tab. Skill data is
/// sample data; the Captain's note comes from the live Connect data.
class SkillScreen extends ConsumerWidget {
  const SkillScreen({required this.skillId, super.key});

  final String skillId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final found = skillById(skillId);
    void back() =>
        context.canPop() ? context.pop() : context.go(AppRoutes.universe);

    if (found == null) {
      return HubPage(
        bottomPadding: AppSpacing.xl,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: HubBackButton(onPressed: back),
          ),
          const SizedBox(height: AppSpacing.md),
          const HubMessageCard(
            icon: LucideIcons.target,
            title: 'Skill not found',
            message: 'This skill isn\'t on your roadmap yet.',
          ),
        ],
      );
    }

    final (:planet, :skill) = found;
    // The Captain's latest real note (live Connect data), if any.
    final captain = ref.watch(myCaptainProvider).valueOrNull;
    final captainNote = captain?.latestCoachFeedback?.body;
    final locked = skill.state == SkillNodeState.locked;
    final pct = (skill.progress * 100).round();

    return HubPage(
      glowCenter: const Alignment(-0.4, -0.56),
      bottomPadding: AppSpacing.xl4 + AppSpacing.xl,
      bottomBar: HubGradientButton(
        label: locked ? 'Locked' : 'Start skill workout',
        icon: locked ? LucideIcons.lock : LucideIcons.play,
        height: AppSizing.buttonHeight,
        onPressed: locked ? null : () => context.go(AppRoutes.train),
      ),
      children: [
        Row(
          children: [
            HubBackButton(
              onPressed: back,
              semanticLabel: 'Back to ${planet.name} planet',
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HubEyebrow('${planet.name} planet · Skill'),
                  Text(
                    skill.name,
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
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxs,
            vertical: AppSpacing.xxs + 2,
          ),
          child: Row(
            children: [
              SkillRing(
                progress: skill.progress,
                size: 132,
                strokeWidth: 7,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (skill.image != null)
                      SizedBox(
                        height: AppSpacing.xl2,
                        child: Image.asset(
                          skill.image!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      )
                    else
                      Icon(
                        locked ? LucideIcons.lock : LucideIcons.target,
                        size: AppSizing.iconLg,
                        color: AppColors.hubSkyLight,
                      ),
                    Text(
                      '$pct%',
                      style: AppTypography.numeric(AppTypography.headlineMedium)
                          .copyWith(
                        color: AppColors.hubEyebrow,
                        fontWeight: AppTypography.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md + AppSpacing.xxs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BigStat(
                      value: '${skill.objectivesDone} of '
                          '${skill.objectives.length}',
                      caption: 'objectives done',
                    ),
                    const SizedBox(height: AppSpacing.sm - 2),
                    _BigStat(
                      value: '${skill.xp}',
                      suffix: ' / ${skill.xpGoal} XP',
                      caption: skill.tier == SkillTier.legendary
                          ? 'Legendary reached'
                          : 'to ${skill.nextTier.label}',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            for (var i = 0; i < skill.tierGoals.length; i++) ...[
              if (i > 0) const SizedBox(width: AppSpacing.xs),
              Expanded(child: _TierCard(goal: skill.tierGoals[i], skill: skill)),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        if (skill.objectives.isNotEmpty) _Objectives(skill: skill),
        if (captain != null && captainNote != null) ...[
          const SizedBox(height: AppSpacing.sm),
          _CaptainNote(
            name: captain.coachName,
            imageUrl: captain.coach?.avatarUrl,
            note: captainNote,
          ),
        ],
      ],
    );
  }
}

class _BigStat extends StatelessWidget {
  const _BigStat({required this.value, required this.caption, this.suffix});

  final String value;
  final String? suffix;
  final String caption;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            text: value,
            children: [
              if (suffix != null)
                TextSpan(
                  text: suffix,
                  style: AppTypography.labelLarge
                      .copyWith(color: AppColors.hubTextMuted),
                ),
            ],
          ),
          style: AppTypography.numeric(AppTypography.headlineSmall).copyWith(
            color: AppColors.hubTextBright,
            fontWeight: AppTypography.bold,
          ),
        ),
        Text(
          caption,
          style: AppTypography.labelMedium.copyWith(color: AppColors.hubTextMuted),
        ),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.goal, required this.skill});

  final TierGoal goal;
  final PlanetSkill skill;

  @override
  Widget build(BuildContext context) {
    final earned = skill.tier.index >= goal.tier.index;
    final isGoal = !earned && skill.nextTier == goal.tier;
    final Color label;
    switch (goal.tier) {
      case SkillTier.complete:
      case SkillTier.none:
        label = AppColors.tierComplete;
      case SkillTier.master:
        label = AppColors.tierMaster;
      case SkillTier.legendary:
        label = AppColors.tierLegendary;
    }
    final highlight = earned || isGoal;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm - 2),
      decoration: BoxDecoration(
        color: highlight ? AppColors.tierCompleteFill : AppColors.tierLockedFill,
        borderRadius: BorderRadius.circular(AppRadius.medium + 2),
        border: Border.all(
          color: highlight ? AppColors.hubEyebrow : AppColors.hubCardBorder,
          width: highlight ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            goal.tier.label.toUpperCase(),
            style: AppTypography.labelSmall.copyWith(
              color: label,
              fontWeight: AppTypography.extraBold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            goal.goal,
            style: AppTypography.labelLarge.copyWith(
              color: highlight ? AppColors.hubTextBright : AppColors.hubTextBody,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            earned
                ? 'Certified'
                : isGoal
                    ? 'Current goal'
                    : 'Locked',
            style: AppTypography.labelSmall.copyWith(
              color: highlight ? AppColors.hubTextMuted : AppColors.hubTextFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _Objectives extends StatelessWidget {
  const _Objectives({required this.skill});

  final PlanetSkill skill;

  @override
  Widget build(BuildContext context) {
    // The first unfinished objective is the active one.
    final activeIndex = skill.objectives.indexWhere((o) => !o.isComplete);
    return HubCard(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md - 2,
        AppSpacing.sm,
        AppSpacing.md - 2,
        AppSpacing.xxs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HubEyebrow('Objectives'),
          const SizedBox(height: AppSpacing.xxs),
          for (var i = 0; i < skill.objectives.length; i++)
            _ObjectiveRow(
              objective: skill.objectives[i],
              active: i == activeIndex,
              last: i == skill.objectives.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ObjectiveRow extends StatelessWidget {
  const _ObjectiveRow({
    required this.objective,
    required this.active,
    required this.last,
  });

  final SkillObjective objective;
  final bool active;
  final bool last;

  static const double _height = 38;

  @override
  Widget build(BuildContext context) {
    final done = objective.isComplete;
    final IconData icon;
    final Color iconColor;
    if (done) {
      icon = LucideIcons.circleCheck;
      iconColor = AppColors.hubEyebrow;
    } else if (active) {
      icon = LucideIcons.circleDot;
      iconColor = AppColors.hubEyebrow;
    } else {
      icon = LucideIcons.circle;
      iconColor = AppColors.hubTextFaint;
    }
    return Container(
      constraints: const BoxConstraints(minHeight: _height),
      decoration: BoxDecoration(
        border: last
            ? null
            : const Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs - 2),
      child: Row(
        children: [
          Icon(icon, size: AppSizing.iconSm + 2, color: iconColor),
          const SizedBox(width: AppSpacing.sm - 2),
          Expanded(
            child: Text(
              objective.label,
              style: AppTypography.bodyMedium.copyWith(
                color: done
                    ? AppColors.hubTextMuted
                    : active
                        ? AppColors.hubTextBright
                        : AppColors.hubTextBody,
                decoration: done ? TextDecoration.lineThrough : null,
                decorationColor: AppColors.hubTextFaint,
              ),
            ),
          ),
          if (objective.target > 1 && !done)
            Text(
              '${objective.done}/${objective.target}',
              style: AppTypography.numeric(AppTypography.labelLarge).copyWith(
                color: AppColors.hubEyebrow,
                fontWeight: AppTypography.bold,
              ),
            ),
        ],
      ),
    );
  }
}

class _CaptainNote extends StatelessWidget {
  const _CaptainNote({
    required this.name,
    required this.note,
    this.imageUrl,
  });

  final String name;
  final String note;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md - 2,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.hubNote,
        borderRadius: BorderRadius.circular(AppRadius.medium + 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HubAvatar(
            name: name,
            imageUrl: imageUrl,
            size: 28,
            ringColor: null,
          ),
          const SizedBox(width: AppSpacing.sm - 2),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${name.split(' ').first}: ',
                    style: AppTypography.labelLarge.copyWith(
                      color: AppColors.hubTextBright,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                  TextSpan(text: note),
                ],
              ),
              style:
                  AppTypography.labelLarge.copyWith(color: AppColors.hubTextBody),
            ),
          ),
        ],
      ),
    );
  }
}
