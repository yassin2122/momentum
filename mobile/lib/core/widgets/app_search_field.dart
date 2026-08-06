import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_radius.dart';
import '../theme/app_typography.dart';

/// Standard search input. Distinct from [AppTextField] — no label, pill
/// radius, always visible under a screen's header rather than a separate
/// search route. Fires on every keystroke (search-as-you-type).
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    required this.hintText,
    this.onChanged,
    this.onClear,
    this.controller,
    super.key,
  });

  final String hintText;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final TextEditingController? controller;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _hasText = _controller.text.isNotEmpty;
    _controller.addListener(_handleTextChange);
  }

  void _handleTextChange() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizing.inputHeight,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.search,
            size: AppSizing.iconSm,
            color: AppColors.textTertiary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: TextField(
              controller: _controller,
              onChanged: widget.onChanged,
              style: AppTypography.bodyLarge,
              decoration: InputDecoration(
                hintText: widget.hintText,
                hintStyle: AppTypography.bodyMedium,
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: AppConstants.animInstant,
            child: _hasText
                ? GestureDetector(
                    key: const ValueKey('clear'),
                    onTap: () {
                      _controller.clear();
                      widget.onClear?.call();
                      widget.onChanged?.call('');
                    },
                    child: const Icon(
                      Icons.close,
                      size: AppSizing.iconSm,
                      color: AppColors.textTertiary,
                    ),
                  )
                : const SizedBox.shrink(key: ValueKey('empty')),
          ),
        ],
      ),
    );
  }
}
