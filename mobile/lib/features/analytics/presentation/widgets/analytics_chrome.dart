import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/motion.dart';

/// Shared chrome for the Analytics screens: graphite canvas, brushed-silver
/// type and edges. Each screen passes its own [accent] for the canvas
/// glow, so the four features read as siblings, not copies.
class AnalyticsScaffold extends StatelessWidget {
  const AnalyticsScaffold({
    required this.eyebrow,
    required this.title,
    required this.accent,
    required this.children,
    this.subtitle,
    this.trailing,
    this.onRefresh,
    this.glowCenter = const Alignment(0.8, -1),
    this.bottomBar,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Color accent;
  final Widget? trailing;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Alignment glowCenter;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        bottomBar == null ? AppSpacing.xl2 : AppSpacing.xl4 + AppSpacing.lg,
      ),
      children: [
        Entrance(
          child: AnalyticsHeader(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            accent: accent,
            trailing: trailing,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Each section rises in once, staggered. The key includes the
        // child's type, so a skeleton swapped for real content plays again.
        for (var i = 0; i < children.length; i++)
          Entrance(
            key: ValueKey(
                'section-$i-${children[i].runtimeType}-${children[i].key}'),
            index: i + 1,
            child: children[i],
          ),
      ],
    );
    return Scaffold(
      backgroundColor: AppColors.analyticsBgBottom,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: glowCenter,
            radius: 1.2,
            colors: [
              Color.alphaBlend(
                  accent.withValues(alpha: 0.07), AppColors.analyticsBgTop),
              AppColors.analyticsBgBottom,
            ],
            stops: const [0, 0.75],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              bottom: false,
              child: onRefresh == null
                  ? list
                  : RefreshIndicator(
                      color: accent,
                      backgroundColor: AppColors.analyticsPanelTop,
                      onRefresh: onRefresh!,
                      child: list,
                    ),
            ),
            if (bottomBar != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.analyticsBgBottom.withValues(alpha: 0),
                        AppColors.analyticsBgBottom,
                      ],
                      stops: const [0, 0.35],
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(AppSpacing.md,
                          AppSpacing.lg, AppSpacing.md, AppSpacing.xs),
                      child: bottomBar,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Back button, accent-dashed eyebrow and brushed-silver title shared by
/// every Analytics screen (including the hologram, which has its own body
/// layout).
class AnalyticsHeader extends StatelessWidget {
  const AnalyticsHeader({
    required this.eyebrow,
    required this.title,
    required this.accent,
    this.subtitle,
    this.trailing,
    super.key,
  });

  final String eyebrow;
  final String title;
  final String? subtitle;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            AnalyticsIconButton(
              icon: LucideIcons.chevronLeft,
              semanticLabel: 'Back',
              onPressed: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRoutes.dashboard),
            ),
            const Spacer(),
            if (trailing != null) trailing!,
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Container(
              width: AppSpacing.md,
              height: 2,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Flexible(
              child: Text(
                eyebrow.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    AppTypography.overline.copyWith(color: AppColors.silverDim),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        MetalText(
          title,
          style: AppTypography.displaySmall.copyWith(fontSize: 32),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.silverDim),
          ),
        ],
      ],
    );
  }
}

/// Text painted with a brushed-silver gradient.
class MetalText extends StatelessWidget {
  const MetalText(
    this.text, {
    required this.style,
    this.maxLines = 1,
    this.textAlign,
    super.key,
  });

  final String text;
  final TextStyle style;
  final int maxLines;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AppColors.silverBright,
          AppColors.silver,
          AppColors.silverBright,
        ],
        stops: [0, 0.6, 1],
      ).createShader(rect),
      child: Text(
        text,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
        textAlign: textAlign,
        style: style.copyWith(color: AppColors.silverBright),
      ),
    );
  }
}

/// Round graphite icon button with a silver rim.
class AnalyticsIconButton extends StatelessWidget {
  const AnalyticsIconButton({
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.color = AppColors.silver,
    super.key,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: PressScale(
        scale: 0.92,
        builder: (context, onHighlight) => Material(
          color: AppColors.analyticsPanelTop,
          shape: const CircleBorder(
            side: BorderSide(color: AppColors.analyticsPanelBorder),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            onHighlightChanged: onHighlight,
            child: SizedBox(
              width: AppSizing.minTouchTarget,
              height: AppSizing.minTouchTarget,
              child: Icon(icon, size: AppSizing.iconSm + 2, color: color),
            ),
          ),
        ),
      ),
    );
  }
}

