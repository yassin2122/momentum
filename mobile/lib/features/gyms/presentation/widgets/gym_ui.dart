import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../../core/widgets/network_photo.dart';

/// Shared building blocks for the gym screens.
///
/// They follow Apple's interface guidelines inside Grit's dark theme:
/// large titles, inset grouped sections with inset separators and
/// disclosure chevrons, segmented controls for 2–4 peer choices, sheets
/// with a grabber for focused tasks, 44 pt minimum hit targets, and
/// confirmation before anything destructive. Colors, type and spacing come
/// only from the core theme tokens.

/// Facilities a gym can tick. The same list drives filters and editors.
const kGymFacilities = <String>[
  'Free weights',
  'Machines',
  'Functional zone',
  'Cardio',
  'Group classes',
  'Personal training',
  'Sauna',
  'Pool',
  'Lockers',
  'Showers',
  'Parking',
  "Women's area",
  'Kids area',
  'Open 24 hours',
];

const kGymServices = <String>[
  'Personal training',
  'Group classes',
  'Body assessment',
  'Nutrition guidance',
  'Kids classes',
  'Physiotherapy',
];

// ---------------------------------------------------------------------------
// Feedback
// ---------------------------------------------------------------------------

void gymToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Confirmation dialog. [destructive] colors the confirm button red and
/// never makes it the default action.
Future<bool> confirmGymAction(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.surfaceElevated,
      title: Text(title, style: AppTypography.headlineSmall),
      content: Text(message, style: AppTypography.bodyMedium),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor:
                destructive ? AppColors.error : AppColors.accentProgress,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ---------------------------------------------------------------------------
// Page chrome
// ---------------------------------------------------------------------------

/// Large-title header: optional back button, eyebrow, title, trailing.
class GymTitleBar extends StatelessWidget {
  const GymTitleBar({
    required this.title,
    this.eyebrow,
    this.onBack,
    this.trailing,
    super.key,
  });

  final String title;
  final String? eyebrow;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            HubBackButton(onPressed: onBack!),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null) HubEyebrow(eyebrow!),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.headlineLarge
                      .copyWith(color: AppColors.hubTextBright),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// Inset grouped section: small header, rounded group, optional footer.
class GymSection extends StatelessWidget {
  const GymSection({
    required this.children,
    this.header,
    this.footer,
    this.trailing,
    super.key,
  });

  final String? header;
  final Widget? trailing;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(const Padding(
          padding: EdgeInsets.only(left: AppSpacing.md),
          child: Divider(height: 1, thickness: 1, color: AppColors.hubCardBorder),
        ));
      }
      rows.add(children[i]);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (header != null || trailing != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, 0, AppSpacing.xs, AppSpacing.xs),
            child: Row(
              children: [
                if (header != null)
                  Expanded(
                    child: Text(
                      header!.toUpperCase(),
                      style: AppTypography.labelSmall.copyWith(
                        color: AppColors.hubTextMuted,
                        letterSpacing: 0.6,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.hubCardTop, AppColors.hubCardBottom],
            ),
            borderRadius: BorderRadius.circular(AppRadius.hubHero),
            border: Border.all(color: AppColors.hubCardBorder),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.hubHero),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
            child: Text(
              footer!,
              style:
                  AppTypography.labelMedium.copyWith(color: AppColors.hubTextFaint),
            ),
          ),
      ],
    );
  }
}

/// One row inside a [GymSection]. Shows a chevron when it navigates.
class GymRow extends StatelessWidget {
  const GymRow({
    required this.title,
    this.subtitle,
    this.value,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.destructive = false,
    this.showChevron,
    super.key,
  });

  final String title;
  final String? subtitle;
  final String? value;
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructive;

  /// Defaults to true when [onTap] is set and there is no [trailing].
  final bool? showChevron;

