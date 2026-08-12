import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/app_typography.dart';
import 'secondary_button.dart';
import '../theme/app_sizing.dart';

/// Standard empty state: icon + title + message + optional action.
/// One component for every "nothing here yet" case app-wide — zero
/// search results, no network, empty history/plans later — parameterized
/// rather than duplicated per screen.
class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizing.iconLg, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: AppTypography.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            style: AppTypography.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: 200,
              child: SecondaryButton(
                label: actionLabel!,
                onPressed: onAction,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
