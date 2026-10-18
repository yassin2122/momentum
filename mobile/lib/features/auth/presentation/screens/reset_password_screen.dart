import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../providers/auth_state_notifier.dart';
import '../widgets/auth_footer_prompt.dart';
import '../widgets/auth_header.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/labeled_text_field.dart';

/// Set-new-password screen — the final step of the reset flow.
///
/// The router sends the user here when they open the emailed reset link
/// (Supabase emits a password-recovery event) and keeps them here until
/// [AuthStateNotifier.updatePassword] succeeds or they cancel. Navigation
/// away is driven entirely by the router's redirect, not by this screen.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final failure = await ref
        .read(authStateProvider.notifier)
        .updatePassword(_passwordController.text);

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(failure?.message ?? 'Password updated.')),
      );
  }

  /// Abandoning the reset ends the recovery session rather than leaving
  /// the user signed in through a link they may not have meant to use.
  void _handleCancel() => ref.read(authStateProvider.notifier).signOut();

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
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: AppSpacing.xl2),
                      const AuthHeaderText(
                        title: 'Set a new password',
                        subtitle: 'Choose a password you haven\'t used '
                            'before. You\'ll stay signed in afterwards.',
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      LabeledTextField(
                        label: 'New password',
                        controller: _passwordController,
                        hintText: 'At least 8 characters',
                        leadingIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: Validators.password,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      LabeledTextField(
                        label: 'Confirm password',
                        controller: _confirmController,
                        hintText: 'Re-enter your new password',
                        leadingIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: Validators.confirmPassword(
                          () => _passwordController.text,
                        ),
                        onSubmitted: (_) => _handleSubmit(),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      GradientPillButton(
                        label: 'Update Password',
                        isLoading: _isSubmitting,
                        onPressed: _handleSubmit,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      AuthFooterPrompt(
                        bodyText: 'Changed your mind?',
                        linkText: 'Cancel',
                        onLinkTap: _handleCancel,
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
