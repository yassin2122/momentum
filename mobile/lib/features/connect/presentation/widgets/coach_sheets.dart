import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../auth/presentation/providers/auth_state_notifier.dart';
import '../../domain/entities/connect_entities.dart';
import '../providers/connect_providers.dart';

/// Bottom sheets used by the Coach hub and the Captain Hub. Each one only
/// calls an existing [ConnectRepository] method and refreshes the provider
/// it changed ([myCaptainProvider] or [captainHubProvider]).

void _toast(BuildContext context, String message) =>
    _toastOn(ScaffoldMessenger.of(context), message);

void _toastOn(ScaffoldMessengerState messenger, String message) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _showHubSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    useRootNavigator: true,
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

// ---------------------------------------------------------------------------
// Shared input styling
// ---------------------------------------------------------------------------

/// Text-field decoration used by the Connect sheets and the Captain profile
/// editor — same look as the check-in field.
InputDecoration hubInputDecoration({String? hint, String? label}) {
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.hubCard),
        borderSide: BorderSide(color: color),
      );
  return InputDecoration(
    hintText: hint,
    labelText: label,
    hintStyle: AppTypography.bodyLarge.copyWith(color: AppColors.hubTextFaint),
    labelStyle: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextMuted),
    floatingLabelStyle:
        AppTypography.bodyMedium.copyWith(color: AppColors.hubEyebrow),
    filled: true,
    fillColor: AppColors.authInputFill,
    counterStyle: AppTypography.caption.copyWith(color: AppColors.hubTextFaint),
    border: border(AppColors.authInputBorder),
    enabledBorder: border(AppColors.authInputBorder),
    focusedBorder: border(AppColors.hubRing),
    errorBorder: border(AppColors.hubDanger),
    focusedErrorBorder: border(AppColors.hubDanger),
  );
}

// ---------------------------------------------------------------------------
// Captain: create an invite
// ---------------------------------------------------------------------------

/// Captain Hub → "Invite a client". Creates a single-use code with
/// `create_coaching_invitation` and shows it once, ready to copy.
Future<void> showCreateInviteSheet(BuildContext context) {
  return _showHubSheet(context, const _CreateInviteSheet());
}

class _CreateInviteSheet extends ConsumerStatefulWidget {
  const _CreateInviteSheet();

  @override
  ConsumerState<_CreateInviteSheet> createState() => _CreateInviteSheetState();
}

class _CreateInviteSheetState extends ConsumerState<_CreateInviteSheet> {
  static const _validityOptions = [3, 7, 14];

