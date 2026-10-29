import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../domain/entities/gym_entities.dart';
import '../providers/gym_providers.dart';
import '../widgets/gym_ui.dart';

/// Inquiries: people who tapped "Ask about joining". Staff follow up
/// outside Grit (call / WhatsApp) and move each one New → Contacted → Closed.
class GymInquiriesTab extends ConsumerStatefulWidget {
  const GymInquiriesTab({required this.gymId, super.key});

  final String gymId;

  @override
  ConsumerState<GymInquiriesTab> createState() => _GymInquiriesTabState();
}

class _GymInquiriesTabState extends ConsumerState<GymInquiriesTab> {
  GymInquiryStatus _filter = GymInquiryStatus.fresh;
  final _busy = <String>{};

  Future<void> _move(GymInquiry i, GymInquiryStatus to) async {
    setState(() => _busy.add(i.id));
    final r = await ref.read(gymRepositoryProvider).setInquiryStatus(i.id, to);
    if (!mounted) return;
    setState(() => _busy.remove(i.id));
    r.when(
      success: (_) {
        HapticFeedback.lightImpact();
        ref
          ..invalidate(gymInquiriesProvider(widget.gymId))
          ..invalidate(gymOverviewProvider(widget.gymId));
      },
      failure: (f) => gymToast(context, f.message),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(gymInquiriesProvider(widget.gymId));
    final detail = ref.watch(gymAdminDetailProvider(widget.gymId)).valueOrNull;
    String? branchName(String? id) => id == null
        ? null
        : detail?.branches.where((b) => b.id == id).map((b) => b.name).firstOrNull;
    String? offerName(String? id) => id == null
        ? null
        : detail?.offers.where((o) => o.id == id).map((o) => o.name).firstOrNull;

    return RefreshIndicator(
      color: AppColors.hubEyebrow,
      onRefresh: () async => ref.invalidate(gymInquiriesProvider(widget.gymId)),
      child: HubPage(
        bottomPadding: AppSpacing.xl3,
        children: [
          const GymTitleBar(title: 'Inquiries'),
          const SizedBox(height: AppSpacing.md),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xl3),
              child: HubLoading(),
            ),
            error: (e, _) => HubMessageCard(
              icon: LucideIcons.circleAlert,
              title: "Couldn't load inquiries",
              message: gymErrorMessage(e),
              actionLabel: 'Try again',
              onAction: () => ref.invalidate(gymInquiriesProvider(widget.gymId)),
            ),
            data: (all) {
              int count(GymInquiryStatus s) => all.where((i) => i.status == s).length;
              final list = all.where((i) => i.status == _filter).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GymSegmented<GymInquiryStatus>(
                    options: [
                      for (final s in GymInquiryStatus.values)
                        (s, count(s) > 0 ? '${s.label} ${count(s)}' : s.label),
                    ],
                    value: _filter,
                    onChanged: (s) => setState(() => _filter = s),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  if (list.isEmpty)
                    HubMessageCard(
                      icon: LucideIcons.inbox,
                      title: switch (_filter) {
                        GymInquiryStatus.fresh => 'No new inquiries',
                        GymInquiryStatus.contacted => 'Nothing waiting',
                        GymInquiryStatus.closed => 'Nothing closed yet',
                      },
                      message: _filter == GymInquiryStatus.fresh
                          ? 'When someone taps "Ask about joining" on your page, '
                              'it lands here.'
                          : 'Inquiries move here as your team follows up.',
                    )
                  else
                    for (final i in list) ...[
                      _InquiryCard(
                        inquiry: i,
                        branch: branchName(i.branchId),
                        offer: offerName(i.offerId),
                        busy: _busy.contains(i.id),
                        onMove: (to) => _move(i, to),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InquiryCard extends StatelessWidget {
  const _InquiryCard({
    required this.inquiry,
    required this.busy,
    required this.onMove,
    this.branch,
    this.offer,
  });

  final GymInquiry inquiry;
  final String? branch;
  final String? offer;
  final bool busy;
  final ValueChanged<GymInquiryStatus> onMove;

  @override
  Widget build(BuildContext context) {
    final i = inquiry;
    final about = [if (branch != null) branch!, if (offer != null) offer!].join(' · ');
    final nextLabel = switch (i.status) {
      GymInquiryStatus.fresh => 'Mark contacted',
      GymInquiryStatus.contacted => 'Close',
      GymInquiryStatus.closed => 'Reopen',
    };
    return HubCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              HubAvatar(name: i.name, size: 36),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(i.name,
                        style: AppTypography.bodyLarge.copyWith(
                          color: AppColors.hubTextBright,
                          fontWeight: AppTypography.semiBold,
                        )),
                    Text(
                      'Prefers ${i.contactMethod.label} · ${gymRelativeTime(i.createdAt)}',
                      style:
                          AppTypography.labelMedium.copyWith(color: AppColors.hubTextMuted),
                    ),
                  ],
                ),
              ),
              if (i.status == GymInquiryStatus.fresh)
                const GymStatusPill('New', tone: GymTone.caution),
            ],
          ),
          if (about.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(about,
                style: AppTypography.labelLarge.copyWith(color: AppColors.hubChipText)),
          ],
          if (i.message != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(i.message!,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody)),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (i.phone != null)
                Expanded(
                  child: HubOutlineButton(
                    label: i.phone!,
                    height: AppSizing.minTouchTarget,
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: i.phone!));
                      HapticFeedback.lightImpact();
                      gymToast(context, 'Number copied');
                    },
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: busy
                    ? const Center(
                        child: SizedBox(
                          width: AppSizing.iconMd,
                          height: AppSizing.iconMd,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.hubEyebrow),
                        ),
                      )
                    : HubGradientButton(
                        label: nextLabel,
                        height: AppSizing.minTouchTarget,
                        onPressed: () => onMove(i.status.next),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
