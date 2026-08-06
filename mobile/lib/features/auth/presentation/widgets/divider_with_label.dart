import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// "or continue with" section divider — two [Divider] rules flanking
/// a centred label.
///
/// Rule colour: [AppColors.divider] (6% white), matching spec §2.
/// Label style: `caption` with +2% letter spacing per spec §3.
class DividerWithLabel extends StatelessWidget {
  const DividerWithLabel({this.label = 'OR', super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.divider, thickness: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            label,
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiary,
              letterSpacing: 0.26, // +2% of 13 px ≈ 0.26
            ),
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.divider, thickness: 1),
        ),
      ],
    );
  }
}
