import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';

/// Shimmering placeholder block. Composed into shapes matching real
/// content (e.g. stack a few of these to mimic a card's layout) rather
/// than shown as a single generic box — the skeleton should telegraph
/// the real layout for a "fast" perceived-performance feel.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({
    this.width,
    this.height = 16,
    this.borderRadius = AppRadius.sm,
    super.key,
  });

  final double? width;
  final double height;
  final double borderRadius;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppConstants.animShimmer,
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment(-1 - _controller.value * 2, 0),
              end: Alignment(1 - _controller.value * 2, 0),
              colors: const [
                AppColors.glassLight,
                AppColors.glassMedium,
                AppColors.glassLight,
              ],
              stops: const [0.35, 0.5, 0.65],
            ),
          ),
        );
      },
    );
  }
}
