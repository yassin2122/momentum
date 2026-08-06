import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_scaffold.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/section_title.dart';

class WorkoutsScreen extends StatelessWidget {
  const WorkoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      extendBodyBehindNav: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: AppSpacing.lg),
          SectionTitle(
            title: 'Workouts',
            subtitle: 'Plans and templates for your training',
          ),
          EmptyState(
            icon: LucideIcons.clipboardList,
            title: 'No workout plans yet',
            message:
                'Create your first plan to start tracking sets, reps, and weight.',
            actionLabel: 'Create Workout',
            // Disabled per this sprint's scope — Workout Plans isn't
            // implemented yet, this button is a layout placeholder only.
            onAction: null,
          ),
        ],
      ),
    );
  }
}
