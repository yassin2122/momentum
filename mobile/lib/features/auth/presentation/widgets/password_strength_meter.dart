import 'package:flutter/material.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/password_strength.dart';

/// Live strength bar + what's still missing, under a new-password field.
/// Advisory only — the server rejects passwords that miss the rules.
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({required this.controller, super.key});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final text = value.text;
        final level = PasswordStrength.evaluate(text);
        final missing = PasswordStrength.missingRequirements(text);
        final (filled, color, label) = switch (level) {
          PasswordStrengthLevel.empty => (0, AppColors.authTextHint, ''),
          PasswordStrengthLevel.weak => (1, AppColors.error, 'Weak'),
          PasswordStrengthLevel.fair => (2, AppColors.warning, 'Fair'),
          PasswordStrengthLevel.good => (3, AppColors.success, 'Good'),
          PasswordStrengthLevel.strong => (4, AppColors.success, 'Strong'),
        };
        final hint = text.isEmpty
            ? 'Use 8+ characters with upper & lowercase letters and a number.'
            : missing.isNotEmpty
                ? 'Add ${missing.join(', ')}.'
                : level == PasswordStrengthLevel.strong
                    ? 'Great password.'
                    : 'Longer, or add a symbol, to make it stronger.';

        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.xs,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: AnimatedContainer(
                        duration: AppConstants.animFast,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i < filled ? color : AppColors.divider,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                    ),
                  ],
                  if (label.isNotEmpty) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      label,
                      style: AppTypography.bodySmall.copyWith(color: color),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                hint,
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.authTextHint),
              ),
            ],
          ),
        );
      },
    );
  }
}
