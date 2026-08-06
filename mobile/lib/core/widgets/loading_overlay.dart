import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Wraps [child] and shows a blocking spinner overlay when [isLoading] is
/// true. Used for full-screen async operations (e.g. submitting a form)
/// where partial interaction would be unsafe.
class LoadingOverlay extends StatelessWidget {
  const LoadingOverlay({
    required this.isLoading,
    required this.child,
    super.key,
  });

  final bool isLoading;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Positioned.fill(
            child: AnimatedOpacity(
              opacity: isLoading ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: const ColoredBox(
                color: AppColors.overlayScrim,
                child: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
