import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// A horizontal rule split by a centered label — e.g. the `OR` divider
/// between the email/password form and social sign-in options.
class DividerWithLabel extends StatelessWidget {
  const DividerWithLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(color: AppColors.divider, thickness: 1, height: 1),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            label,
            style: AppTypography.labelMedium,
          ),
        ),
        const Expanded(
          child: Divider(color: AppColors.divider, thickness: 1, height: 1),
        ),
      ],
    );
  }
}
