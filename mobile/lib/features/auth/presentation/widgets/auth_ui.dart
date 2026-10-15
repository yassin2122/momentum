import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';

/// Shared building blocks for the Splash / Login / Register screens
/// (app_design/*.png). They sit on the near-black auth canvas, so they
/// use the `auth*` tokens in [AppColors] rather than the general ones.

/// Two-line hero title: white first line, sky-gradient second line.
class AuthTwoLineTitle extends StatelessWidget {
  const AuthTwoLineTitle({
    super.key,
    required this.firstLine,
    required this.secondLine,
    required this.subtitle,
  });

  final String firstLine;
  final String secondLine;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final titleStyle = AppTypography.displayLarge.copyWith(
      fontSize: 34,
      height: 1.12,
      color: AppColors.white,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(firstLine, style: titleStyle),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) => const LinearGradient(
            colors: [
              AppColors.authTitleGradientStart,
              AppColors.authTitleGradientEnd,
            ],
          ).createShader(bounds),
          child: Text(secondLine, style: titleStyle),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          subtitle,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.authTextSubtitle,
          ),
        ),
      ],
    );
  }
}

/// Uppercase field label used above Login's inputs.
class AuthFieldLabel extends StatelessWidget {
  const AuthFieldLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.xs),
      child: Text(
        text.toUpperCase(),
        style: AppTypography.labelMedium.copyWith(
          color: AppColors.authTextLabel,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

/// Dark rounded input with a leading icon and, for passwords, an eye
/// toggle.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.focusNode,
    this.isPassword = false,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final FocusNode? focusNode;
  final bool isPassword;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscured = true;

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.medium + 2),
        borderSide: BorderSide(color: color),
      );

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      focusNode: widget.focusNode,
      obscureText: widget.isPassword && _obscured,
      keyboardType: widget.keyboardType,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      validator: widget.validator,
      onFieldSubmitted: widget.onSubmitted,
      cursorColor: AppColors.authSky,
      style: AppTypography.bodyLarge.copyWith(color: AppColors.white),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: AppTypography.bodyLarge.copyWith(
          color: AppColors.authTextHint,
        ),
        filled: true,
        fillColor: AppColors.authInputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: 18,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: AppSpacing.md, right: 10),
          child: Icon(widget.icon, color: AppColors.authTextLabel, size: 22),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 48),
        suffixIcon: widget.isPassword
            ? IconButton(
                onPressed: () => setState(() => _obscured = !_obscured),
                icon: Icon(
                  _obscured
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: AppColors.authTextLabel,
                  size: 22,
                ),
              )
            : null,
        enabledBorder: _border(AppColors.authInputBorder),
        focusedBorder: _border(AppColors.authSky),
        errorBorder: _border(AppColors.error),
        focusedErrorBorder: _border(AppColors.error),
        errorStyle: AppTypography.bodySmall.copyWith(color: AppColors.error),
      ),
    );
  }
}

/// Full-width steel-blue gradient CTA ("LOG IN", "CREATE ACCOUNT").
class AuthCtaButton extends StatelessWidget {
  const AuthCtaButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.large);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.authCtaStart,
            AppColors.authCtaMid,
            AppColors.authCtaEnd,
          ],
        ),
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: radius,
          onTap: isLoading ? null : onPressed,
          child: SizedBox(
            height: 56,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.white,
                      ),
                    )
                  : Text(
                      label.toUpperCase(),
                      style: AppTypography.button.copyWith(
                        color: AppColors.white,
                        fontSize: 18,
                        fontWeight: AppTypography.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "──── OR ────" separator.
class AuthOrDivider extends StatelessWidget {
  const AuthOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    const line = Expanded(
      child: Divider(color: AppColors.authInputBorder, thickness: 1),
    );
    return Row(
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'OR',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.authTextHint,
              fontWeight: AppTypography.semiBold,
            ),
          ),
        ),
        line,
      ],
    );
  }
}

/// Dark outlined social/email button. [vertical] stacks icon over label
/// (the Apple / Google tiles); otherwise icon and label sit in a row.
class AuthSocialButton extends StatelessWidget {
  const AuthSocialButton({
    super.key,
    required this.label,
    required this.leading,
    required this.onPressed,
    this.vertical = true,
  });

  final String label;
  final Widget leading;
  final VoidCallback onPressed;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.medium + 2);
    final text = Text(
      label,
      textAlign: TextAlign.center,
      style: AppTypography.labelLarge.copyWith(color: AppColors.white),
    );
    return Material(
      color: AppColors.authInputFill,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: const BorderSide(color: AppColors.authInputBorder),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: onPressed,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: vertical ? AppSpacing.md : 18,
          ),
          child: vertical
              ? Column(
                  children: [
                    leading,
                    const SizedBox(height: AppSpacing.xs),
                    text,
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    leading,
                    const SizedBox(width: AppSpacing.sm),
                    text,
                  ],
                ),
        ),
      ),
    );
  }
}

/// Apple + Google tiles side by side.
class AuthSocialTiles extends StatelessWidget {
  const AuthSocialTiles({
    super.key,
    required this.onApple,
    required this.onGoogle,
  });

  final VoidCallback onApple;
  final VoidCallback onGoogle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: AuthSocialButton(
            label: 'Continue with Apple',
            onPressed: onApple,
            leading: const Icon(Icons.apple, color: AppColors.white, size: 30),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: AuthSocialButton(
            label: 'Continue with Google',
            onPressed: onGoogle,
            leading: Image.asset(
              'assets/images/auth/google_icon.png',
              width: 30,
              height: 30,
            ),
          ),
        ),
      ],
    );
  }
}

/// "Already have an account?  Log in" footer.
class AuthFooterLink extends StatelessWidget {
  const AuthFooterLink({
    super.key,
    required this.prompt,
    required this.linkText,
    required this.onTap,
  });

  final String prompt;
  final String linkText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prompt,
          style: AppTypography.bodyLarge.copyWith(
            color: AppColors.authTextSubtitle,
          ),
        ),
        TextButton(
          onPressed: onTap,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.authSky,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
          child: Text(
            linkText,
            style: AppTypography.bodyLarge.copyWith(
              color: AppColors.authSky,
              fontWeight: AppTypography.medium,
            ),
          ),
        ),
      ],
    );
  }
}
