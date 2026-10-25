import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_sizing.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/app_search_field.dart';
import '../../../../core/widgets/hub_ui.dart';
import '../../../../core/widgets/network_photo.dart';
import '../../domain/entities/trackable_exercise.dart';
import '../../domain/services/exercise_catalog.dart';
import '../providers/workout_providers.dart';
import 'create_exercise_sheet.dart';

/// Bottom sheet to pick an exercise from the library (or create a custom
/// one). Pops with the chosen [TrackableExercise].
///
/// Organised for training, not browsing a database: body-part chips, then
/// your recent exercises, then the main lifts, then the full A–Z list.
/// Searching ranks main lifts and name matches first. Every row shows the
/// exercise photo and its primary muscle.
Future<TrackableExercise?> showExercisePicker(
  BuildContext context, {
  required String title,
}) =>
    showModalBottomSheet<TrackableExercise>(
      useRootNavigator: true,
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Same canvas as the dashboard (HubBackground below).
      backgroundColor: AppColors.hubBackgroundBottom,
      barrierColor: AppColors.achScrim,
      clipBehavior: Clip.antiAlias,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.92,
        child: HubBackground(
          glowCenter: const Alignment(0.4, -1),
          child: _ExercisePicker(title: title),
        ),
      ),
    );

class _ExercisePicker extends ConsumerStatefulWidget {
  const _ExercisePicker({required this.title});

  final String title;

  @override
  ConsumerState<_ExercisePicker> createState() => _ExercisePickerState();
}

class _ExercisePickerState extends ConsumerState<_ExercisePicker> {
  static const _pageSize = 40;

  final _scroll = ScrollController();
  Timer? _debounce;
  String _query = '';
  BodyPart? _part;

  // Home sections (loaded once; filtered by body part locally).
  List<TrackableExercise> _recent = const [];
  List<TrackableExercise> _main = const [];

  // Search results, or the A–Z list when the query is empty.
  List<TrackableExercise> _list = const [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _error;
  int _requestId = 0;

  bool get _searching => _query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadHome();
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadHome() async {
    final repo = ref.read(workoutRepositoryProvider);
    final results = await Future.wait([
      repo.recentExercises(),
      repo.exercisesBySlugs(ExerciseCatalog.allMainSlugs),
    ]);
    if (!mounted) return;
    setState(() {
      _recent = results[0].valueOrNull ?? const [];
      _main = results[1].valueOrNull ?? const [];
    });
  }

  Future<void> _reload() async {
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(workoutRepositoryProvider).searchExercises(
          _query,
          muscleGroups: _part?.muscleGroups ?? const [],
          limit: _searching ? 60 : _pageSize,
        );
    if (!mounted || id != _requestId) return;
    final items = result.valueOrNull ?? const <TrackableExercise>[];
    setState(() {
      _loading = false;
      _error = result.failureOrNull?.message;
      _list = _searching ? ExerciseCatalog.rankForSearch(items, _query) : items;
      _hasMore = !_searching && items.length == _pageSize;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore || _searching) return;
    final id = _requestId;
    setState(() => _loadingMore = true);
    final result = await ref.read(workoutRepositoryProvider).searchExercises(
          '',
          muscleGroups: _part?.muscleGroups ?? const [],
          offset: _list.length,
          limit: _pageSize,
        );
    if (!mounted || id != _requestId) return;
    final items = result.valueOrNull ?? const <TrackableExercise>[];
    setState(() {
      _loadingMore = false;
      _list = [..._list, ...items];
      _hasMore = result.isSuccess && items.length == _pageSize;
    });
  }

  void _onScroll() {
    final p = _scroll.position;
    if (p.pixels > p.maxScrollExtent - 600) _loadMore();
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _reload);
  }

  void _selectPart(BodyPart? part) {
    if (part == _part) return;
    setState(() => _part = part);
    _debounce?.cancel();
    _reload();
  }

  Future<void> _createCustom() async {
    final created = await showCreateExerciseSheet(
      context,
      initialName: _query.trim(),
    );
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  void _pick(TrackableExercise e) => Navigator.of(context).pop(e);

  bool _inPart(TrackableExercise e) =>
      _part == null || BodyPart.ofMuscleGroup(e.primaryMuscle) == _part;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.md, AppSpacing.xs, 0),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.hubTextBright,
                    fontWeight: AppTypography.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: AppColors.hubTextBody),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.sm),
          child: AppSearchField(
            hintText: 'Search exercises',
            onChanged: _onQueryChanged,
            onClear: () => _onQueryChanged(''),
          ),
        ),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            children: [
              _PartChip(
                label: 'All',
                selected: _part == null,
                onTap: () => _selectPart(null),
              ),
              for (final p in BodyPart.values) ...[
                const SizedBox(width: AppSpacing.xs),
                _PartChip(
                  label: p.label,
                  selected: _part == p,
                  onTap: () => _selectPart(p),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Expanded(child: _buildList()),
      ],
    );
  }

  Widget _buildList() {
    final sections = <Widget>[];

    if (_searching) {
      sections.add(_SectionHeader(
        _loading ? 'Searching…' : 'Results',
        trailing: _loading ? null : '${_list.length}',
      ));
    } else {
      final recent = _recent.where(_inPart).toList();
      final main = ExerciseCatalog.orderMain(_main, part: _part);
      if (recent.isNotEmpty) {
        sections
          ..add(const _SectionHeader('Recent'))
          ..addAll(recent.map((e) => _ExerciseTile(e, onTap: () => _pick(e))));
      }
      if (main.isNotEmpty) {
        sections
          ..add(_SectionHeader(_part == null
              ? 'Main lifts'
              : 'Main ${_part!.label.toLowerCase()} lifts'))
          ..addAll(main.map((e) => _ExerciseTile(e, onTap: () => _pick(e))));
      }
      sections.add(const _SectionHeader('All exercises · A–Z'));
    }

    final body = <Widget>[];
    if (_loading && _list.isEmpty) {
      body.add(const HubLoading());
    } else if (_error != null && _list.isEmpty) {
      body.add(_Message(
        text: _error!,
        actionLabel: 'Try again',
        onAction: _reload,
      ));
    } else if (_list.isEmpty) {
      body.add(_Message(
        text: _searching
            ? 'No exercises match "${_query.trim()}".'
            : 'No exercises here yet.',
        actionLabel: _searching
            ? 'Create "${_query.trim()}"'
            : 'Create custom exercise',
        onAction: _createCustom,
      ));
    } else {
      body.addAll(_list.map((e) => _ExerciseTile(e, onTap: () => _pick(e))));
      if (_loadingMore) body.add(const HubLoading());
    }

    return ListView(
      controller: _scroll,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, 0, AppSpacing.md, AppSpacing.xl),
      children: [
        ...sections,
        ...body,
        const SizedBox(height: AppSpacing.sm),
        Center(
          child: TextButton.icon(
            onPressed: _createCustom,
            icon: const Icon(LucideIcons.plus, size: AppSizing.iconSm),
            label: const Text("Can't find it? Create a custom exercise"),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.hubEyebrow,
              textStyle: AppTypography.labelLarge,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
          top: AppSpacing.md, bottom: AppSpacing.xs, left: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(child: HubEyebrow(title)),
          if (trailing != null)
            Text(
              trailing!,
              style: AppTypography.labelMedium
                  .copyWith(color: AppColors.hubTextFaint),
            ),
        ],
      ),
    );
  }
}

