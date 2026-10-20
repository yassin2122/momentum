import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_sizing.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';

/// Shared chrome for the hub screens (Dashboard, Coach, Captain, Profile,
/// Skill): the deep near-black canvas, slate cards, eyebrows, pills and
/// buttons from the Grit canvas designs. Presentation only.

/// Bottom padding a tab screen needs so its last card clears the
/// floating nav bar and the raised START orb.
const double kNavClearance = AppSizing.navBarHeight + AppSpacing.xl2;

/// Full-screen deep-blue canvas with a soft lift near the top.
class HubBackground extends StatelessWidget {
  const HubBackground({
    required this.child,
    this.glowCenter = const Alignment(0.4, -0.85),
    super.key,
  });

  final Widget child;

  /// Where the blue lift sits; the canvas varies it per screen.
  final Alignment glowCenter;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.hubBackgroundBottom,
        gradient: RadialGradient(
          center: glowCenter,
          radius: 0.95,
          colors: const [
            AppColors.hubBackgroundTop,
            AppColors.hubBackgroundBottom,
          ],
          stops: const [0, 0.7],
        ),
      ),
      child: child,
    );
  }
}

/// A scrolling hub page: background, safe area and nav-bar clearance.
class HubPage extends StatelessWidget {
  const HubPage({
    required this.children,
    this.glowCenter = const Alignment(0.4, -0.85),
    this.bottomPadding = kNavClearance,
    this.bottomBar,
    super.key,
  });

  final List<Widget> children;
  final Alignment glowCenter;
  final double bottomPadding;

  /// Optional pinned bar at the bottom (e.g. a primary CTA on a
  /// full-screen page).
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.hubBackgroundBottom,
      body: HubBackground(
        glowCenter: glowCenter,
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  AppSpacing.xs,
                  AppSpacing.sm,
                  bottomPadding,
                ),
                children: children,
              ),
            ),
            if (bottomBar != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: HubBottomBar(child: bottomBar!),
              ),
          ],
        ),
      ),
    );
  }
}

/// Fades content out under a pinned bottom CTA.
class HubBottomBar extends StatelessWidget {
  const HubBottomBar({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.hubBackgroundBottom.withValues(alpha: 0),
            AppColors.hubBackgroundBottom,
          ],
          stops: const [0, 0.3],
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Dark slate card with a hairline border.
class HubCard extends StatelessWidget {
  const HubCard({
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.md,
      AppSpacing.sm,
      AppSpacing.md,
      AppSpacing.sm,
    ),
    this.onTap,
    this.hero = false,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Hero cards get the blue glow from the lower-left corner.
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      hero ? AppRadius.hubHero : AppRadius.hubCard,
    );
    final decoration = BoxDecoration(
      borderRadius: radius,
      border: Border.all(
        color: hero ? AppColors.hubNavBorder : AppColors.hubCardBorder,
      ),
      gradient: hero
          ? const RadialGradient(
              center: Alignment(-0.7, 1),
              radius: 1.1,
              colors: [
                AppColors.hubHeroGlow,
                AppColors.hubHeroMid,
                AppColors.hubHeroEdge,
              ],
              stops: [0, 0.55, 1],
            )
          : const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.hubCardTop, AppColors.hubCardBottom],
            ),
    );
    final content = Ink(
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );
    return Material(
      color: AppColors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : InkWell(borderRadius: radius, onTap: onTap, child: content),
    );
  }
}

/// Small blue uppercase section label ("STREAK", "LATEST FEEDBACK").
class HubEyebrow extends StatelessWidget {
  const HubEyebrow(this.text, {this.color = AppColors.hubEyebrow, super.key});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: AppTypography.labelMedium.copyWith(
        color: color,
        fontWeight: AppTypography.semiBold,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// Eyebrow on the left, optional link on the right.
class HubCardHeader extends StatelessWidget {
  const HubCardHeader({
    required this.title,
    this.trailing,
    this.onTrailingTap,
    super.key,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: HubEyebrow(title)),
        if (trailing != null)
          HubLink(label: trailing!, onTap: onTrailingTap),
      ],
    );
  }
}

