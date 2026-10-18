import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../sample/achievements_sample_data.dart';
import '../widgets/achievement_badge.dart';
import '../widgets/achievement_detail_sheet.dart';

/// Achievements overview: unlocked count with a rarity breakdown,
/// category filters, "closest / rarity" sort and the medallion grid.
/// Sample data (see `achievements_sample_data.dart`).
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  AchievementCategory? _category;
  bool _byRarity = false;

  /// 0 earned, 1 in progress, 2 locked.
  static int _group(Achievement a) => a.isEarned
      ? 0
      : a.state == AchievementState.inProgress
          ? 1
          : 2;

  List<Achievement> get _items {
    final list = sampleAchievements
        .where((a) => _category == null || a.category == _category)
        .toList();
    if (_byRarity) {
      list.sort((a, b) {
        final r = b.rarity.index - a.rarity.index;
        if (r != 0) return r;
        final g = _group(a) - _group(b);
        if (g != 0) return g;
        return a.id - b.id;
      });
    } else {
      list.sort((a, b) {
        final g = _group(a) - _group(b);
        if (g != 0) return g;
        if (_group(a) == 0) {
          final n = (b.state == AchievementState.isNew ? 1 : 0) -
              (a.state == AchievementState.isNew ? 1 : 0);
          if (n != 0) return n;
          final r = b.rarity.index - a.rarity.index;
          if (r != 0) return r;
        } else if (_group(a) == 1) {
          final p = b.progress.compareTo(a.progress);
          if (p != 0) return p;
        }
        return a.id - b.id;
      });
    }
    return list;
  }

  void _open(Achievement a) {
    if (a.state == AchievementState.isNew) {
      context.push(AppRoutes.achievementUnlockPath('${a.id}'));
    } else {
      showAchievementDetail(context, a);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = sampleAchievements.where((a) => a.isEarned).toList();
    final items = _items;

    return Scaffold(
      backgroundColor: AppColors.achBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -1),
            radius: 0.9,
            colors: [AppColors.achBackgroundTop, AppColors.achBackground],
            stops: [0, 0.7],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm + 2,
                  AppSpacing.xxs,
                  AppSpacing.sm + 2,
                  0,
                ),
                sliver: SliverList.list(
                  children: [
                    Row(
                      children: [
                        HubBackButton(
                          fill: AppColors.achSurface,
                          semanticLabel: 'Back to Progress',
                          onPressed: () => context.canPop()
                              ? context.pop()
                              : context.go(AppRoutes.universe),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Achievements',
                            style: AppTypography.headlineMedium.copyWith(
                              color: AppColors.achText,
                              fontWeight: AppTypography.bold,
                            ),
                          ),
                        ),
                        _SortButton(
                          byRarity: _byRarity,
                          onTap: () => setState(() => _byRarity = !_byRarity),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _Summary(unlocked: unlocked),
                    const SizedBox(height: AppSpacing.md - 2),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: AppSizing.minTouchTarget - AppSpacing.xs - 2,
                  child: ListView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm + 2,
                    ),
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CategoryChip(
                        label: 'All',
                        selected: _category == null,
                        onTap: () => setState(() => _category = null),
                      ),
                      for (final c in AchievementCategory.values)
                        _CategoryChip(
                          label: c.label,
                          selected: _category == c,
                          onTap: () => setState(() => _category = c),
                        ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm + 2,
                  AppSpacing.md,
                  AppSpacing.sm + 2,
                  kNavClearance,
                ),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: AppSpacing.md + 2,
                    crossAxisSpacing: AppSpacing.sm - 2,
                    childAspectRatio: 0.62,
                  ),
                  itemCount: items.length,
                  itemBuilder: (context, i) => _GridItem(
                    key: ValueKey(items[i].id),
                    achievement: items[i],
                    onTap: () => _open(items[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  const _SortButton({required this.byRarity, required this.onTap});

  final bool byRarity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Semantics(
      button: true,
      label: 'Sort by ${byRarity ? 'rarity' : 'closest to unlocking'}',
      excludeSemantics: true,
      child: Material(
        color: AppColors.achSurface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.hudBorder),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.arrowUpDown,
                  size: AppSizing.iconSm - 2,
                  color: AppColors.phaseTextBody,
                ),
                const SizedBox(width: AppSpacing.xxs + 2),
                Text(
                  byRarity ? 'Rarity' : 'Closest',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.phaseTextBody,
                    fontWeight: AppTypography.semiBold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.unlocked});

  final List<Achievement> unlocked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md - 2,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.hubHero),
        border: Border.all(color: AppColors.divider),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.achSurface, AppColors.achSurfaceLow],
        ),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  text: '${unlocked.length}',
                  children: [
                    TextSpan(
                      text: ' / ${sampleAchievements.length}',
                      style: AppTypography.titleLarge.copyWith(
                        color: AppColors.achTextMuted,
                        fontWeight: AppTypography.medium,
                      ),
                    ),
                  ],
                ),
                style: AppTypography.numeric(AppTypography.displayMedium)
                    .copyWith(color: AppColors.achText),
              ),
              Text(
                'unlocked',
                style: AppTypography.labelLarge
                    .copyWith(color: AppColors.achTextMuted),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md + 2),
          Expanded(
            child: Wrap(
              runSpacing: AppSpacing.sm - 2,
              children: [
                for (final r in Rarity.values)
                  FractionallySizedBox(
                    widthFactor: 1 / 3,
                    child: Row(
                      children: [
                        RarityHex(color: r.palette.label, size: 10),
                        const SizedBox(width: AppSpacing.xxs + 2),
                        Text(
                          '${unlocked.where((a) => a.rarity == r).length}',
                          style: AppTypography.numeric(AppTypography.labelMedium)
                              .copyWith(
                            color: AppColors.achText,
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xxs),
                        Flexible(
                          child: Text(
                            r.label,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: AppTypography.labelSmall
                                .copyWith(color: AppColors.achTextMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: Semantics(
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: AppConstants.animFast,
          decoration: BoxDecoration(
            color: selected ? AppColors.achText : AppColors.achSurface,
            borderRadius: radius,
            border: Border.all(
              color: selected ? AppColors.achText : AppColors.hudBorder,
            ),
          ),
          child: Material(
            color: AppColors.transparent,
            child: InkWell(
              borderRadius: radius,
              onTap: onTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md - 2),
                child: Center(
                  child: Text(
                    label,
                    style: AppTypography.labelLarge.copyWith(
                      color: selected
                          ? AppColors.achBackground
                          : AppColors.phaseTextTag,
                      fontWeight: AppTypography.semiBold,
                    ),
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

class _GridItem extends StatelessWidget {
  const _GridItem({
    required this.achievement,
    required this.onTap,
    super.key,
  });

  final Achievement achievement;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final a = achievement;
    final earned = a.isEarned;
    final String meta;
    final Color metaColor;
    if (a.state == AchievementState.inProgress) {
      meta = a.progressLabel ?? '${(a.progress * 100).round()}%';
      metaColor = AppColors.phaseTextBody;
    } else if (a.state == AchievementState.isNew) {
      meta = 'New · ${a.rarity.label}';
      metaColor = a.rarity.palette.label;
    } else if (earned) {
      meta = a.earnedOn != null
          ? '${a.rarity.label} · ${DateFormat('MMM d').format(a.earnedOn!)}'
          : a.rarity.label;
      metaColor = a.rarity.palette.label;
    } else {
      meta = a.rarity.label;
      metaColor = AppColors.achTextFaint;
    }

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: LayoutBuilder(
        builder: (context, c) => Column(
          children: [
            AchievementBadge(
              achievement: a,
              size: c.maxWidth,
              animated: earned && a.rarity.index >= Rarity.legendary.index,
            ),
            const SizedBox(height: AppSpacing.xxs + 2),
            Text(
              a.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelLarge.copyWith(
                color: earned ? AppColors.achText : AppColors.achTextMuted,
                fontWeight: AppTypography.semiBold,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs - 2),
            Text(
              meta,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.numeric(AppTypography.labelSmall)
                  .copyWith(color: metaColor),
            ),
          ],
        ),
      ),
    );
  }
}
