import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_state_notifier.dart';
import '../widgets/auth_ui.dart';

/// Login screen (app_design/login screen.png): mascot-in-doorway hero
/// with the two-line title, over an opaque form card.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final failure = await ref.read(authStateProvider.notifier).signIn(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    if (!mounted) return;
    if (failure != null) {
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

  Widget _staggered(Widget child, int index) {
    final delay = Duration(milliseconds: 60 * index);
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
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Column(
                children: [
                  _buildHero(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.lg,
                    ),
                    child: _staggered(_buildFormCard(isLoading), 1),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        // Doorway art is 397×740; it occupies the right ~47% of the
        // screen width in the mockup.
        final artWidth = width * 0.47;
        final artHeight = artWidth * 740 / 397;
        return SizedBox(
          height: artHeight - AppSpacing.md,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: 0,
                top: 0,
                width: artWidth,
                child: Image.asset(
                  'assets/images/login_mascot_doorway.png',
                  fit: BoxFit.fitWidth,
                ).animate().fadeIn(duration: AppConstants.animSlow),
              ),
              Positioned(
                left: AppSpacing.lg,
                right: artWidth * 0.55,
                top: artHeight * 0.38,
                child: _staggered(
                  const AuthTwoLineTitle(
                    firstLine: 'Start',
                    secondLine: 'your journey',
                    subtitle: 'Log in to continue\nyour transformation.',
                  ),
                  0,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFormCard(bool isLoading) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md + 4,
        AppSpacing.lg,
        AppSpacing.md + 4,
        AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.authCardBorder),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.authCardTop, AppColors.authCardBottom],
        ),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const AuthFieldLabel('Email address'),
              AuthTextField(
                controller: _emailController,
                hintText: 'Enter your email',
                icon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
              ),
              const SizedBox(height: AppSpacing.md),
              const AuthFieldLabel('Password'),
              AuthTextField(
                controller: _passwordController,
                hintText: 'Enter your password',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                validator: Validators.password,
                onSubmitted: (_) => _handleLogin(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.forgotPassword),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.authSky,
                  ),
                  child: Text(
                    'Forgot password?',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.authSky,
                      fontWeight: AppTypography.medium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              AuthCtaButton(
                label: 'Log in',
                isLoading: isLoading,
                onPressed: _handleLogin,
              ),
              const SizedBox(height: AppSpacing.lg),
              const AuthOrDivider(),
              const SizedBox(height: AppSpacing.lg),
              AuthSocialTiles(
                onApple: _handleSocialAuth,
                onGoogle: _handleSocialAuth,
              ),
              const SizedBox(height: AppSpacing.sm),
              AuthSocialButton(
                label: 'Continue with Email',
                vertical: false,
                leading: const Icon(
                  Icons.mail_outline_rounded,
                  color: AppColors.white,
                  size: 24,
                ),
                onPressed: () => context.push(AppRoutes.register),
              ),
              const SizedBox(height: AppSpacing.sm),
              AuthFooterLink(
                prompt: "Don't have an account?",
                linkText: 'Sign up',
                onTap: () => context.push(AppRoutes.register),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