  final _note = TextEditingController();
  int _days = 7;
  bool _creating = false;
  CreatedInvite? _created;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    setState(() => _creating = true);
    final note = _note.text.trim();
    final result = await ref.read(connectRepositoryProvider).createInvite(
          note: note.isEmpty ? null : note,
          validDays: _days,
        );
    if (!mounted) return;
    setState(() => _creating = false);
    result.when(
      success: (invite) {
        ref.invalidate(captainHubProvider);
        setState(() => _created = invite);
      },
      failure: (f) => _toast(context, f.message),
    );
  }

  Future<void> _copy(String text, String confirmation) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) _toast(context, confirmation);
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
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
        children: created == null ? _form() : _result(created),
      ),
    );
  }

  List<Widget> _form() => [
        const _SheetHeader(
          title: 'Invite a client',
          subtitle: 'They enter this code in Coach → "Have an invite code?". '
              'One code works for one athlete.',
        ),
        TextField(
          controller: _note,
          maxLength: 80,
          textCapitalization: TextCapitalization.sentences,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.hubTextBright),
          cursorColor: AppColors.hubEyebrow,
          decoration: hubInputDecoration(
            label: 'Who is it for? (optional)',
            hint: 'Ahmed — Tuesday group',
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        const HubEyebrow('Valid for'),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            for (final d in _validityOptions)
              ChoiceChip(
                label: Text('$d days'),
                selected: _days == d,
                onSelected: _creating ? null : (_) => setState(() => _days = d),
                selectedColor: AppColors.hubShareOnFill,
                backgroundColor: AppColors.hubTrack,
                labelStyle: AppTypography.labelLarge.copyWith(
                  color: _days == d
                      ? AppColors.hubShareOnText
                      : AppColors.hubTextBody,
                ),
                showCheckmark: false,
                side: BorderSide.none,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        HubGradientButton(
          label: 'Create invite code',
          height: AppSpacing.xl2,
          isLoading: _creating,
          onPressed: _create,
        ),
      ];

  List<Widget> _result(CreatedInvite invite) {
    final expires = DateFormat('MMM d').format(invite.expiresAt.toLocal());
    final message = 'Join me on Grit — I\'ll be your Captain. Open the Coach '
        'tab, tap "Have an invite code?" and enter ${invite.code} '
        '(valid until $expires).';
    return [
      const _SheetHeader(
        title: 'Invite code ready',
        subtitle: 'Share it now — for security, Grit only shows the full '
            'code once.',
      ),
      Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.hubTrack,
          borderRadius: BorderRadius.circular(AppRadius.hubCard),
        ),
        child: Column(
          children: [
            SelectableText(
              invite.code,
              textAlign: TextAlign.center,
              style: AppTypography.numeric(AppTypography.headlineLarge).copyWith(
                color: AppColors.hubTextBright,
                fontWeight: AppTypography.bold,
                letterSpacing: 3,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'Single use · valid until $expires',
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.hubTextMuted),
            ),
          ],
        ),
      ),
      const SizedBox(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: HubOutlineButton(
              label: 'Copy code',
              onPressed: () => _copy(invite.code, 'Code copied'),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: HubGradientButton(
              label: 'Copy message',
              onPressed: () => _copy(message, 'Invite message copied'),
            ),
          ),
        ],
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// Athlete: redeem an invite
// ---------------------------------------------------------------------------

/// Coach tab → "Have an invite code?". Shows who sent the code
/// (`preview_coaching_invitation`), lets the athlete pick what to share,
/// then `accept_coaching_invitation` starts an active relationship.
Future<void> showRedeemInviteSheet(BuildContext context) {
  return _showHubSheet(context, const _RedeemInviteSheet());
}

class _RedeemInviteSheet extends ConsumerStatefulWidget {
  const _RedeemInviteSheet();

  @override
  ConsumerState<_RedeemInviteSheet> createState() => _RedeemInviteSheetState();
}

class _RedeemInviteSheetState extends ConsumerState<_RedeemInviteSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  InvitePreview? _preview;
  String? _error;

  // Database defaults: body stats stay private.
  bool _workouts = true;
  bool _prs = true;
  bool _skills = true;
  bool _body = false;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _lookUp() async {
    final code = _code.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(connectRepositoryProvider).previewInvite(code);
    if (!mounted) return;
    setState(() {
      _busy = false;
      result.when(
        success: (p) => _preview = p,
        failure: (f) => _error = f.message,
      );
    });
  }

  Future<void> _accept() async {
    setState(() => _busy = true);
    final result = await ref.read(connectRepositoryProvider).acceptInvite(
          _code.text.trim(),
          shareWorkouts: _workouts,
          sharePrs: _prs,
          shareSkillProgress: _skills,
          shareBodyMetrics: _body,
        );
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (_) {
        final messenger = ScaffoldMessenger.of(context);
        ref.invalidate(myCaptainProvider);
        Navigator.of(context).pop();
        _toastOn(messenger, '${_preview?.name ?? 'Your Coach'} is now your Coach');
      },
      failure: (f) => _toast(context, f.message),
    );
  }

  Widget _switch(String title, String subtitle, bool value, ValueChanged<bool> on) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: _busy ? null : on,
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
    final preview = _preview;
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
        children: preview == null ? _codeStep() : _confirmStep(preview),
      ),
    );
  }

  List<Widget> _codeStep() => [
        const _SheetHeader(
          title: 'Enter invite code',
          subtitle: 'Your Captain shares a 10-character code with you.',
        ),
        TextField(
          controller: _code,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _lookUp(),
          onChanged: (_) => setState(() => _error = null),
          style: AppTypography.numeric(AppTypography.titleLarge).copyWith(
            color: AppColors.hubTextBright,
            letterSpacing: 2,
          ),
          cursorColor: AppColors.hubEyebrow,
          decoration: hubInputDecoration(hint: 'XXXXX-XXXXX').copyWith(
            errorText: _error,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        HubGradientButton(
          label: 'Continue',
          height: AppSpacing.xl2,
          isLoading: _busy,
          onPressed: _code.text.trim().isEmpty ? null : _lookUp,
        ),
      ];

  List<Widget> _confirmStep(InvitePreview p) => [
        const _SheetHeader(title: 'Coaching invite'),
        Row(
          children: [
            HubAvatar(name: p.name, imageUrl: p.avatarUrl, size: 52),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: AppTypography.titleLarge.copyWith(
                      color: AppColors.hubTextBright,
                      fontWeight: AppTypography.bold,
                    ),
                  ),
                  Text(
                    p.headline?.isNotEmpty ?? false
                        ? p.headline!
                        : p.specialties.isNotEmpty
                            ? p.specialties.join(' · ')
                            : 'Approved coach',
                    style: AppTypography.labelLarge
                        .copyWith(color: AppColors.hubTextBody),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          '${p.name} invited you to train with them. Choose what they can '
          'see — you can change it any time.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
        ),
        const SizedBox(height: AppSpacing.xs),
        _switch('Workout logs', 'Sessions, sets and reps', _workouts,
            (v) => setState(() => _workouts = v)),
        _switch('Personal records', 'Your best lifts and holds', _prs,
            (v) => setState(() => _prs = v)),
        _switch('Roadmap progress', 'Skills, stars and certifications', _skills,
            (v) => setState(() => _skills = v)),
        _switch('Body stats', 'Height, weight, age', _body,
            (v) => setState(() => _body = v)),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: HubOutlineButton(
                label: 'Decline',
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: HubGradientButton(
                label: 'Accept',
                isLoading: _busy,
                onPressed: _accept,
              ),
            ),
          ],
        ),
      ];
}