  @override
  Widget build(BuildContext context) {
    final chevron = showChevron ?? (onTap != null && trailing == null);
    final titleColor = destructive ? AppColors.hubDanger : AppColors.hubTextBright;
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AppSizing.minTouchTarget + 6),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: AppSpacing.sm),
                ] else if (icon != null) ...[
                  Icon(icon,
                      size: AppSizing.iconSm + 2,
                      color: destructive ? AppColors.hubDanger : AppColors.hubEyebrow),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: AppTypography.bodyLarge.copyWith(color: titleColor),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: AppTypography.labelMedium
                                .copyWith(color: AppColors.hubTextMuted),
                          ),
                        ),
                    ],
                  ),
                ),
                if (value != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  Flexible(
                    child: Text(
                      value!,
                      textAlign: TextAlign.end,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyMedium
                          .copyWith(color: AppColors.hubTextMuted),
                    ),
                  ),
                ],
                if (trailing != null) ...[
                  const SizedBox(width: AppSpacing.xs),
                  trailing!,
                ],
                if (chevron) ...[
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(LucideIcons.chevronRight,
                      size: AppSizing.iconSm, color: AppColors.hubTextFaint),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A row with a platform switch (Cupertino-style on iOS).
class GymSwitchRow extends StatelessWidget {
  const GymSwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    super.key,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GymRow(
      title: title,
      subtitle: subtitle,
      onTap: onChanged == null ? null : () => onChanged!(!value),
      showChevron: false,
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeTrackColor: AppColors.accentProgress,
      ),
    );
  }
}

