import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../gyms/presentation/providers/gym_providers.dart' show gymAccountProvider;
import '../../../gyms/presentation/widgets/gym_ui.dart';
import '../providers/health_providers.dart';
import 'health_marketplace_screen.dart' show HealthProviderCard;

/// Providers the user saved for later. Private to their account.
class SavedProvidersScreen extends ConsumerWidget {
  const SavedProvidersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final saved = ref.watch(savedProvidersProvider);
    final hasAccount = ref.watch(gymAccountProvider);

    Future<void> unsave(String listingId) async {
      final r = await ref.read(healthRepositoryProvider).setSaved(listingId, false);
      if (!context.mounted) return;
      r.when(
        success: (_) => ref.invalidate(savedProvidersProvider),
        failure: (f) => gymToast(context, f.message),
      );
    }

    return HubPage(
      children: [
        GymTitleBar(eyebrow: 'Health', title: 'Saved providers', onBack: () => context.pop()),
        const SizedBox(height: AppSpacing.md),
        if (!hasAccount)
          const HubMessageCard(
            icon: LucideIcons.userRound,
            title: 'Saving needs an account',
            message: 'Create a Grit account to keep providers for later.',
          )
        else
          saved.when(
            loading: () => const HubLoading(),
            error: (e, _) => HubMessageCard(
              icon: LucideIcons.circleAlert,
              title: "Couldn't load saved providers",
              message: healthErrorMessage(e),
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(savedProvidersProvider),
            ),
            data: (list) => list.isEmpty
                ? HubMessageCard(
                    icon: LucideIcons.heart,
                    title: 'Nothing saved yet',
                    message: 'Tap the heart on a provider to keep them here for later.',
                    actionLabel: 'Find a health pro',
                    onAction: () => context.go(AppRoutes.healthMarketplace),
                  )
                : Column(
                    children: [
                      for (final e in list) ...[
                        HealthProviderCard(entry: e, onSave: () => unsave(e.listingId)),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const GymNote('Saved on this account only. Providers don\'t see who saved them.'),
                    ],
                  ),
          ),
      ],
    );
  }
}
