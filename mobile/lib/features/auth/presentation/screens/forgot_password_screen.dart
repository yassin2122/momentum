import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/loading_overlay.dart';
import '../providers/auth_state_notifier.dart';
import '../widgets/auth_footer_prompt.dart';
import '../widgets/auth_header.dart';
import '../widgets/gradient_pill_button.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/wordmark_lockup.dart';

/// MOTRA Forgot / Reset Password Screen.
///
/// Shares the MOTRA visual identity, dark background gradient, glass inputs,
/// and gradient CTA.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isSubmitting = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    final failure = await ref
        .read(authStateProvider.notifier)
        .sendPasswordReset(_emailController.text.trim());

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (failure != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    } else {
      setState(() => _emailSent = true);
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
          isLoading: _isSubmitting,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
              ),
              child: _emailSent ? _buildConfirmation() : _buildForm(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
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
                title: 'Reset password',
                subtitle:
                    "Enter your email and we'll send you a reset link.",
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
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                validator: Validators.email,
                onSubmitted: (_) => _handleSubmit(),
              ),
              2,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Gradient CTA ──────────────────────────────────────
            _staggered(
              GradientPillButton(
                label: 'Send Reset Link',
                isLoading: _isSubmitting,
                onPressed: _handleSubmit,
              ),
              3,
            ),

            const SizedBox(height: AppSpacing.xl),

            // ── Footer ───────────────────────────────────────────
            _staggered(
              AuthFooterPrompt(
                bodyText: 'Remember your password?',
                linkText: 'Log in',
                onLinkTap: () => context.pop(),
              ),
              4,
            ),

            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmation() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.heroGlowSoft,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: AppColors.heroGlow,
              size: 54,
            ),
          ).animate().scale(duration: 350.ms, curve: Curves.easeOutBack),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Check your email',
            style: AppTypography.headlineLarge.copyWith(
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "We've sent a password reset link to ${_emailController.text.trim()}.",
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          GradientPillButton(
            label: 'Back to Log In',
            onPressed: () => context.pop(),
          ),
        ],
      ),
    );
  }
}
