import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Static hero visual for the auth screen — vertical background
/// gradient plus the GRIT mascot illustration, anchored bottom-right
/// with its glow baked into the source asset.
///
/// Deliberately dumb/static: headline copy ("Start your journey" vs
/// "Welcome back") lives in [LoginScreen] itself so it can toggle
/// between login/sign-up modes and animate independently of this
/// backdrop, which never changes.
class LoginHeroSection extends StatelessWidget {
  const LoginHeroSection({super.key});

  @override
  Widget build(BuildContext context) {
    // ~42% of screen height matches the reference layout's hero-to-form
    // proportion across common phone aspect ratios.
    final double heroHeight = MediaQuery.sizeOf(context).height * 0.42;

    return SizedBox(
      height: heroHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [AppColors.bgGradientTop, AppColors.bgGradientBottom],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: FractionallySizedBox(
              heightFactor: 0.95,
              child: Image.asset(
                'assets/images/auth/mascot_hero.png',
                fit: BoxFit.contain,
                alignment: Alignment.bottomRight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
