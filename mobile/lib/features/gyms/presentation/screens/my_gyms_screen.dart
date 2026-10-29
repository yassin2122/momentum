import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_ui.dart';

/// Profile → Your gyms: the gyms this account works at, plus registering a
/// gym or joining a gym's team with a code from its owner.
class MyGymsScreen extends ConsumerWidget {
  const MyGymsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gyms = ref.watch(myGymsProvider);
    final hasAccount = ref.watch(gymAccountProvider);

    Future<void> join() async {
      final gymId = await showGymSheet<String>(context, const _JoinTeamSheet());
      if (gymId != null && context.mounted) {
        ref.invalidate(myGymsProvider);
        context.push(AppRoutes.gymAdminPath(gymId));
      }
    }

    return HubPage(
      bottomPadding: AppSpacing.xl2,
      children: [
        GymTitleBar(eyebrow: 'Grit for gyms', title: 'Your gyms', onBack: () => context.pop()),
        const SizedBox(height: AppSpacing.md),
        if (!hasAccount)
          const HubMessageCard(
            icon: LucideIcons.userRound,
            title: 'Create an account first',
            message: 'Gyms are managed from a Grit account.',
          )
        else
          gyms.when(
            loading: () => const GymRowsSkeleton(semanticLabel: 'Loading your gyms'),
            error: (e, _) => HubMessageCard(
              icon: LucideIcons.circleAlert,
              title: "Couldn't load your gyms",
              message: gymErrorMessage(e),
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(myGymsProvider),
            ),
            data: (list) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (list.isNotEmpty) ...[
                  GymSection(
                    header: 'Dashboards',
                    children: [
                      for (final g in list)
                        GymRow(
                          leading: GymLogo(name: g.name, url: g.logoUrl, size: 36),
                          title: g.name,
                          value: g.role.label,
                          onTap: () => context.push(AppRoutes.gymAdminPath(g.gymId)),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ] else ...[
                  const GymNote(
                    'Own or run a gym? Give it a page in Find a gym, add your '
                    'coaches, and answer people who want to join.',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                GymSection(
                  children: [
                    GymRow(
                      icon: LucideIcons.plus,
                      title: 'Register a gym',
                      onTap: () => context.push(AppRoutes.gymRegister),
                    ),
                    GymRow(
                      icon: LucideIcons.keyRound,
                      title: 'Join a gym team',
                      subtitle: 'Enter the team code your gym owner gave you',
                      onTap: join,
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _JoinTeamSheet extends ConsumerStatefulWidget {
  const _JoinTeamSheet();

  @override
  ConsumerState<_JoinTeamSheet> createState() => _JoinTeamSheetState();
}

class _JoinTeamSheetState extends ConsumerState<_JoinTeamSheet> {
  final _code = TextEditingController();
  String? _error;
  bool _sending = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final code = _code.text.trim();
    if (code.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').length < 8) {
      setState(() => _error = 'Codes look like ABCD-1234');
      return;
    }
    setState(() {
      _error = null;
      _sending = true;
    });
    final r = await ref.read(gymRepositoryProvider).acceptStaffInvite(code);
    if (!mounted) return;
    setState(() => _sending = false);
    r.when(
      success: (gymId) => Navigator.of(context).pop(gymId),
      failure: (f) => setState(() => _error = f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GymSheetHeader(
          title: 'Join a gym team',
          subtitle: 'Team codes work once and expire after 7 days.',
        ),
        GymTextField(
          label: 'Team code',
          controller: _code,
          error: _error,
          hint: 'ABCD-1234',
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          maxLength: 9,
        ),
        const SizedBox(height: AppSpacing.sm),
        HubGradientButton(
          label: 'Join team',
          height: AppSizing.buttonHeight,
          isLoading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