// ---------------------------------------------------------------------------
// Captain: write feedback for an athlete
// ---------------------------------------------------------------------------

/// Captain → client → "Write feedback" (optionally on one workout).
/// Inserts into the append-only `coaching_feedback`.
Future<void> showCoachFeedbackSheet(
  BuildContext context, {
  required String relationshipId,
  required String athleteName,
  String? workoutLogId,
  String? workoutLabel,
}) {
  return _showHubSheet(
    context,
    _CoachFeedbackSheet(
      relationshipId: relationshipId,
      athleteName: athleteName,
      workoutLogId: workoutLogId,
      workoutLabel: workoutLabel,
    ),
  );
}

class _CoachFeedbackSheet extends ConsumerStatefulWidget {
  const _CoachFeedbackSheet({
    required this.relationshipId,
    required this.athleteName,
    this.workoutLogId,
    this.workoutLabel,
  });

  final String relationshipId;
  final String athleteName;
  final String? workoutLogId;
  final String? workoutLabel;

  @override
  ConsumerState<_CoachFeedbackSheet> createState() =>
      _CoachFeedbackSheetState();
}

class _CoachFeedbackSheetState extends ConsumerState<_CoachFeedbackSheet> {
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
          relationshipId: widget.relationshipId,
          authorId: user.id,
          body: body,
          workoutLogId: widget.workoutLogId,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    result.when(
      success: (_) {
        final messenger = ScaffoldMessenger.of(context);
        ref.invalidate(relationshipFeedbackProvider(widget.relationshipId));
        Navigator.of(context).pop();
        _toastOn(messenger, 'Feedback sent to ${widget.athleteName}');
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
            title: 'Feedback for ${widget.athleteName}',
            subtitle: widget.workoutLabel != null
                ? 'On ${widget.workoutLabel}'
                : 'They\'ll see it in their Coach tab.',
          ),
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            maxLength: 1000,
            textCapitalization: TextCapitalization.sentences,
            style:
                AppTypography.bodyLarge.copyWith(color: AppColors.hubTextBright),
            cursorColor: AppColors.hubEyebrow,
            decoration: hubInputDecoration(
              hint: 'Great depth on the negatives — add one rep next session.',
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AppSpacing.sm),
          HubGradientButton(
            label: 'Send feedback',
            height: AppSpacing.xl2,
            isLoading: _sending,
            onPressed: _controller.text.trim().isEmpty ? null : _send,
          ),
        ],
      ),
    );
  }
}
