import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../domain/entities/mfa.dart';
import '../providers/auth_providers.dart';
import '../widgets/labeled_text_field.dart';
import 'mfa_verify_screen.dart' show validateOtpCode;

/// Profile > Two-factor authentication: turn an authenticator-app code
/// on or off for this account.
class TwoFactorScreen extends ConsumerStatefulWidget {
  const TwoFactorScreen({super.key});

  @override
  ConsumerState<TwoFactorScreen> createState() => _TwoFactorScreenState();
}

class _TwoFactorScreenState extends ConsumerState<TwoFactorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  MfaEnrollment? _enrollment;
  bool _busy = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _start() async {
    setState(() => _busy = true);
    final result = await ref.read(authRepositoryProvider).startMfaEnrollment();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _enrollment = result.valueOrNull;
    });
    if (result.failureOrNull case final f?) _toast(f.message);
  }

  Future<void> _confirm() async {
    final enrollment = _enrollment;
    if (enrollment == null || _busy || !_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(authRepositoryProvider).verifyMfaCode(
          factorId: enrollment.factorId,
          code: _codeController.text.trim(),
        );
    if (!mounted) return;
    setState(() => _busy = false);
    if (result.failureOrNull case final f?) {
      _codeController.clear();
      _toast(f.message);
      return;
    }
    setState(() => _enrollment = null);
    _codeController.clear();
    ref.invalidate(mfaFactorsProvider);
    _toast('Two-factor authentication is on.');
  }

  Future<void> _disable(MfaFactor factor) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceElevated,
        title: Text('Turn off 2FA?', style: AppTypography.headlineSmall),
        content: Text(
          'Anyone with your password could then sign in to your account.',
          style: AppTypography.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Turn off'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final result =
        await ref.read(authRepositoryProvider).removeMfaFactor(factor.id);
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(mfaFactorsProvider);
    _toast(result.failureOrNull?.message ?? 'Two-factor authentication is off.');
  }

  Future<void> _openAuthenticator(String uri) async {
    final opened = await launchUrl(
      Uri.parse(uri),
      mode: LaunchMode.externalApplication,
    ).catchError((_) => false);
    if (!opened && mounted) {
      _toast('No authenticator app found. Copy the key instead.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final factors = ref.watch(mfaFactorsProvider);
    return Scaffold(
      body: HubPage(bottomPadding: AppSpacing.xl2, children: [
        Row(children: [
          HubBackButton(onPressed: () => context.pop()),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              'Two-factor authentication',
              style: AppTypography.headlineSmall
                  .copyWith(color: AppColors.hubTextBright),
            ),
          ),
        ]),
        const SizedBox(height: AppSpacing.md),
        factors.when(
          loading: () => const HubLoading(),
          error: (e, _) => HubMessageCard(
            icon: LucideIcons.circleAlert,
            title: "Couldn't load your security settings",
            message: '$e',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(mfaFactorsProvider),
          ),
          data: (list) => list.isNotEmpty
              ? _enabledCard(list.first)
              : _enrollment == null
                  ? _offCard()
                  : _setupCard(_enrollment!),
        ),
      ]),
    );
  }

  Widget _enabledCard(MfaFactor factor) => HubCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HubPill(label: 'On', icon: LucideIcons.shieldCheck),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Signing in asks for a code from your authenticator app.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.hubTextBright),
            ),
            const SizedBox(height: AppSpacing.md),
            HubOutlineButton(
              label: 'Turn off',
              onPressed: _busy ? null : () => _disable(factor),
            ),
          ],
        ),
      );

  Widget _offCard() => HubCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Add a second step to sign-in. Even if someone learns your '
              'password, they also need the code from your phone.',
              style: AppTypography.bodyMedium
                  .copyWith(color: AppColors.hubTextBright),
            ),
            const SizedBox(height: AppSpacing.md),
            HubGradientButton(
              label: 'Set up authenticator app',
              isLoading: _busy,
              onPressed: _busy ? null : _start,
            ),
          ],
        ),
      );

  Widget _setupCard(MfaEnrollment e) => HubCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '1. Add Grit to an authenticator app (Google Authenticator, '
                '1Password, Authy…).',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.hubTextBright),
              ),
              const SizedBox(height: AppSpacing.sm),
              HubGradientButton(
                label: 'Open authenticator app',
                icon: LucideIcons.externalLink,
                onPressed: () => _openAuthenticator(e.otpauthUri),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Or enter this key manually:',
                style: AppTypography.bodySmall
                    .copyWith(color: AppColors.hubTextMuted),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(children: [
                Expanded(
                  child: SelectableText(
                    e.secret,
                    style: AppTypography.numeric(AppTypography.bodyMedium)
                        .copyWith(color: AppColors.hubTextBright),
                  ),
                ),
                IconButton(
                  tooltip: 'Copy key',
                  icon: const Icon(LucideIcons.copy,
                      color: AppColors.hubTextMuted),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: e.secret));
                    _toast('Key copied');
                  },
                ),
              ]),
              const SizedBox(height: AppSpacing.md),
              Text(
                '2. Enter the 6-digit code it shows.',
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.hubTextBright),
              ),
              const SizedBox(height: AppSpacing.sm),
              LabeledTextField(
                label: 'Verification code',
                controller: _codeController,
                hintText: '123456',
                leadingIcon: Icons.verified_user_outlined,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                validator: validateOtpCode,
                onSubmitted: (_) => _confirm(),
              ),
              const SizedBox(height: AppSpacing.md),
              HubGradientButton(
                label: 'Turn on 2FA',
                isLoading: _busy,
                onPressed: _busy ? null : _confirm,
              ),
            ],
          ),
        ),
      );
}
