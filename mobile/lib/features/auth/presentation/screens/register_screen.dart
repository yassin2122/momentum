import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_state_notifier.dart';
import '../widgets/account_type_picker.dart';
import '../widgets/auth_ui.dart';

/// Register screen (app_design/register screen.png).
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _agreedToTerms = false;
  AccountType _accountType = AccountType.athlete;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreedToTerms) {
      _showError('Please agree to the Terms of Service and Privacy Policy.');
      return;
    }
    FocusScope.of(context).unfocus();

    final name = _nameController.text.trim();
    final failure = await ref.read(authStateProvider.notifier).register(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          displayName: name.isEmpty ? null : name,
        );

    if (!mounted) return;
    if (failure is EmailConfirmationRequiredFailure) {
      // Account exists but has no session until the email is confirmed.
      _showError(failure.message);
      _goToLogin();
    } else if (failure != null) {
      _showError(failure.message);
    } else {
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _handleSocialAuth() async {
    FocusScope.of(context).unfocus();
    final failure =
        await ref.read(authStateProvider.notifier).continueAsGuest();

    if (!mounted) return;
    if (failure != null) {
      _showError(failure.message);
    } else {
      context.go(AppRoutes.dashboard);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _goToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRoutes.login);
    }
  }

  Widget _staggered(Widget child, int index) {
    final delay = Duration(milliseconds: 50 * index);
    return child
        .animate()
        .fadeIn(delay: delay, duration: AppConstants.animMedium)
        .slideY(begin: 0.06, end: 0, delay: delay, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(authStateProvider).isLoading;

    return Scaffold(
      backgroundColor: AppColors.authBackground,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.3),
            radius: 1.1,
            colors: [AppColors.authBackgroundGlow, AppColors.authBackground],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.lg,
                ),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: _buildChildren(isLoading)
                          .asMap()
                          .entries
                          .map((e) => _staggered(e.value, e.key))
                          .toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildChildren(bool isLoading) {
    return [
      Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: AppColors.authBackButton,
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: _goToLogin,
            icon: const Icon(Icons.arrow_back, color: AppColors.white),
            tooltip: 'Back',
          ),
        ),
      ),
      const SizedBox(height: AppSpacing.xl),
      const AuthTwoLineTitle(
        firstLine: 'Create',
        secondLine: 'your account',
        subtitle: 'Join Grit and start\nyour transformation.',
      ),
      const SizedBox(height: AppSpacing.lg),
      AccountTypePicker(
        value: _accountType,
        onChanged: (type) => setState(() => _accountType = type),
      ),
      const SizedBox(height: AppSpacing.lg),
      AuthTextField(
        controller: _nameController,
        hintText: 'Full name',
        icon: Icons.person_outline_rounded,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.name],
      ),
      const SizedBox(height: AppSpacing.sm),
      AuthTextField(
        controller: _emailController,
        hintText: 'Email address',
        icon: Icons.mail_outline_rounded,
        keyboardType: TextInputType.emailAddress,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.email],
        validator: Validators.email,
      ),
      const SizedBox(height: AppSpacing.sm),
      AuthTextField(
        controller: _passwordController,
        hintText: 'Password',
        icon: Icons.lock_outline_rounded,
        isPassword: true,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newPassword],
        validator: Validators.password,
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.sm,
        ),
        child: Text(
          'Use 8+ characters with a mix of letters, numbers & symbols.',
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.authTextHint,
          ),
        ),
      ),
      AuthTextField(
        controller: _confirmController,
        hintText: 'Confirm password',
        icon: Icons.lock_outline_rounded,
        isPassword: true,
        textInputAction: TextInputAction.done,
        validator: Validators.confirmPassword(() => _passwordController.text),
        onSubmitted: (_) => _handleRegister(),
      ),
      const SizedBox(height: AppSpacing.md),
      _buildTermsRow(),
      const SizedBox(height: AppSpacing.md),
      AuthCtaButton(
        label: 'Create account',
        isLoading: isLoading,
        onPressed: _handleRegister,
      ),
      const SizedBox(height: AppSpacing.lg),
      const AuthOrDivider(),
      const SizedBox(height: AppSpacing.lg),
      AuthSocialTiles(onApple: _handleSocialAuth, onGoogle: _handleSocialAuth),
      const SizedBox(height: AppSpacing.md),
      AuthFooterLink(
        prompt: 'Already have an account?',
        linkText: 'Log in',
        onTap: _goToLogin,
      ),
    ];
  }

  Widget _buildTermsRow() {
    final base = AppTypography.bodySmall.copyWith(
      color: AppColors.authTextSubtitle,
      fontSize: 13,
    );
    final link = base.copyWith(color: AppColors.authSky);
    return InkWell(
      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: Checkbox(
              value: _agreedToTerms,
              onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
              activeColor: AppColors.authCtaStart,
              checkColor: AppColors.white,
              side: const BorderSide(color: AppColors.authTextHint),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: base,
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(text: 'Terms of Service', style: link),
                  const TextSpan(text: ' and '),
                  TextSpan(text: 'Privacy Policy', style: link),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