/// Segmented control for 2–4 peer options.
class GymSegmented<T> extends StatelessWidget {
  const GymSegmented({
    required this.options,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: AppSizing.minTouchTarget - 4,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.hubIconButton,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: AppColors.hubCardBorder),
      ),
      child: Row(
        children: [
          for (final (option, label) in options)
            Expanded(
              child: Semantics(
                selected: option == value,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (option == value) return;
                    HapticFeedback.selectionClick();
                    onChanged(option);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: option == value
                          ? AppColors.hubAvatarRing
                          : AppColors.transparent,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.labelLarge.copyWith(
                        color: option == value
                            ? AppColors.hubTextBright
                            : AppColors.hubTextMuted,
                        fontWeight: AppTypography.semiBold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Selectable pill (filters, facilities, branches).
class GymChoiceChip extends StatelessWidget {
  const GymChoiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: AppSizing.minTouchTarget - 8),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: selected ? AppColors.hubHeroGlow : AppColors.hubIconButton,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: Border.all(
              color: selected ? AppColors.hubRing : AppColors.hubCardBorderStrong,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(LucideIcons.check,
                    size: AppSizing.iconSm - 2, color: AppColors.hubChipText),
                const SizedBox(width: AppSpacing.xxs),
              ],
              Text(
                label,
                style: AppTypography.labelLarge.copyWith(
                  color: selected ? AppColors.hubTextBright : AppColors.hubTextBody,
                  fontWeight: AppTypography.semiBold,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: AppSpacing.xxs),
                Text(
                  '$count',
                  style: AppTypography.labelMedium.copyWith(
                    color: selected ? AppColors.hubSkyLight : AppColors.hubTextFaint,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A short filter row (Hick's Law): a "Filters" button plus the 2–3 most
/// used options. Everything else lives in the Filters sheet. A choice made
/// in the sheet also shows in the row, so the active filter is never hidden.
class GymFilterRow extends StatelessWidget {
  const GymFilterRow({
    required this.quick,
    required this.all,
    required this.selected,
    required this.onSelected,
    this.title = 'Filters',
    super.key,
  });

  final List<String> quick;
  final List<String> all;
  final String? selected;
  final ValueChanged<String?> onSelected;
  final String title;

  Future<void> _openSheet(BuildContext context) async {
    final picked = await showGymSheet<({String? value})>(
      context,
      Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GymSheetHeader(title: title),
            GymSection(
              children: [
                for (final o in [null, ...all])
                  GymRow(
                    title: o ?? 'All',
                    showChevron: false,
                    trailing: Icon(
                      selected == o ? LucideIcons.circleCheck : LucideIcons.circle,
                      size: AppSizing.iconSm + 2,
                      color: selected == o ? AppColors.hubEyebrow : AppColors.hubTextFaint,
                    ),
                    onTap: () => Navigator.of(context).pop((value: o)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked != null) onSelected(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final extra = selected != null && !quick.contains(selected) ? selected : null;
    return SizedBox(
      height: AppSizing.minTouchTarget - 8,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          GymChoiceChip(
            label: 'Filters',
            selected: extra != null,
            onTap: () => _openSheet(context),
          ),
          if (extra != null) ...[
            const SizedBox(width: AppSpacing.xs),
            GymChoiceChip(label: extra, selected: true, onTap: () => onSelected(null)),
          ],
          for (final q in quick) ...[
            const SizedBox(width: AppSpacing.xs),
            GymChoiceChip(
              label: q,
              selected: selected == q,
              onTap: () => onSelected(selected == q ? null : q),
            ),
          ],
        ],
      ),
    );
  }
}

enum GymTone { positive, caution, negative, neutral, info, partner }

class GymStatusPill extends StatelessWidget {
  const GymStatusPill(this.label, {this.tone = GymTone.neutral, super.key});

  final String label;
  final GymTone tone;

  @override
  Widget build(BuildContext context) {
    final (fill, text) = switch (tone) {
      GymTone.positive => (AppColors.hubShareOnFill, AppColors.hubShareOnText),
      GymTone.caution => (AppColors.hubWaitFill, AppColors.hubWaitText),
      GymTone.negative => (AppColors.errorContainer, AppColors.hubDanger),
      GymTone.neutral => (AppColors.hubShareOffFill, AppColors.hubTextMuted),
      GymTone.info => (AppColors.hubHeroGlow, AppColors.hubChipText),
      GymTone.partner => (AppColors.hubHeroGlow, AppColors.ctaGradientStart),
    };
    return HubPill(label: label, fill: fill, textColor: text);
  }
}

/// "Grit partner" badge for gyms with an active partnership.
class GymPartnerBadge extends StatelessWidget {
  const GymPartnerBadge({super.key});

  @override
  Widget build(BuildContext context) => const HubPill(
        label: 'Grit partner',
        icon: LucideIcons.shieldCheck,
        fill: AppColors.hubHeroGlow,
        textColor: AppColors.hubChipText,
      );
}

// ---------------------------------------------------------------------------
// Images
// ---------------------------------------------------------------------------

/// Rounded-square gym logo, initials when there's no image.
class GymLogo extends StatelessWidget {
  const GymLogo({required this.name, this.url, this.size = 48, super.key});

  final String name;
  final String? url;
  final double size;

  String get _initials {
    final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty);
    return words.take(2).map((w) => w[0].toUpperCase()).join();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        _initials,
        style: AppTypography.titleMedium.copyWith(
          color: AppColors.ctaGradientStart,
          fontWeight: AppTypography.extraBold,
        ),
      ),
    );
    final u = url;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.hubCardBottom,
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: AppColors.ctaGradientStart, width: 2),
      ),
      child: u == null
          ? fallback
          : NetworkPhoto(
              url: u,
              cacheWidth: (size * 3).round(),
              placeholder: fallback,
            ),
    );
  }
}

/// Cover image with a quiet gradient when there's none yet.
class GymCover extends StatelessWidget {
  const GymCover({this.url, this.height = 140, this.radius, super.key});

  final String? url;
  final double height;
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    const placeholder = DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment(0.7, -0.6),
          radius: 1.2,
          colors: [AppColors.hubHeroGlow, AppColors.hubHeroEdge],
        ),
      ),
      child: Center(
        child: Icon(LucideIcons.dumbbell,
            size: AppSizing.iconLg, color: AppColors.hubTextFaint),
      ),
    );
    final u = url;
    return ClipRRect(
      borderRadius: radius ?? BorderRadius.zero,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: u == null
            ? placeholder
            : NetworkPhoto(url: u, placeholder: placeholder, cacheWidth: 1200),
      ),
    );
  }
}

/// A picked, validated image ready to upload.
typedef GymPickedImage = ({Uint8List bytes, String contentType});

/// Opens the photo library and checks the image is JPG/PNG/WebP, at most
/// 8 MB, and at least [minWidth] × [minHeight] px. Returns null if cancelled;
/// throws [GymImageError] with a readable message if it doesn't fit.
Future<GymPickedImage?> pickGymImage({
  required int minWidth,
  required int minHeight,
}) async {
  final XFile? file;
  try {
    file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      maxHeight: 2400,
      imageQuality: 85,
      requestFullMetadata: false,
    );
  } catch (_) {
    throw const GymImageError(
        "Couldn't open your photos. Check Grit's photo permission.");
  }
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  final name = file.name.toLowerCase();
  final contentType = name.endsWith('.png')
      ? 'image/png'
      : name.endsWith('.webp')
          ? 'image/webp'
          : (name.endsWith('.jpg') || name.endsWith('.jpeg'))
              ? 'image/jpeg'
              : null;
  if (contentType == null) {
    throw const GymImageError('Use a JPG, PNG or WebP photo.');
  }
  if (bytes.lengthInBytes > 8 * 1024 * 1024) {
    throw const GymImageError('That photo is over 8 MB. Pick a smaller one.');
  }
  final ui.Image image;
  try {
    image = await decodeImageFromList(bytes);
  } catch (_) {
    throw const GymImageError("That file isn't a readable photo.");
  }
  final w = image.width;
  final h = image.height;
  image.dispose();
  if (w < minWidth || h < minHeight) {
    throw GymImageError(
        'That photo is $w × $h px. Use one at least $minWidth × $minHeight px.');
  }
  return (bytes: bytes, contentType: contentType);
}

final class GymImageError implements Exception {
  const GymImageError(this.message);
  final String message;
}

// ---------------------------------------------------------------------------
// Forms and sheets
// ---------------------------------------------------------------------------

/// Arabic-Indic (٠-٩) and Persian (۰-۹) digits, the Arabic decimal and
/// thousands marks → ASCII. Many people in Egypt type numbers this way.
String gymNormalizeDigits(String input) {
  final out = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x0660 && r <= 0x0669) {
      out.writeCharCode(0x30 + r - 0x0660);
    } else if (r >= 0x06F0 && r <= 0x06F9) {
      out.writeCharCode(0x30 + r - 0x06F0);
    } else if (r == 0x066B) {
      out.write('.');
    } else if (r == 0x066C) {
      out.write(',');
    } else {
      out.writeCharCode(r);
    }
  }
  return out.toString();
}

