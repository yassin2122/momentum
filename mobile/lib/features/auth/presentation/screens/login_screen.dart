import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../../../../core/utils/validators.dart';
import '../providers/auth_state_notifier.dart';
import '../widgets/auth_footer_prompt.dart';
import '../widgets/divider_with_label.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/login_hero_section.dart';
import '../widgets/social_auth_row.dart';

/// MOTRA auth screen — matching exact user layout & specifications.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();

  bool _isSignUpMode = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleAuthSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    final failure = _isSignUpMode
        ? await ref.read(authStateProvider.notifier).register(
              email: email,
              password: password,
            )
        : await ref.read(authStateProvider.notifier).signIn(
              email: email,
              password: password,
            );

    if (!mounted) return;
    if (failure != null) {
      _showError(failure.message);
    } else {
      context.go(AppRoutes.dashboard);
    }
  }

  Future<void> _handleSocialAuth(String providerName) async {
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
      backgroundColor: AppColors.bgGradientBottom,
      body: LoadingOverlay(
        isLoading: isLoading,
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const LoginHeroSection(),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    20,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _staggered(_buildHeaderText(), 0),
                        const SizedBox(height: 20),
                        _staggered(
                          LabeledTextField(
                            label: 'Email address',
                            controller: _emailController,
                            focusNode: _emailFocusNode,
                            hintText: 'Enter your email',
                            leadingIcon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: Validators.email,
                          ),
                          1,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _staggered(
                          LabeledTextField(
                            label: 'Password',
                            controller: _passwordController,
                            hintText: 'Enter your password',
                            leadingIcon: Icons.lock_outline_rounded,
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            validator: Validators.password,
                            onSubmitted: (_) => _handleAuthSubmit(),
                          ),
                          2,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        if (!_isSignUpMode)
                          _staggered(
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () =>
                                    context.push(AppRoutes.forgotPassword),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Text(
                                    'Forgot password?',
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.accentLink,
                                      fontSize: 12,
                                      fontWeight: AppTypography.medium,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            3,
                          ),
                        const SizedBox(height: 20),
                        _staggered(
                          GradientPillButton(
                            label: 'LOG IN',
                            isLoading: isLoading,
                            onPressed: _handleAuthSubmit,
                          ),
                          4,
                        ),
                        const SizedBox(height: 20),
                        _staggered(const DividerWithLabel(label: 'OR'), 5),
                        const SizedBox(height: 20),
                        _staggered(
                          SocialAuthRow(
                            onApplePressed: () => _handleSocialAuth('Apple'),
                            onGooglePressed: () => _handleSocialAuth('Google'),
                            onEmailPressed: () {
                              _emailFocusNode.requestFocus();
                            },
                          ),
                          6,
                        ),
                        const SizedBox(height: 20),
                        _staggered(
                          AuthFooterPrompt(
                            bodyText: _isSignUpMode
                                ? 'Already have an account?'
                                : "Don't have an account?",
                            linkText: _isSignUpMode ? 'Log in' : 'Sign up',
                            onLinkTap: () {
                              setState(() {
                                _isSignUpMode = !_isSignUpMode;
                              });
                            },
                          ),
                          7,
                        ),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderText() {
    final title = _isSignUpMode ? 'Start your journey' : 'Welcome back';
    final subtitle = _isSignUpMode
        ? 'Create an account to begin your transformation.'
        : 'Log in to continue your transformation.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.headlineMedium.copyWith(
            color: AppColors.textPrimary,
            fontSize: 22,
            fontWeight: AppTypography.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}
