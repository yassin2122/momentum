import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_sizing.dart';
import '../theme/app_spacing.dart';
import 'floating_nav_bar.dart';

/// Grit bottom bar: a frosted-glass pill with icon-only tabs. The
/// selected tab sits in a filled blue circle; the centre slot is the
/// START button in the brand orange-to-blue gradient.
///
/// Slot order is fixed — Dashboard, Coach, START, Universe, Profile — and
/// matches the shell branches in `app_router.dart`, so a slot index is a
/// branch index. Labels are kept for screen readers.
///
/// Motion follows the "used dozens of times a day" rule: the selected
/// circle fades in (no slide or bounce), presses give a quick 0.92 scale,
/// and everything is instant when the platform asks for reduced motion.
class GritNavBar extends StatelessWidget {
  const GritNavBar({
    required this.currentIndex,
    required this.onTap,
    super.key,
  });

  /// Index of the START slot (the Train branch).
  static const int startIndex = 2;

  static const List<NavBarItem> items = [
    NavBarItem(icon: LucideIcons.house, label: 'Dashboard'),
    NavBarItem(icon: LucideIcons.userRoundCheck, label: 'Coach'),
    NavBarItem(icon: LucideIcons.play, label: 'Start workout'),
    NavBarItem(icon: LucideIcons.orbit, label: 'Universe'),
    NavBarItem(icon: LucideIcons.circleUserRound, label: 'Profile'),
  ];

  /// Height of the pill.
  static const double barHeight = 64;

  /// Selected circle and START target diameter.
  static const double circleSize = 48;

  /// Inset between the pill's edge and the circles.
  static const double inset = (barHeight - circleSize) / 2;

  /// Pill width cap so tabs don't drift apart on wide phones.
  static const double maxWidth = 360;

  /// Backdrop blur strength. Kept moderate: heavy blur is expensive.
  static const double blurSigma = 18;

  /// Selected-circle fade.
  static const Duration fade = Duration(milliseconds: 180);

  /// Press feedback in / release out.
  static const Duration pressIn = Duration(milliseconds: 100);
  static const Duration pressOut = Duration(milliseconds: 160);

  /// Strong ease-out (cubic-bezier(0.23, 1, 0.32, 1)).
  static const Curve easeOut = Cubic(0.23, 1, 0.32, 1);

  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: SizedBox(
              height: barHeight,
              child: DecoratedBox(
                // Shadow sits outside the clip so it isn't cut off.
                decoration: BoxDecoration(
                  borderRadius: radius,
                  boxShadow: AppShadows.floating,
                ),
                child: ClipRRect(
                  borderRadius: radius,
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(color: AppColors.navGlassRim),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppColors.navGlassTop,
                            AppColors.navGlassBottom,
                          ],
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          const _TopHighlight(),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: inset),
                            child: Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                for (var i = 0; i < items.length; i++)
                                  i == startIndex
                                      ? _StartSlot(
                                          label: items[i].label,
                                          selected: currentIndex == startIndex,
                                          onTap: () => onTap(startIndex),
                                        )
                                      : _TabSlot(
                                          item: items[i],
                                          selected: currentIndex == i,
                                          onTap: () => onTap(i),
                                        ),
                              ],
                            ),
                          ),
                        ],
                      ),
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

bool _reduceMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// One-pixel light catch along the glass's top edge, fading out at the
/// ends — what makes the pane read as glass rather than a dark tint.
class _TopHighlight extends StatelessWidget {
  const _TopHighlight();

  @override
  Widget build(BuildContext context) {
    return const Positioned(
      left: AppSpacing.xl,
      right: AppSpacing.xl,
      top: 0,
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.transparent,
              AppColors.navGlassHighlight,
              AppColors.transparent,
            ],
          ),
        ),
      ),
    );
  }
}

/// Scales its child down while pressed: quick in, slightly slower out.
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _down = false;

  void _set(bool down) {
    if (_down != down) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    final reduce = _reduceMotion(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down && !reduce ? 0.92 : 1,
        duration: _down ? GritNavBar.pressIn : GritNavBar.pressOut,
        curve: GritNavBar.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _TabSlot extends StatelessWidget {
  const _TabSlot({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fade =
        _reduceMotion(context) ? Duration.zero : GritNavBar.fade;
    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: _Pressable(
        onTap: onTap,
        child: SizedBox.square(
          dimension: GritNavBar.circleSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedOpacity(
                opacity: selected ? 1 : 0,
                duration: fade,
                curve: GritNavBar.easeOut,
                child: const _SelectedCircle(),
              ),
              TweenAnimationBuilder<Color?>(
                tween: ColorTween(
                  end: selected ? AppColors.white : AppColors.navIcon,
                ),
                duration: fade,
                curve: GritNavBar.easeOut,
                builder: (context, c, _) =>
                    Icon(item.icon, size: AppSizing.iconSm + 2, color: c),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Filled blue circle behind the selected tab: light top-left to deep
/// bottom-right, a soft bloom and a thin light rim.
class _SelectedCircle extends StatelessWidget {
  const _SelectedCircle();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.navSelectedTop, AppColors.navSelectedBottom],
        ),
        border: Border.fromBorderSide(
          BorderSide(color: AppColors.navGlassHighlight),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navSelectedGlow,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox.square(dimension: GritNavBar.circleSize),
    );
  }
}

/// START: a circle in the brand orange-to-blue CTA gradient with a
/// rounded white play mark, sitting inside the pill like the other tabs.
class _StartSlot extends StatelessWidget {
  const _StartSlot({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: _Pressable(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.ctaGradientStart,
                AppColors.ctaGradientMid,
                AppColors.ctaGradientEnd,
              ],
            ),
            border: Border.all(color: AppColors.navGlassHighlight),
            boxShadow: AppShadows.ctaGlow,
          ),
          child: const SizedBox.square(
            dimension: GritNavBar.circleSize,
            child: CustomPaint(painter: _PlayPainter()),
          ),
        ),
      ),
    );
  }
}

/// Filled white play triangle with rounded corners, nudged right so it
/// looks optically centred.
class _PlayPainter extends CustomPainter {
  const _PlayPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final cx = size.width / 2 + s * 0.035;
    final cy = size.height / 2;
    final h = s * 0.19; // half height
    final w = s * 0.3; // width
    final path = Path()
      ..moveTo(cx - w * 0.4, cy - h)
      ..lineTo(cx + w * 0.6, cy)
      ..lineTo(cx - w * 0.4, cy + h)
      ..close();
    final paint = Paint()
      ..color = AppColors.white
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = s * 0.06;
    canvas
      ..drawPath(path, paint..style = PaintingStyle.fill)
      ..drawPath(path, paint..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(_PlayPainter oldDelegate) => false;
}
