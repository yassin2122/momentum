import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../../core/widgets/network_photo.dart';
import '../../domain/entities/gym_entities.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_ui.dart';

/// A gym's public page. Everything shown is what the gym entered; prices
/// are the gym's own and joining happens with the gym, not through Grit.
class GymDetailScreen extends ConsumerStatefulWidget {
  const GymDetailScreen({required this.gymId, super.key});

  final String gymId;

  @override
  ConsumerState<GymDetailScreen> createState() => _GymDetailScreenState();
}

class _GymDetailScreenState extends ConsumerState<GymDetailScreen> {
  String? _branchId;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(gymPublicProvider(widget.gymId));
    return async.when(
      loading: () => const HubPage(bottomPadding: AppSpacing.xl2, children: [
        SizedBox(height: AppSpacing.xl4),
        HubLoading(),
      ]),
      error: (e, _) => HubPage(bottomPadding: AppSpacing.xl2, children: [
        GymTitleBar(title: 'Gym', onBack: () => context.pop()),
        const SizedBox(height: AppSpacing.md),
        HubMessageCard(
          icon: LucideIcons.circleAlert,
          title: "Couldn't open this gym",
          message: gymErrorMessage(e),
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(gymPublicProvider(widget.gymId)),
        ),
      ]),
      data: (gym) => _build(context, gym),
    );
  }

  Widget _build(BuildContext context, GymPublicDetail gym) {
    final p = gym.profile;
    final branches = gym.branches;
    final branch = branches.isEmpty
        ? null
        : branches.firstWhere((b) => b.id == _branchId,
            orElse: () => branches.first);
    final offers = branch == null
        ? gym.offers
        : gym.offers.where((o) => o.appliesTo(branch.id)).toList();
    final phone = branch?.phone ?? p.phone;
    final location = [
      if (p.area != null && p.area!.isNotEmpty) p.area!,
      if (p.city != null && p.city!.isNotEmpty) p.city!,
    ].join(', ');

    return HubPage(
      bottomPadding: AppSizing.buttonHeight + AppSpacing.xl4,
      bottomBar: Row(
        children: [
          if (phone != null && phone.isNotEmpty) ...[
            SizedBox(
              width: AppSizing.buttonHeight + AppSpacing.xl,
              child: HubOutlineButton(
                label: 'Call',
                height: AppSizing.buttonHeight,
                onPressed: () => _copyPhone(context, phone),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: HubGradientButton(
              label: 'Ask about joining',
              icon: LucideIcons.messageCircle,
              height: AppSizing.buttonHeight,
              onPressed: () => _ask(context, gym, branch),
            ),
          ),
        ],
      ),
      children: [
        Stack(
          children: [
            GymCover(
              url: p.coverUrl,
              height: 190,
              radius: BorderRadius.circular(AppRadius.hubHero),
            ),
            Positioned(
              top: AppSpacing.xs,
              left: AppSpacing.xs,
              child: HubBackButton(onPressed: () => context.pop()),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GymLogo(name: p.name, url: p.logoUrl, size: 56),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(p.name,
                        style: AppTypography.headlineMedium.copyWith(
                          color: AppColors.hubTextBright,
                          fontWeight: AppTypography.bold,
                        )),
                    if (location.isNotEmpty)
                      Text(location,
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.hubTextMuted)),
                    if (p.headline != null && p.headline!.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(p.headline!,
                          style: AppTypography.bodyMedium
                              .copyWith(color: AppColors.hubTextBody)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        if (branches.length > 1) ...[
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: AppSizing.minTouchTarget - 8,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: branches.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, i) => GymChoiceChip(
                label: branches[i].name,
                selected: branches[i].id == branch?.id,
                onTap: () => setState(() => _branchId = branches[i].id),
              ),
            ),
          ),
        ],
        if (branch != null) ...[
          const SizedBox(height: AppSpacing.md),
          GymSection(
            header: branches.length > 1 ? branch.name : 'Location & hours',
            children: [
              GymRow(
                icon: LucideIcons.mapPin,
                title: branch.addressLabel,
                showChevron: false,
              ),
              GymRow(
                icon: LucideIcons.clock,
                title: branch.hoursLabel,
                subtitle: branch.hoursNote,
                showChevron: false,
              ),
              if (branch.phone != null && branch.phone!.isNotEmpty)
                GymRow(
                  icon: LucideIcons.phone,
                  title: branch.phone!,
                  trailing: const Icon(LucideIcons.copy,
                      size: AppSizing.iconSm, color: AppColors.hubTextFaint),
                  onTap: () => _copyPhone(context, branch.phone!),
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        GymSection(
          header: 'Offers',
          footer: 'Prices are set by the gym. You join and pay at the gym — '
              'Grit doesn\'t handle memberships or payments.',
          children: offers.isEmpty
              ? [
                  const GymRow(
                    title: 'No public offers',
                    subtitle: 'Ask the gym about current prices.',
                    showChevron: false,
                  ),
                ]
              : [
                  for (final o in offers)
                    GymRow(
                      title: o.name,
                      subtitle: [
                        if (o.durationText.isNotEmpty) o.durationText,
                        if (o.benefits.isNotEmpty) o.benefits.join(' · '),
                      ].join('  ·  '),
                      value: o.priceAmount == null
                          ? 'Ask the gym'
                          : gymPrice(o.priceAmount!, o.currency),
                      onTap: () => _ask(context, gym, branch, offer: o),
                      showChevron: true,
                    ),
                ],
        ),
        if (p.description != null && p.description!.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          GymSection(header: 'About', children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(p.description!,
                  style: AppTypography.bodyMedium
                      .copyWith(color: AppColors.hubTextBody, height: 1.45)),
            ),
          ]),
        ],
        if (gym.photos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _Gallery(photos: gym.photos),
        ],
        if ((branch?.facilities ?? p.facilities).isNotEmpty ||
            p.services.isNotEmpty ||
            p.equipment.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          _TagGroup(
              title: 'Facilities',
              tags: branch != null && branch.facilities.isNotEmpty
                  ? branch.facilities
                  : p.facilities),
          _TagGroup(title: 'Services', tags: p.services),
          _TagGroup(title: 'Equipment', tags: p.equipment),
        ],
        if (gym.coaches.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          GymSection(
            header: 'Coaches at ${p.name}',
            children: [
              for (final c in gym.coaches)
                GymRow(
                  leading: HubAvatar(name: c.name, imageUrl: c.avatarUrl, size: 36),
                  title: c.name,
                  subtitle: c.headline ?? c.role.label,
                  value: c.role == GymCoachRole.headCoach ? 'Head coach' : null,
                  onTap: () =>
                      context.push(AppRoutes.captainProfilePath(c.coachId)),
                ),
            ],
          ),
        ],
        if ((p.website != null && p.website!.isNotEmpty) ||
            (p.email != null && p.email!.isNotEmpty)) ...[
          const SizedBox(height: AppSpacing.lg),
          GymSection(header: 'Contact', children: [
            if (p.email != null && p.email!.isNotEmpty)
              GymRow(
                icon: LucideIcons.mail,
                title: p.email!,
                trailing: const Icon(LucideIcons.copy,
                    size: AppSizing.iconSm, color: AppColors.hubTextFaint),
                onTap: () => _copy(context, p.email!, 'Email copied'),
              ),
            if (p.website != null && p.website!.isNotEmpty)
              GymRow(
                icon: LucideIcons.globe,
                title: p.website!,
                trailing: const Icon(LucideIcons.copy,
                    size: AppSizing.iconSm, color: AppColors.hubTextFaint),
                onTap: () => _copy(context, p.website!, 'Link copied'),
              ),
          ]),
        ],
      ],
    );
  }

  void _copyPhone(BuildContext context, String phone) =>
      _copy(context, phone, 'Number copied — paste it into your phone app');

  void _copy(BuildContext context, String text, String toast) {
    Clipboard.setData(ClipboardData(text: text));
    HapticFeedback.lightImpact();
    gymToast(context, toast);
  }

  Future<void> _ask(BuildContext context, GymPublicDetail gym, GymBranch? branch,
      {GymOffer? offer}) async {
    if (!ref.read(gymAccountProvider)) {
      gymToast(context, 'Create a Grit account to message gyms.');
      return;
    }
    final sent = await showGymSheet<GymContactMethod>(
      context,
      InquirySheet(gym: gym, branch: branch, offer: offer),
    );
    if (sent != null && context.mounted) {
      final how = switch (sent) {
        GymContactMethod.whatsapp => 'Their team will contact you on WhatsApp.',
        GymContactMethod.call => 'Their team will call you.',
        GymContactMethod.inApp => 'Their team will get back to you.',
      };
      await showGymSuccess(
        context,
        title: 'Sent to ${gym.profile.name}',
        message: '$how Joining and payment happen directly with the gym.',
      );
    }
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({required this.title, required this.tags});

  final String title;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: AppSpacing.md, bottom: AppSpacing.xs),
            child: Text(title.toUpperCase(),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.hubTextMuted,
                  letterSpacing: 0.6,
                  fontWeight: AppTypography.semiBold,
                )),
          ),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final t in tags)
                HubPill(
                  label: t,
                  fill: AppColors.hubIconButton,
                  textColor: AppColors.hubTextBody,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Gallery extends StatelessWidget {
  const _Gallery({required this.photos});

  final List<GymPhoto> photos;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 132,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: photos.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.xs),
        itemBuilder: (context, i) => GestureDetector(
          onTap: () => _open(context, i),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.hubCard),
            child: SizedBox(
              width: 176,
              child: NetworkPhoto(
                url: photos[i].url,
                cacheWidth: 528,
                placeholder: const ColoredBox(color: AppColors.hubCardBottom),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, int index) {
    showDialog<void>(
      context: context,
      barrierColor: AppColors.achScrim,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: PageView.builder(
          controller: PageController(initialPage: index),
          itemCount: photos.length,
          itemBuilder: (context, i) => InteractiveViewer(
            child: Center(
              child: NetworkPhoto(
                url: photos[i].url,
                fit: BoxFit.contain,
                placeholder: const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Ask about joining" — the only data the gym receives is what the
/// visitor types here.
class InquirySheet extends ConsumerStatefulWidget {
  const InquirySheet({required this.gym, this.branch, this.offer, super.key});

  final GymPublicDetail gym;
  final GymBranch? branch;
  final GymOffer? offer;

  @override
  ConsumerState<InquirySheet> createState() => _InquirySheetState();
}

class _InquirySheetState extends ConsumerState<InquirySheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();
  GymContactMethod _method = GymContactMethod.whatsapp;
  String? _nameError;
  String? _phoneError;
  bool _sending = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    setState(() {
      _nameError = name.length < 2 ? 'Add your name' : null;
      _phoneError = _method != GymContactMethod.inApp &&
              phone.replaceAll(RegExp(r'[^0-9]'), '').length < 8
          ? 'Add a number the gym can reach'
          : null;
    });
    if (_nameError != null || _phoneError != null) return;
    setState(() => _sending = true);
    final result = await ref.read(gymRepositoryProvider).submitInquiry(
          gymId: widget.gym.profile.id,
          name: name,
          contactMethod: _method,
          phone: phone.isEmpty ? null : phone,
          message: _message.text.trim().isEmpty ? null : _message.text.trim(),
          branchId: widget.branch?.id,
          offerId: widget.offer?.id,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    result.when(
      success: (_) => Navigator.of(context).pop(_method),
      failure: (f) => gymToast(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final about = [
      if (widget.branch != null && widget.gym.branches.length > 1)
        widget.branch!.name,
      if (widget.offer != null) widget.offer!.name,
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GymSheetHeader(
          title: 'Ask ${widget.gym.profile.name}',
          subtitle: about.isEmpty ? 'About joining' : 'About $about',
        ),
        GymTextField(
          label: 'Your name',
          controller: _name,
          error: _nameError,
          textCapitalization: TextCapitalization.words,
          maxLength: 80,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('How should they reach you?',
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.hubTextBody,
              fontWeight: AppTypography.semiBold,
            )),
        const SizedBox(height: AppSpacing.xs),
        GymSegmented<GymContactMethod>(
          options: [for (final m in GymContactMethod.values) (m, m.label)],
          value: _method,
          onChanged: (m) => setState(() => _method = m),
        ),
        const SizedBox(height: AppSpacing.md),
        GymTextField(
          label: 'Phone',
          controller: _phone,
          error: _phoneError,
          optional: _method == GymContactMethod.inApp,
          keyboardType: TextInputType.phone,
          textCapitalization: TextCapitalization.none,
          maxLength: 20,
        ),
        const SizedBox(height: AppSpacing.sm),
        GymTextField(
          label: 'Message',
          controller: _message,
          optional: true,
          hint: 'Times you train, questions about the offer…',
          maxLines: 4,
          minLines: 2,
          maxLength: 500,
        ),
        const SizedBox(height: AppSpacing.sm),
        const GymNote(
          'The gym sees your name, contact and message — nothing from your '
          'workouts. Joining and payment happen directly with the gym.',
          icon: LucideIcons.lock,
        ),
        const SizedBox(height: AppSpacing.md),
        HubGradientButton(
          label: 'Send',
          height: AppSizing.buttonHeight,
          isLoading: _sending,
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
