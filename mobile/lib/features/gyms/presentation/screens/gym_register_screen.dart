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

/// Register a gym. It starts as a private draft; the owner fills in the
/// profile from the gym dashboard and publishes when it's ready.
class GymRegisterScreen extends ConsumerStatefulWidget {
  const GymRegisterScreen({super.key});

  @override
  ConsumerState<GymRegisterScreen> createState() => _GymRegisterScreenState();
}

class _GymRegisterScreenState extends ConsumerState<GymRegisterScreen> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  bool _multiBranch = false;
  bool _saving = false;
  final _errors = <String, String?>{};

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _name.text.trim();
    final city = _city.text.trim();
    final phone = _phone.text.trim();
    final email = _email.text.trim();
    setState(() {
      _errors
        ..['name'] = name.length < 2 ? 'Add the gym name' : null
        ..['city'] = city.isEmpty ? 'Add the city' : null
        ..['phone'] = phone.replaceAll(RegExp(r'[^0-9]'), '').length < 8
            ? 'Add a phone number members can call'
            : null
        ..['email'] = email.isNotEmpty && !email.contains('@')
            ? "That email doesn't look right"
            : null;
    });
    if (_errors.values.any((e) => e != null)) return;
    setState(() => _saving = true);
    final result = await ref.read(gymRepositoryProvider).createGym(
          name: name,
          city: city,
          phone: phone,
          email: email.isEmpty ? null : email,
          multiBranch: _multiBranch,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (gymId) {
        ref.invalidate(myGymsProvider);
        context.pushReplacement(AppRoutes.gymAdminPath(gymId));
      },
      failure: (f) => gymToast(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(gymAccountProvider)) {
      return HubPage(bottomPadding: AppSpacing.xl2, children: [
        GymTitleBar(title: 'Register your gym', onBack: () => context.pop()),
        const SizedBox(height: AppSpacing.md),
        const HubMessageCard(
          icon: LucideIcons.userRound,
          title: 'Create an account first',
          message: 'Gyms are managed from a Grit account. Sign up, then '
              'come back here to register your gym.',
        ),
      ]);
    }
    return HubPage(
      bottomPadding: AppSizing.buttonHeight + AppSpacing.xl4,
      bottomBar: HubGradientButton(
        label: 'Create gym',
        height: AppSizing.buttonHeight,
        isLoading: _saving,
        onPressed: _saving ? null : _create,
      ),
      children: [
        GymTitleBar(
          eyebrow: 'Grit for gyms',
          title: 'Register your gym',
          onBack: () => context.pop(),
        ),
        const SizedBox(height: AppSpacing.md),
        const GymNote(
          'Your gym page starts as a private draft. Add photos, branches and '
          'offers, then publish it when it\'s ready. Grit reviews new '
          'listings before they appear in Find a gym.',
        ),
        const SizedBox(height: AppSpacing.lg),
        GymTextField(
          label: 'Gym name',
          controller: _name,
          error: _errors['name'],
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'City',
          controller: _city,
          error: _errors['city'],
          textCapitalization: TextCapitalization.words,
          maxLength: 60,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'Phone',
          controller: _phone,
          error: _errors['phone'],
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          maxLength: 20,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'Email',
          controller: _email,
          error: _errors['email'],
          optional: true,
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          maxLength: 120,
        ),
        const SizedBox(height: AppSpacing.md),
        GymSection(
          footer: 'You can add branches from the dashboard.',
          children: [
            GymSwitchRow(
              title: 'More than one branch',
              value: _multiBranch,
              onChanged: (v) => setState(() => _multiBranch = v),
            ),
          ],
        ),
      ],
    );
  }
}
