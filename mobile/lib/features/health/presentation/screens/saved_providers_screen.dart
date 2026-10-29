import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../../core/widgets/provider_card.dart';
import '../../../gyms/presentation/providers/gym_providers.dart' show gymAccountProvider;
import '../../../gyms/presentation/widgets/gym_ui.dart';
import '../providers/health_providers.dart';
import 'health_marketplace_screen.dart' show HealthProviderCard;

/// Providers the user saved for later. Private to their account.
class SavedProvidersScreen extends ConsumerStatefulWidget {
  const SavedProvidersScreen({super.key});

  @override
  ConsumerState<SavedProvidersScreen> createState() =>
      _SavedProvidersScreenState();
}

class _SavedProvidersScreenState extends ConsumerState<SavedProvidersScreen> {
  /// Unsaved locally, hidden right away while the server catches up.
  final _hidden = <String>{};

  Future<void> _unsave(String listingId) async {
    final repo = ref.read(healthRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _hidden.add(listingId));
    final r = await repo.setSaved(listingId, false);
    if (!mounted) return;
    if (r.failureOrNull case final f?) {
      setState(() => _hidden.remove(listingId));
      gymToast(context, f.message);
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: const Text('Removed from saved'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            final undo = await repo.setSaved(listingId, true);
            if (!mounted) return;
            if (undo.failureOrNull case final f?) {
              gymToast(context, f.message);
              return;
            }
            setState(() => _hidden.remove(listingId));
            ref.invalidate(savedProvidersProvider);
          },
        ),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedProvidersProvider);
    final hasAccount = ref.watch(gymAccountProvider);

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
            loading: () =>
                const ProviderCardSkeleton(semanticLabel: 'Loading saved providers'),
            error: (e, _) => HubMessageCard(
              icon: LucideIcons.circleAlert,
              title: "Couldn't load saved providers",
              message: healthErrorMessage(e),
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(savedProvidersProvider),
            ),
            data: (all) {
              final list =
                  all.where((e) => !_hidden.contains(e.listingId)).toList();
              return list.isEmpty
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
                        HealthProviderCard(entry: e, onSave: () => _unsave(e.listingId)),
                        const SizedBox(height: AppSpacing.sm),
                      ],
                      const GymNote('Saved on this account only. Providers don\'t see who saved them.'),
                    ],
                  );
            },
          ),
      ],
    );
  }
}