/// Applies [gymNormalizeDigits] while typing (phones, prices, years, codes).
class GymDigitsFormatter extends TextInputFormatter {
  const GymDigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final text = gymNormalizeDigits(newValue.text);
    if (text == newValue.text) return newValue;
    // Every mapped character stays one UTF-16 unit, so offsets don't move.
    return newValue.copyWith(text: text);
  }
}

/// Labelled text field in the hub style.
class GymTextField extends StatelessWidget {
  const GymTextField({
    required this.label,
    required this.controller,
    this.hint,
    this.error,
    this.keyboardType,
    this.maxLength,
    this.maxLines = 1,
    this.minLines,
    this.textCapitalization = TextCapitalization.sentences,
    this.onChanged,
    this.optional = false,
    this.autofocus = false,
    super.key,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? error;
  final TextInputType? keyboardType;
  final int? maxLength;
  final int maxLines;
  final int? minLines;
  final TextCapitalization textCapitalization;
  final ValueChanged<String>? onChanged;
  final bool optional;
  final bool autofocus;

  /// Numbers, phones, links and codes accept Arabic digits too.
  bool get _numericish {
    final k = keyboardType;
    return textCapitalization == TextCapitalization.characters ||
        (k != null &&
            (k.index == TextInputType.number.index ||
                k.index == TextInputType.phone.index ||
                k.index == TextInputType.url.index));
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.hubCard),
          borderSide: BorderSide(color: c),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xxs, bottom: AppSpacing.xxs),
          child: Text.rich(
            TextSpan(children: [
              TextSpan(text: label),
              if (optional)
                TextSpan(
                  text: '  Optional',
                  style: AppTypography.labelSmall
                      .copyWith(color: AppColors.hubTextFaint),
                ),
            ]),
            style: AppTypography.labelLarge.copyWith(
              color: AppColors.hubTextBody,
              fontWeight: AppTypography.semiBold,
            ),
          ),
        ),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          maxLength: maxLength,
          maxLines: maxLines,
          minLines: minLines,
          textCapitalization: textCapitalization,
          inputFormatters: _numericish ? const [GymDigitsFormatter()] : null,
          onChanged: onChanged,
          style: AppTypography.bodyLarge.copyWith(color: AppColors.hubTextBright),
          cursorColor: AppColors.hubEyebrow,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle:
                AppTypography.bodyLarge.copyWith(color: AppColors.hubTextFaint),
            errorText: error,
            errorStyle: AppTypography.labelMedium.copyWith(color: AppColors.hubDanger),
            filled: true,
            fillColor: AppColors.authInputFill,
            counterStyle:
                AppTypography.caption.copyWith(color: AppColors.hubTextFaint),
            border: border(AppColors.authInputBorder),
            enabledBorder: border(AppColors.authInputBorder),
            focusedBorder: border(AppColors.hubRing),
            errorBorder: border(AppColors.hubDanger),
            focusedErrorBorder: border(AppColors.hubDanger),
          ),
        ),
      ],
    );
  }
}

