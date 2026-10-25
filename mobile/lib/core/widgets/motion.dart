import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

/// Shared motion primitives. Every one is brief, never bounces, and goes
/// still when the platform asks for reduced motion.

/// True when the user has asked the platform to reduce motion.
bool reduceMotionOf(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Strong ease-out (cubic-bezier(0.23, 1, 0.32, 1)), the app's press curve.
const Curve kPressCurve = Cubic(0.23, 1, 0.32, 1);

/// Scales its child down a touch while an [InkWell] inside is pressed.
///
/// [builder] receives the callback to hand to `InkWell.onHighlightChanged`,
/// so the press state follows the ink exactly — including cancelling when
/// a press turns into a scroll.
class PressScale extends StatefulWidget {
  const PressScale({required this.builder, this.scale = 0.98, super.key});

  final Widget Function(BuildContext context, ValueChanged<bool> onHighlight)
      builder;

  /// Scale while pressed.
  final double scale;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool down) {
    if (down != _down && mounted) setState(() => _down = down);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _down && !reduceMotionOf(context) ? widget.scale : 1,
      duration: _down ? AppConstants.animInstant : AppConstants.animFast,
      curve: kPressCurve,
      child: widget.builder(context, _set),
    );
  }
}

/// Fades and lifts its child in once, the first time it's built.
///
/// [index] staggers siblings (capped, so long lists don't wait). Pass a key
/// that changes when the content is replaced (e.g. skeleton → data) to play
/// the entrance again for the new content.
class Entrance extends StatefulWidget {
  const Entrance({required this.child, this.index = 0, super.key});

  final Widget child;
  final int index;

  /// Delay between siblings and the most siblings that wait.
  static const Duration stagger = Duration(milliseconds: 40);
  static const int maxStaggered = 8;

  /// How far (logical px) the child rises while fading in.
  static const double lift = 12;

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: AppConstants.animMedium + const Duration(milliseconds: 60),
  );
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: Curves.easeOutCubic);
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (reduceMotionOf(context)) {
      _c.value = 1;
      return;
    }
    final steps = widget.index.clamp(0, Entrance.maxStaggered);
    Future.delayed(Entrance.stagger * steps, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        final t = _t.value;
        if (t >= 1) return child!;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * Entrance.lift),
            child: child,
          ),
        );
      },
    );
  }
}

/// A number that counts to its new [value] whenever it changes (and from
/// zero the first time). [builder] renders the in-between value, so callers
/// keep their own formatting and styling.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    required this.value,
    required this.builder,
    this.duration = AppConstants.animSlow,
    super.key,
  });

  final double value;
  final Widget Function(BuildContext context, double value) builder;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    if (reduceMotionOf(context)) return builder(context, value);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => builder(context, v),
    );
  }
}