/// Inline sky-blue text link.
class HubLink extends StatelessWidget {
  const HubLink({required this.label, this.onTap, super.key});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.small),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xxs,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          label,
          style: AppTypography.labelMedium.copyWith(color: AppColors.hubEyebrow),
        ),
      ),
    );
  }
}

/// Thin rounded progress bar with the hub blue gradient.
class HubProgressBar extends StatelessWidget {
  const HubProgressBar({
    required this.value,
    this.height = 6,
    this.colors = const [AppColors.hubBarStart, AppColors.hubBarEnd],
    this.track = AppColors.hubTrack,
    super.key,
  });

  /// 0–1.
  final double value;
  final double height;
  final List<Color> colors;
  final Color track;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: track)),
            FractionallySizedBox(
              widthFactor: v,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  gradient: LinearGradient(colors: colors),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Outlined uppercase button ("VIEW PROFILE", "EDIT").
class HubOutlineButton extends StatelessWidget {
  const HubOutlineButton({
    required this.label,
    required this.onPressed,
    this.height = 40,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.medium);
    return Material(
      color: AppColors.transparent,
      borderRadius: radius,
      child: InkWell(
        borderRadius: radius,
        onTap: onPressed,
        child: Container(
          height: height,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: AppColors.hubCardBorderStrong),
          ),
          child: Text(
            label.toUpperCase(),
            style: AppTypography.labelMedium.copyWith(
              color: onPressed == null
                  ? AppColors.hubTextFaint
                  : AppColors.hubTextBright,
              fontWeight: AppTypography.bold,
            ),
          ),
        ),
      ),
    );
  }
}

