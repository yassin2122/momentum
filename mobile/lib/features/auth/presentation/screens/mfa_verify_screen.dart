import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../providers/auth_providers.dart';
import '../providers/auth_state_notifier.dart';
import '../widgets/auth_footer_prompt.dart';
import '../widgets/auth_header.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/labeled_text_field.dart';

/// Second sign-in step for accounts with 2FA. The router keeps the user
/// here until the code is accepted; the database refuses every request
/// from this half-signed-in session anyway.
class MfaVerifyScreen extends ConsumerStatefulWidget {
  const MfaVerifyScreen({super.key});

  @override
  ConsumerState<MfaVerifyScreen> createState() => _MfaVerifyScreenState();
}

class _MfaVerifyScreenState extends ConsumerState<MfaVerifyScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final repo = ref.read(authRepositoryProvider);
    final factors = await repo.getMfaFactors();
    final factorId = factors.valueOrNull?.firstOrNull?.id;
    final failure = factorId == null
        ? factors.failureOrNull
        : (await repo.verifyMfaCode(
            factorId: factorId,
            code: _codeController.text.trim(),
          ))
            .failureOrNull;

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (failure != null || factorId == null) {
      _codeController.clear();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(failure?.message ?? 'Could not verify. Try again.'),
        ));
      return;
    }
    context.go(AppRoutes.dashboard);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.bgGradientTop, AppColors.bgGradientBottom],
          ),
        ),
        child: LoadingOverlay(
          isLoading: _isSubmitting,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.xl2),
                    const AuthHeaderText(
                      title: 'Two-factor check',
                      subtitle: 'Enter the 6-digit code from your '
                          'authenticator app to finish signing in.',
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    LabeledTextField(
                      label: 'Verification code',
                      controller: _codeController,
                      hintText: '123456',
                      leadingIcon: Icons.verified_user_outlined,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      validator: validateOtpCode,
                      onSubmitted: (_) => _handleSubmit(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    GradientPillButton(
                      label: 'Verify',
                      isLoading: _isSubmitting,
                      onPressed: _handleSubmit,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AuthFooterPrompt(
                      bodyText: 'Not you?',
                      linkText: 'Sign out',
                      onLinkTap: () =>
                          ref.read(authStateProvider.notifier).signOut(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A TOTP code is exactly six digits.
String? validateOtpCode(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Enter the 6-digit code';
  if (!RegExp(r'^\d{6}$').hasMatch(v)) return 'The code is 6 digits';
  return null;
}