/// Graphite panel with a hairline border and a brushed-metal top edge.
class AnalyticsPanel extends StatelessWidget {
  const AnalyticsPanel({
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.md),
    this.onTap,
    this.tint,
    this.radius = AppRadius.cardLarge,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  /// Optional accent washed into the lower corner.
  final Color? tint;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final decoration = BoxDecoration(
      borderRadius: r,
      border: Border.all(color: AppColors.analyticsPanelBorder),
      gradient: tint == null
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.analyticsPanelTop,
                AppColors.analyticsPanelBottom,
              ],
            )
          : RadialGradient(
              center: const Alignment(-0.9, 1.1),
              radius: 1.3,
              colors: [
                Color.alphaBlend(tint!.withValues(alpha: 0.16),
                    AppColors.analyticsPanelBottom),
                AppColors.analyticsPanelTop,
                AppColors.analyticsPanelBottom,
              ],
              stops: const [0, 0.55, 1],
            ),
    );
    final body = Stack(
      children: [
        Padding(padding: padding, child: child),
        // Brushed top edge: a highlight that fades out toward the corners.
        Positioned(
          top: 0,
          left: radius,
          right: radius,
          child: IgnorePointer(
            child: Container(
              height: 1,
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [
                  AppColors.transparent,
                  AppColors.silverEdge,
                  AppColors.transparent,
                ]),
              ),
            ),
          ),
        ),
      ],
    );
    Widget panel(ValueChanged<bool>? onHighlight) => Material(
          color: AppColors.transparent,
          borderRadius: r,
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: decoration,
            child: onTap == null
                ? body
                : InkWell(
                    borderRadius: r,
                    onTap: onTap,
                    onHighlightChanged: onHighlight,
                    child: body,
                  ),
          ),
        );
    if (onTap == null) return panel(null);
    return PressScale(builder: (context, onHighlight) => panel(onHighlight));
  }
}

/// Small uppercase section label.
class AnalyticsLabel extends StatelessWidget {
  const AnalyticsLabel(this.text, {this.trailing, super.key});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style:
                  AppTypography.overline.copyWith(color: AppColors.silverDim),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// A segmented control with a sliding silver thumb.
class AnalyticsSegmented<T> extends StatelessWidget {
  const AnalyticsSegmented({
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.accent = AppColors.analyticsTeal,
    super.key,
  });

  final List<T> options;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final index = options.indexOf(selected);
    return Container(
      height: AppSizing.minTouchTarget,
      padding: const EdgeInsets.all(AppSpacing.xxs),
      decoration: BoxDecoration(
        color: AppColors.analyticsPanelBottom,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.analyticsPanelBorder),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth / options.length;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: reduceMotionOf(context)
                    ? Duration.zero
                    : AppConstants.animMedium,
                curve: Curves.easeOutCubic,
                left: w * (index < 0 ? 0 : index),
                top: 0,
                bottom: 0,
                width: w,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [AppColors.silverDeep, AppColors.analyticsTrack],
                    ),
                    border: Border.all(color: AppColors.silverEdge),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final o in options)
                    Expanded(
                      child: Semantics(
                        button: true,
                        selected: o == selected,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          onTap: () {
                            if (o == selected) return;
                            HapticFeedback.selectionClick();
                            onChanged(o);
                          },
                          child: Center(
                            child: Text(
                              labelOf(o),
                              style: AppTypography.labelLarge.copyWith(
                                color: o == selected
                                    ? AppColors.silverBright
                                    : AppColors.silverDim,
                                fontWeight: AppTypography.semiBold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Inline error with retry, styled for the graphite screens.
class AnalyticsErrorPanel extends StatelessWidget {
  const AnalyticsErrorPanel({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AnalyticsPanel(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.cloudOff,
              size: AppSizing.iconMd, color: AppColors.silverDim),
          const SizedBox(height: AppSpacing.sm),
          Text(
            "Couldn't load this",
            style: AppTypography.titleMedium
                .copyWith(color: AppColors.silverBright),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            message,
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.silverDim),
          ),
          const SizedBox(height: AppSpacing.md),
          AnalyticsButton(
              label: 'Try again', onPressed: onRetry, outlined: true),
        ],
      ),
    );
  }
}

/// Empty state for a feature that has no data yet.
class AnalyticsEmptyPanel extends StatelessWidget {
  const AnalyticsEmptyPanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.accent,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color accent;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AnalyticsPanel(
      tint: accent,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSpacing.xl2,
            height: AppSpacing.xl2,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.12),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Icon(icon, size: AppSizing.iconMd, color: accent),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: AppTypography.titleLarge
                .copyWith(color: AppColors.silverBright),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            message,
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.silverDim),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            AnalyticsButton(
                label: actionLabel!, onPressed: onAction, accent: accent),
          ],
        ],
      ),
    );
  }
}