/// Filled steel-blue uppercase button ("SEND CHECK-IN", "CHOOSE AS
/// CAPTAIN"). Uses the auth CTA gradient so it matches login/register.
class HubGradientButton extends StatelessWidget {
  const HubGradientButton({
    required this.label,
    required this.onPressed,
    this.height = 40,
    this.isLoading = false,
    this.icon,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final double height;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.medium);
    final enabled = onPressed != null && !isLoading;
    return Opacity(
      opacity: enabled || isLoading ? 1 : 0.45,
      child: Material(
        color: AppColors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled ? onPressed : null,
          child: Ink(
            height: height,
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: const LinearGradient(
                colors: [
                  AppColors.authCtaStart,
                  AppColors.authCtaMid,
                  AppColors.authCtaEnd,
                ],
                stops: [0, 0.45, 1],
              ),
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: AppSizing.iconSm,
                      height: AppSizing.iconSm,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.hubTextBright,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(
                            icon,
                            size: AppSizing.iconSm,
                            color: AppColors.hubTextBright,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                        ],
                        Text(
                          label.toUpperCase(),
                          style: AppTypography.labelMedium.copyWith(
                            color: AppColors.hubTextBright,
                            fontWeight: AppTypography.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded status/tag pill.
class HubPill extends StatelessWidget {
  const HubPill({
    required this.label,
    this.fill = AppColors.hubHeroGlow,
    this.textColor = AppColors.hubChipText,
    this.icon,
    super.key,
  });

  final String label;
  final Color fill;
  final Color textColor;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: AppSizing.iconSm - 4, color: textColor),
            const SizedBox(width: AppSpacing.xxs),
          ],
          Text(
            label,
            style: AppTypography.labelMedium.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

/// Circular avatar: network image when available, initials otherwise.
class HubAvatar extends StatelessWidget {
  const HubAvatar({
    required this.name,
    this.imageUrl,
    this.size = 40,
    this.ringColor = AppColors.hubAvatarRing,
    this.ringWidth = 2,
    this.glow = false,
    super.key,
  });

  final String name;
  final String? imageUrl;
  final double size;
  final Color? ringColor;
  final double ringWidth;
  final bool glow;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first.characters.first;
    final second = parts.length > 1 ? parts[1].characters.first : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final fallback = ColoredBox(
      color: AppColors.hubHeroGlow,
      child: Center(
        child: Text(
          _initials,
          style: AppTypography.titleSmall.copyWith(
            color: AppColors.hubChipText,
            fontWeight: AppTypography.bold,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(ringColor == null ? 0 : ringWidth + 1),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.hubBackgroundBottom,
        border: ringColor == null
            ? null
            : Border.all(color: ringColor!, width: ringWidth),
        boxShadow: glow ? AppShadows.hubAvatarGlow : null,
      ),
      child: ClipOval(
        child: url == null || url.isEmpty
            ? fallback
            : CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (_, __) => fallback,
                errorWidget: (_, __, ___) => fallback,
              ),
      ),
    );
  }
}

/// Round translucent back button used on full-screen hub/game pages.
class HubBackButton extends StatelessWidget {
  const HubBackButton({
    required this.onPressed,
    this.fill = AppColors.authBackButton,
    this.semanticLabel = 'Back',
    super.key,
  });

  final VoidCallback onPressed;
  final Color fill;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: fill,
        shape: const CircleBorder(
          side: BorderSide(color: AppColors.hubCardBorderStrong),
        ),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: const SizedBox(
            width: AppSizing.minTouchTarget - 2,
            height: AppSizing.minTouchTarget - 2,
            child: Icon(
              LucideIcons.chevronLeft,
              size: AppSizing.iconMd - 2,
              color: AppColors.hubTextBright,
            ),
          ),
        ),
      ),
    );
  }
}

/// Square-ish icon button from the hub headers (bell, settings).
class HubSquareIconButton extends StatelessWidget {
  const HubSquareIconButton({
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.showDot = false,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.medium);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: AppColors.hubIconButton,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: const BorderSide(color: AppColors.hubCardBorder),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onPressed,
          child: SizedBox(
            width: AppSizing.minTouchTarget - AppSpacing.xs,
            height: AppSizing.minTouchTarget - AppSpacing.xs,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(icon, size: AppSizing.iconSm + 2, color: AppColors.hubTextBody),
                if (showDot)
                  const Positioned(
                    right: AppSpacing.xs - 2,
                    top: AppSpacing.xs - 2,
                    child: SizedBox(
                      width: 5,
                      height: 5,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.startOrbMid,
                          shape: BoxShape.circle,
                        ),
                      ),
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

/// Number-over-label tile used in stat rows (Profile totals, Captain
/// "at a glance").
class HubStatTile extends StatelessWidget {
  const HubStatTile({
    required this.value,
    required this.label,
    this.valueColor = AppColors.hubTextNumber,
    super.key,
  });

  final String value;
  final String label;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    return HubCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.numeric(AppTypography.headlineSmall).copyWith(
              color: valueColor,
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.labelSmall.copyWith(color: AppColors.hubTextMuted),
          ),
        ],
      ),
    );
  }
}

/// Inline loading spinner sized for a card.
class HubLoading extends StatelessWidget {
  const HubLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(
        child: SizedBox(
          width: AppSizing.iconMd,
          height: AppSizing.iconMd,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.hubEyebrow,
          ),
        ),
      ),
    );
  }
}

/// Inline message card with an optional retry action.
class HubMessageCard extends StatelessWidget {
  const HubMessageCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return HubCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizing.iconMd, color: AppColors.hubEyebrow),
          const SizedBox(height: AppSpacing.sm),
          Text(
            title,
            style: AppTypography.titleMedium.copyWith(
              color: AppColors.hubTextBright,
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            message,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            HubOutlineButton(label: actionLabel!, onPressed: onAction),
          ],
        ],
      ),
    );
  }
}
