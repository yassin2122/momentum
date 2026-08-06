import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../providers/auth_state_notifier.dart';
import '../widgets/auth_footer_prompt.dart';
import '../widgets/auth_header.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/wordmark_lockup.dart';

/// MOTRA Register / Sign-up Screen.
///
/// Built on the same MOTRA design system tokens and glass widgets as [LoginScreen].
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final failure = await ref.read(authStateProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;
    if (failure != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    } else {
      context.go(AppRoutes.dashboard);
    }
  }

  static const _bgDecoration = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.bgGradientTop,
        AppColors.bgGradientBottom,
      ],
    ),
  );

  Widget _staggered(Widget child, int index) {
    const rowDuration = Duration(milliseconds: 250);
    final delay = Duration(milliseconds: 60 * index);
    return child
        .animate()
        .fadeIn(delay: delay, duration: rowDuration, curve: Curves.easeOut)
        .slideY(
          begin: 0.06,
          end: 0,
          delay: delay,
          duration: rowDuration,
          curve: Curves.easeOut,
        );
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: BackButton(
          color: AppColors.textPrimary,
          onPressed: () => context.pop(),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: _bgDecoration,
        child: LoadingOverlay(
          isLoading: isLoading,
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.md),

                    // ── Wordmark ──────────────────────────────────────────
                    _staggered(
                      const Center(child: WordmarkLockup()),
                      0,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Header ───────────────────────────────────────────
                    _staggered(
                      const AuthHeaderText(
                        title: 'Start your journey',
                        subtitle: 'Create an account to begin your transformation.',
                      ),
                      1,
                    ),

                    const SizedBox(height: AppSpacing.lg),

                    // ── Email field ───────────────────────────────────────
                    _staggered(
                      LabeledTextField(
                        label: 'Email address',
                        controller: _emailController,
                        hintText: 'you@example.com',
                        leadingIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                      ),
                      2,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // ── Password field ────────────────────────────────────
                    _staggered(
                      LabeledTextField(
                        label: 'Password',
                        controller: _passwordController,
                        hintText: 'At least 8 characters',
                        leadingIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        validator: Validators.password,
                      ),
                      3,
                    ),

                    const SizedBox(height: AppSpacing.sm),

                    // ── Confirm password ──────────────────────────────────
                    _staggered(
                      LabeledTextField(
                        label: 'Confirm Password',
                        controller: _confirmController,
                        hintText: 'Re-enter your password',
                        leadingIcon: Icons.lock_outline_rounded,
                        obscureText: true,
                        textInputAction: TextInputAction.done,
                        validator: Validators.confirmPassword(
                          () => _passwordController.text,
                        ),
                        onSubmitted: (_) => _handleRegister(),
                      ),
                      4,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Gradient CTA ──────────────────────────────────────
                    _staggered(
                      GradientPillButton(
                        label: 'Create Account',
                        isLoading: isLoading,
                        onPressed: _handleRegister,
                      ),
                      5,
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // ── Footer ───────────────────────────────────────────
                    _staggered(
                      AuthFooterPrompt(
                        bodyText: 'Already have an account?',
                        linkText: 'Log in',
                        onLinkTap: () => context.pop(),
                      ),
                      6,
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