/// Modal sheet with a grabber, safe area and keyboard inset.
Future<T?> showGymSheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
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
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
        child: child,
      ),
    ),
  );
}

/// Grabber + title (+ subtitle) at the top of a sheet.
class GymSheetHeader extends StatelessWidget {
  const GymSheetHeader({required this.title, this.subtitle, super.key});

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
            style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextMuted),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
      ],
    );
  }
}

/// The end of an important flow (inquiry sent, submitted for review,
/// joined a gym): a clear finish that says what happens next, instead of a
/// toast that disappears.
Future<void> showGymSuccess(
  BuildContext context, {
  required String title,
  required String message,
  String doneLabel = 'Done',
}) {
  HapticFeedback.mediumImpact();
  return showGymSheet<void>(
    context,
    Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const GymSheetHeader(title: ''),
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.hubShareOnFill,
                border: Border.all(color: AppColors.hubShareOnText),
              ),
              child: const Icon(LucideIcons.check,
                  size: AppSizing.iconLg, color: AppColors.hubShareOnText),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.headlineSmall.copyWith(
              color: AppColors.hubTextBright,
              fontWeight: AppTypography.bold,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody, height: 1.4),
          ),
          const SizedBox(height: AppSpacing.lg),
          HubGradientButton(
            label: doneLabel,
            height: AppSizing.buttonHeight,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    ),
  );
}

/// Short explanatory note (privacy, payment, review rules).
class GymNote extends StatelessWidget {
  const GymNote(this.text, {this.icon = LucideIcons.info, super.key});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.hubNote,
        borderRadius: BorderRadius.circular(AppRadius.hubCard),
        border: Border.all(color: AppColors.hubCardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizing.iconSm + 2, color: AppColors.hubSkyLight),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              text,
              style: AppTypography.labelLarge.copyWith(color: AppColors.hubChipText),
            ),
          ),
        ],
      ),
    );
  }
}

/// "12 Oct" / "12 Oct 2025" style dates without pulling in a locale.
String gymShortDate(DateTime d) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final now = DateTime.now();
  final base = '${d.day} ${months[d.month - 1]}';
  return d.year == now.year ? base : '$base ${d.year}';
}

/// "12 min ago", "3 h ago", "Yesterday", or a date.
String gymRelativeTime(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Yesterday';
  return gymShortDate(d);
}

/// "900 EGP" with grouping, no decimals unless there are some.
String gymPrice(double amount, String currency) {
  final whole = amount == amount.roundToDouble();
  final s = whole ? amount.round().toString() : amount.toStringAsFixed(2);
  final parts = s.split('.');
  final grouped = parts.first.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]},');
  return '${parts.length > 1 ? '$grouped.${parts[1]}' : grouped} $currency';
}
