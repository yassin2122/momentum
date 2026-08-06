import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_shadows.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_typography.dart';

/// Full-width warm-orange → violet → blue gradient pill CTA button.
///
/// Visual behaviour per spec §11 / §15:
/// - **Default**: gradient fill + soft outer CTA glow (two BoxShadow layers).
/// - **Pressed**: scale 1.0 → 0.97 (100 ms down / 150 ms spring up).
/// - **Loading**: spinner replaces label; width/height locked to avoid
///   layout shift.
/// - **Disabled**: gradient replaced by a flat desaturated surface.
///
/// The gradient always runs warm (left) → cool (right) and must never be
/// flipped, per spec §22.
class GradientPillButton extends StatefulWidget {
  const GradientPillButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isEnabled = true,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isEnabled;

  @override
  State<GradientPillButton> createState() => _GradientPillButtonState();
}

class _GradientPillButtonState extends State<GradientPillButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  bool get _canTap =>
      widget.isEnabled && !widget.isLoading && widget.onPressed != null;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 150),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
    _scaleAnim = _scaleCtrl;
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!_canTap) return;
    _scaleCtrl.reverse(); // animates 1.0 → 0.97
  }

  void _onTapUp(TapUpDetails _) {
    _scaleCtrl.forward(); // springs back 0.97 → 1.0
    if (_canTap) widget.onPressed?.call();
  }

  void _onTapCancel() => _scaleCtrl.forward();

  static const _gradient = LinearGradient(
    colors: [
      AppColors.ctaGradientStart,
      AppColors.ctaGradientMid,
      AppColors.ctaGradientEnd,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  static const _disabledGradient = LinearGradient(
    colors: [Color(0xFF4A4A5A), Color(0xFF3A3A4A)],
  );

  @override
  Widget build(BuildContext context) {
    final bool active = _canTap;

    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Container(
          height: AppSizing.buttonHeight, // 56 px
          decoration: BoxDecoration(
            gradient: active ? _gradient : _disabledGradient,
            borderRadius: BorderRadius.circular(999), // pill
            boxShadow: active ? AppShadows.ctaGlow : null,
          ),
          alignment: Alignment.center,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: widget.isLoading
                ? const SizedBox(
                    key: ValueKey('loading'),
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.white,
                      ),
                    ),
                  )
                : Text(
                    widget.label,
                    key: const ValueKey('label'),
                    style: AppTypography.button.copyWith(
                      color: AppColors.white,
                      fontSize: 17,
                      fontWeight: AppTypography.semiBold,
                      letterSpacing: 0,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