class _PartChip extends StatelessWidget {
  const _PartChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.pill);
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.hubHeroGlow : AppColors.hubIconButton,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: selected ? AppColors.hubAvatarRing : AppColors.hubCardBorder,
          ),
        ),
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: AppTypography.labelMedium.copyWith(
                  color:
                      selected ? AppColors.hubChipText : AppColors.hubTextBody,
                  fontWeight:
                      selected ? AppTypography.semiBold : AppTypography.medium,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Photo, name, "Primary muscle · Equipment".
class _ExerciseTile extends StatelessWidget {
  const _ExerciseTile(this.exercise, {required this.onTap});

  final TrackableExercise exercise;
  final VoidCallback onTap;

  static String _title(String v) => v
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');

  @override
  Widget build(BuildContext context) {
    final e = exercise;
    final meta = [
      if (e.primaryMuscle != null) _title(e.primaryMuscle!),
      if (e.equipment != null && e.equipment!.isNotEmpty) _title(e.equipment!),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: HubCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.xs),
        child: Row(
          children: [
            _Thumb(url: e.imageUrl),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.hubTextBright,
                      fontWeight: AppTypography.semiBold,
                    ),
                  ),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodySmall
                          .copyWith(color: AppColors.hubTextMuted),
                    ),
                  ],
                ],
              ),
            ),
            if (e.isCustom)
              const Padding(
                padding: EdgeInsets.only(left: AppSpacing.xs),
                child: HubPill(
                  label: 'Custom',
                  fill: AppColors.hubShareOffFill,
                  textColor: AppColors.hubTextBody,
                ),
              ),
            const SizedBox(width: AppSpacing.xxs),
            const Icon(
              LucideIcons.plus,
              size: AppSizing.iconSm + 2,
              color: AppColors.hubEyebrow,
            ),
          ],
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});

  final String? url;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    const fallback = ColoredBox(
      color: AppColors.hubIconButton,
      child: Center(
        child: Icon(LucideIcons.dumbbell,
            size: AppSizing.iconMd - 4, color: AppColors.hubTextFaint),
      ),
    );
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: SizedBox.square(
        dimension: _size,
        child: u == null
            ? fallback
            : NetworkPhoto(
                url: u,
                cacheWidth: (_size * 3).round(),
                placeholder: fallback,
              ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.text,
    required this.actionLabel,
    required this.onAction,
  });

  final String text;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style:
                AppTypography.bodyMedium.copyWith(color: AppColors.hubTextBody),
          ),
          const SizedBox(height: AppSpacing.sm),
          HubOutlineButton(label: actionLabel, onPressed: onAction),
        ],
      ),
    );
  }
}
