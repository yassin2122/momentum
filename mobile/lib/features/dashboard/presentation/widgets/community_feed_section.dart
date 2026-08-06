import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Community feed section — header row + horizontal scrolling list of
/// [CommunityPostCard] widgets.
///
/// Per user request: post thumbnails are blank/empty (UGC content that
/// users will upload). Cards show the structural chrome (avatar, name,
/// timestamp, caption, engagement row) with a dark placeholder where
/// photos will appear.
class CommunityFeedSection extends StatelessWidget {
  const CommunityFeedSection({
    required this.posts,
    this.onSeeAll,
    super.key,
  });

  final List<CommunityPost> posts;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Section header row ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md),
          child: Row(
            children: [
              Text(
                'Community Feed',
                style: AppTypography.titleLarge.copyWith(
                  fontSize: 18,
                  fontWeight: AppTypography.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: onSeeAll,
                child: Text(
                  'See all',
                  style: AppTypography.labelLarge.copyWith(
                    fontSize: 14,
                    fontWeight: AppTypography.medium,
                    color: AppColors.accentLink,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // ── Horizontal scroll of cards ─────────────────────────────────
        SizedBox(
          height: 270,
          child: posts.isEmpty
              ? _EmptyFeed()
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md),
                  itemCount: posts.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (_, i) =>
                      CommunityPostCard(post: posts[i]),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty feed state — shown when no posts exist yet
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppRadius.cardLarge),
          border: Border.all(color: AppColors.cardBorder, width: 1),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.users,
                size: 36,
                color: AppColors.textTertiary.withValues(alpha: 0.6),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'No posts yet',
                style: AppTypography.titleSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Be the first to share your workout!',
                style: AppTypography.bodySmall.copyWith(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class CommunityPost {
  const CommunityPost({
    required this.authorName,
    required this.authorInitials,
    required this.timestamp,
    required this.caption,
    required this.likeCount,
    required this.commentCount,
    this.isLiked = false,
  });

  final String authorName;
  final String authorInitials;
  final String timestamp;
  final String caption;
  final int likeCount;
  final int commentCount;
  final bool isLiked;
}

// ─────────────────────────────────────────────────────────────────────────────
// Community post card
// ─────────────────────────────────────────────────────────────────────────────

class CommunityPostCard extends StatefulWidget {
  const CommunityPostCard({required this.post, super.key});
  final CommunityPost post;

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard>
    with SingleTickerProviderStateMixin {
  late bool _liked;
  late int _likeCount;
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _liked = widget.post.isLiked;
    _likeCount = widget.post.likeCount;
    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    // Spring-bounce: 1 → 1.3 → 1
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.35)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.35, end: 1.0)
              .chain(CurveTween(curve: Curves.elasticOut)),
          weight: 60),
    ]).animate(_heartCtrl);
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    super.dispose();
  }

  void _toggleLike() {
    setState(() {
      _liked = !_liked;
      _likeCount += _liked ? 1 : -1;
    });
    _heartCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 185,
      decoration: BoxDecoration(
        color: AppColors.cardSurface.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(AppRadius.cardLarge),
        border: Border.all(color: AppColors.cardBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Author row ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            child: Row(
              children: [
                _Avatar(initials: widget.post.authorInitials),
                const SizedBox(width: AppSpacing.xxs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.post.authorName,
                        style: AppTypography.labelMedium.copyWith(
                          fontSize: 13,
                          fontWeight: AppTypography.semiBold,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        widget.post.timestamp,
                        style: AppTypography.caption.copyWith(
                          fontSize: 11,
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                // Overflow menu
                const Icon(
                  LucideIcons.moreVertical,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),

          // ── Video/photo thumbnail (blank for user uploads) ───────────
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.postThumbnail),
                child: Container(
                  color: AppColors.ringTrack,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.video,
                          size: 24,
                          color: AppColors.textTertiary
                              .withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Video',
                          style: AppTypography.caption.copyWith(
                            fontSize: 10,
                            color: AppColors.textTertiary
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Caption ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
            child: Text(
              widget.post.caption,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 13,
                fontWeight: AppTypography.medium,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // ── Engagement row ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
            child: Row(
              children: [
                // Like
                GestureDetector(
                  onTap: _toggleLike,
                  child: Row(
                    children: [
                      ScaleTransition(
                        scale: _heartScale,
                        child: Icon(
                          _liked
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          size: 15,
                          color: _liked
                              ? AppColors.socialHeart
                              : AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '$_likeCount',
                        style: AppTypography.caption.copyWith(
                          fontSize: 12,
                          color: _liked
                              ? AppColors.socialHeart
                              : AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Comment
                Row(
                  children: [
                    const Icon(
                      LucideIcons.messageCircle,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${widget.post.commentCount}',
                      style: AppTypography.caption.copyWith(
                        fontSize: 12,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                // Bookmark
                const Icon(
                  LucideIcons.bookmark,
                  size: 14,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar — initials circle, no ring border per spec §2
// ─────────────────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryMuted],
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          fontSize: 10,
          fontWeight: AppTypography.bold,
          color: AppColors.white,
        ),
      ),
    );
  }
}