/// Pill button: filled with [accent], or a silver outline.
class AnalyticsButton extends StatelessWidget {
  const AnalyticsButton({
    required this.label,
    required this.onPressed,
    this.accent = AppColors.analyticsTeal,
    this.outlined = false,
    this.icon,
    this.isLoading = false,
    this.expand = false,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final bool outlined;
  final IconData? icon;
  final bool isLoading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(AppRadius.pill);
    final enabled = onPressed != null && !isLoading;
    final fg = outlined ? AppColors.silverBright : AppColors.analyticsBgBottom;
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading)
          SizedBox(
            width: AppSizing.iconSm,
            height: AppSizing.iconSm,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (icon != null)
          Icon(icon, size: AppSizing.iconSm, color: fg),
        if (isLoading || icon != null) const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.button.copyWith(color: fg, fontSize: 15),
        ),
      ],
    );
    return Opacity(
      opacity: enabled || isLoading ? 1 : 0.45,
      child: PressScale(
        scale: 0.96,
        builder: (context, onHighlight) => Material(
          color: outlined ? AppColors.transparent : accent,
          shape: RoundedRectangleBorder(
            borderRadius: r,
            side: outlined
                ? const BorderSide(color: AppColors.silverDeep)
                : BorderSide.none,
          ),
          child: InkWell(
            borderRadius: r,
            onTap: enabled ? onPressed : null,
            onHighlightChanged: onHighlight,
            child: ConstrainedBox(
              // HIG minimum hit target.
              constraints:
                  const BoxConstraints(minHeight: AppSizing.minTouchTarget),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
                child: content,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Muted placeholder block while data loads, with a slow brushed-silver
/// sheen sweeping across it (held still under reduced motion).
class AnalyticsSkeleton extends StatefulWidget {
  const AnalyticsSkeleton({required this.height, this.width, super.key});

  final double height;
  final double? width;

  @override
  State<AnalyticsSkeleton> createState() => _AnalyticsSkeletonState();
}

class _AnalyticsSkeletonState extends State<AnalyticsSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: AppConstants.animShimmer);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotionOf(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = AppColors.analyticsTrack.withValues(alpha: 0.6);
    return Semantics(
      label: 'Loading',
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final x = -2 + _c.value * 4; // off-left to off-right
            return Container(
              height: widget.height,
              width: widget.width,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.medium),
                color: base,
                gradient: _c.isAnimating
                    ? LinearGradient(
                        begin: Alignment(x - 1, -0.3),
                        end: Alignment(x + 1, 0.3),
                        colors: [base, AppColors.analyticsPanelTop, base],
                      )
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Cross-fades between a block's loading, error, empty and data states
/// (give each state's child its own key). Top-left aligned, so it sits in
/// a left-aligned column without jumping.
class AnalyticsSwap extends StatelessWidget {
  const AnalyticsSwap({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration:
          reduceMotionOf(context) ? Duration.zero : AppConstants.animMedium,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: AlignmentDirectional.topStart,
        children: [...previous, if (current != null) current],
      ),
      child: child,
    );
  }
}

/// Bottom-sheet frame shared by the analytics forms.
Future<T?> showAnalyticsSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.analyticsPanelTop,
    barrierColor: AppColors.analyticsScrim,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: builder(context),
    ),
  );
}

/// Grab handle + title row used at the top of analytics sheets.
class AnalyticsSheetHeader extends StatelessWidget {
  const AnalyticsSheetHeader({required this.title, this.subtitle, super.key});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: AppSpacing.xl + AppSpacing.xxs,
            height: AppSpacing.xxs,
            decoration: BoxDecoration(
              color: AppColors.silverDeep,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          title,
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.silverBright,
            fontWeight: AppTypography.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.silverDim),
          ),
        ],
      ],
    );
  }
}

/// "Today", "Yesterday", "3 days ago".
String relativeDay(DateTime date, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final days = DateTime.utc(n.year, n.month, n.day)
      .difference(DateTime.utc(date.year, date.month, date.day))
      .inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return '$days days ago';
  final weeks = days ~/ 7;
  if (days < 60) return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
  return '${days ~/ 30} months ago';
}
