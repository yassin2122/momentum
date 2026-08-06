import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';


/// Auth-screen glass input field.
///
/// Differences from the general [AppTextField]:
/// - Glass fill: [AppColors.surface] at 65% opacity + 1 px hairline border.
/// - Optional leading icon slot.
/// - Trailing password-reveal icon with a 120 ms crossfade.
/// - Focus animation: border brightens from 8% → 30% white opacity in 150 ms.
/// - 14 px corner radius per spec §5 ("Input fields: 14–16 px").
///
/// The label above the field is drawn at `caption` size (12 px, medium weight)
/// so it reads as a field identifier, not a headline.
class LabeledTextField extends StatefulWidget {
  const LabeledTextField({
    required this.label,
    this.controller,
    this.focusNode,
    this.hintText,
    this.leadingIcon,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.validator,
    this.autofillHints,
    this.onSubmitted,
    this.enabled = true,
    super.key,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final IconData? leadingIcon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final String? Function(String?)? validator;
  final Iterable<String>? autofillHints;
  final void Function(String)? onSubmitted;
  final bool enabled;

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  late bool _obscured = widget.obscureText;
  bool _focused = false;
  late FocusNode _effectiveFocusNode;

  @override
  void initState() {
    super.initState();
    _effectiveFocusNode = widget.focusNode ?? FocusNode();
    _effectiveFocusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    setState(() => _focused = _effectiveFocusNode.hasFocus);
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    if (widget.focusNode == null) {
      _effectiveFocusNode.dispose();
    }
    super.dispose();
  }

  // Border color: hairline white at 8% unfocused → 30% focused.
  Color get _borderColor => _focused
      ? const Color(0x4DFFFFFF) // ~30% white
      : const Color(0x14FFFFFF); // ~8% white

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ──────────────────────────────────────────────────────
        Text(
          widget.label,
          style: AppTypography.labelLarge.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: AppTypography.medium,
          ),
        ),
        const SizedBox(height: 6),

        // ── Glass input ─────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            // Glass fill: surface at 65% opacity.
            color: AppColors.surface.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(14), // spec §5 field radius
            border: Border.all(color: _borderColor, width: 1),
          ),
          // No fixed height — lets the TextFormField's error message text
          // render below the input without being clipped.
          child: TextFormField(
            controller: widget.controller,
            focusNode: _effectiveFocusNode,
            obscureText: _obscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            validator: widget.validator,
            autofillHints: widget.autofillHints,
            onFieldSubmitted: widget.onSubmitted,
            enabled: widget.enabled,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.textPrimary,
              fontSize: 15,
            ),
            cursorColor: AppColors.heroGlow,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: AppTypography.bodyLarge.copyWith(
                color: AppColors.textTertiary,
                fontSize: 15,
                fontWeight: AppTypography.regular,
              ),
              // Strip the theme's InputDecorationTheme borders/fill —
              // this widget controls its own container visually.
              filled: false,
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorStyle: AppTypography.bodyMedium.copyWith(
                color: const Color(0xFFFF6B6B),
                fontSize: 12,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: widget.leadingIcon != null
                  ? Icon(
                      widget.leadingIcon,
                      color: AppColors.textTertiary,
                      size: 18,
                    )
                  : null,
              // Password reveal: 120 ms crossfade per spec §15.
              suffixIcon: widget.obscureText
                  ? AnimatedSwitcher(
                      duration: const Duration(milliseconds: 120),
                      child: IconButton(
                        key: ValueKey(_obscured),
                        icon: Icon(
                          _obscured
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textTertiary,
                          size: 18,
                        ),
                        // 44×44 minimum touch target per spec §22.
                        padding: const EdgeInsets.all(12),
                        onPressed: () =>
                            setState(() => _obscured = !_obscured),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
