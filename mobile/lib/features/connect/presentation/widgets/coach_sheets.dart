import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../auth/presentation/providers/auth_state_notifier.dart';
import '../../domain/entities/connect_entities.dart';
import '../providers/connect_providers.dart';

/// Bottom sheets used by the Coach hub. Each one only calls an existing
/// [ConnectRepository] method and refreshes [myCaptainProvider].

void _toast(BuildContext context, String message) =>
    _toastOn(ScaffoldMessenger.of(context), message);

void _toastOn(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _showHubSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.achSheet,
    barrierColor: AppColors.achScrim,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.sheet)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: child,
    ),
  );
}

/// Grab handle + title row shared by the sheets.
class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: AppSpacing.xl + AppSpacing.xxs,
            height: AppSpacing.xxs,
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.achHandle,
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
          ),
        ),
        Text(
          title,
          style: AppTypography.headlineSmall.copyWith(
            color: AppColors.hubTextBright,
            fontWeight: AppTypography.bold,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle!,
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.hubTextMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// "SEND CHECK-IN": a short note to the Captain (coaching_feedback).
Future<void> showCheckInSheet(BuildContext context, CaptainOverview overview) {
  return _showHubSheet(context, _CheckInSheet(overview: overview));
}

class _CheckInSheet extends ConsumerStatefulWidget {
  const _CheckInSheet({required this.overview});

  final CaptainOverview overview;

  @override
  ConsumerState<_CheckInSheet> createState() => _CheckInSheetState();
}

class _CheckInSheetState extends ConsumerState<_CheckInSheet> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    final user = ref.read(authStateProvider).valueOrNull;
    if (body.isEmpty || user == null) return;
    setState(() => _sending = true);
    final result = await ref.read(connectRepositoryProvider).sendFeedback(
          relationshipId: widget.overview.relationship.id,
          authorId: user.id,
          body: body,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    result.when(
      success: (_) {
        final messenger = ScaffoldMessenger.of(context);
        ref.invalidate(myCaptainProvider);
        Navigator.of(context).pop();
        _toastOn(messenger, 'Check-in sent to ${widget.overview.coachName}');
      },
      failure: (f) => _toast(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(
            title: 'Check in',
            subtitle: 'Tell ${widget.overview.coachName} how training is going.',
          ),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            style: AppTypography.bodyLarge.copyWith(color: AppColors.hubTextBright),
            cursorColor: AppColors.hubEyebrow,
            decoration: InputDecoration(
              hintText: 'Hit 6 negatives today, grip felt better…',
              hintStyle:
                  AppTypography.bodyLarge.copyWith(color: AppColors.hubTextFaint),
              filled: true,
              fillColor: AppColors.authInputFill,
              counterStyle:
                  AppTypography.caption.copyWith(color: AppColors.hubTextFaint),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.hubCard),
                borderSide: const BorderSide(color: AppColors.authInputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.hubCard),
                borderSide: const BorderSide(color: AppColors.authInputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.hubCard),
                borderSide: const BorderSide(color: AppColors.hubRing),
              ),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          HubGradientButton(
            label: 'Send check-in',
            height: AppSpacing.xl2,
            isLoading: _sending,
            onPressed: _controller.text.trim().isEmpty ? null : _send,
          ),
        ],
      ),
    );
  }
}

/// "Manage" sharing: the athlete's consent scopes (coaching_permissions).
Future<void> showSharingSheet(BuildContext context, CaptainOverview overview) {
  return _showHubSheet(context, _SharingSheet(overview: overview));
}

class _SharingSheet extends ConsumerStatefulWidget {
  const _SharingSheet({required this.overview});

  final CaptainOverview overview;

  @override
  ConsumerState<_SharingSheet> createState() => _SharingSheetState();
}

class _SharingSheetState extends ConsumerState<_SharingSheet> {
  late bool _workouts;
  late bool _prs;
  late bool _skills;
  late bool _body;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.overview.permissions;
    // Database defaults when no row is visible yet.
    _workouts = p?.shareWorkouts ?? true;
    _prs = p?.sharePrs ?? true;
    _skills = p?.shareSkillProgress ?? true;
    _body = p?.shareBodyMetrics ?? false;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final result = await ref.read(connectRepositoryProvider).updatePermissions(
          widget.overview.relationship.id,
          shareWorkouts: _workouts,
          sharePrs: _prs,
          shareSkillProgress: _skills,
          shareBodyMetrics: _body,
        );
    if (!mounted) return;
    setState(() => _saving = false);
    result.when(
      success: (_) {
        final messenger = ScaffoldMessenger.of(context);
        ref.invalidate(myCaptainProvider);
        Navigator.of(context).pop();
        _toastOn(messenger, 'Sharing updated');
      },
      failure: (f) => _toast(context, f.message),
    );
  }

  Widget _row(String title, String subtitle, bool value, ValueChanged<bool> on) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: _saving ? null : on,
      activeTrackColor: AppColors.hubRing,
      title: Text(
        title,
        style: AppTypography.titleSmall.copyWith(color: AppColors.hubTextBright),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall.copyWith(color: AppColors.hubTextMuted),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SheetHeader(
            title: 'What ${widget.overview.coachName} can see',
            subtitle: 'Your Coach can add feedback and assign programs. '
                'Your logged workouts stay yours.',
          ),
          _row('Workout logs', 'Sessions, sets and reps', _workouts,
              (v) => setState(() => _workouts = v)),
          _row('Personal records', 'Your best lifts and holds', _prs,
              (v) => setState(() => _prs = v)),
          _row('Roadmap progress', 'Skills, stars and certifications', _skills,
              (v) => setState(() => _skills = v)),
          _row('Body stats', 'Height, weight, age', _body,
              (v) => setState(() => _body = v)),
          const SizedBox(height: AppSpacing.md),
          HubGradientButton(
            label: 'Save sharing',
            height: AppSpacing.xl2,
            isLoading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

/// Labels for the share chips and the Captain profile's "can see" list.
List<(String, bool)> shareScopes(CoachingPermissions? p) => [
      ('Workout logs', p?.shareWorkouts ?? true),
      ('Personal records', p?.sharePrs ?? true),
      ('Roadmap', p?.shareSkillProgress ?? true),
      ('Body stats', p?.shareBodyMetrics ?? false),
    ];
