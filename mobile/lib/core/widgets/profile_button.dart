import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../constants/app_constants.dart';
import 'app_icon_button.dart';

/// Opens the account screen. Sits in the header of every tab, since
/// Profile is reached from the pillars rather than being a tab itself.
class ProfileButton extends StatelessWidget {
  const ProfileButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Profile',
      button: true,
      child: AppIconButton(
        icon: LucideIcons.circleUser,
        filled: true,
        onPressed: () => context.go(AppRoutes.profile),
      ),
    );
  }
}
