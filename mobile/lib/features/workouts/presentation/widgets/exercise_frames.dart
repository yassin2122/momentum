import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/network_photo.dart';

/// An exercise's two library photos (start and end position) in one
/// fixed 3:2 frame — the photos' own shape, so nothing is cropped and the
/// layout never jumps while they load.
///
/// While [playing], the frames alternate with a short crossfade so the
/// movement reads at a glance. Tapping "Start" / "End" pins that frame;
/// tapping the photo resumes the loop. With reduced motion the loop is
/// off and the chips switch frames.
class ExerciseFrames extends StatefulWidget {
  const ExerciseFrames({
    required this.urls,
    required this.exerciseName,
    this.playing = true,
    this.trailing,
    super.key,
  });

  /// Photo URLs in order; only the first two are used.
  final List<String> urls;
  final String exerciseName;

  /// False when this exercise isn't the one on screen (pauses the loop).
  final bool playing;

  /// Optional control in the top-right corner (e.g. the muscles toggle).
  final Widget? trailing;

  /// The photos' aspect ratio (free-exercise-db frames are 850 × 567).
  static const double aspectRatio = 3 / 2;

  /// How long each frame holds before the crossfade.
  static const Duration hold = Duration(milliseconds: 1400);

  @override
  State<ExerciseFrames> createState() => _ExerciseFramesState();
}

class _ExerciseFramesState extends State<ExerciseFrames> {
  int _frame = 0;
  bool _pinned = false;
  Timer? _timer;

  int get _count => widget.urls.length.clamp(0, 2);

  bool get _loops {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return _count > 1 && widget.playing && !_pinned && !reduceMotion;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTimer();
  }

  @override
  void didUpdateWidget(ExerciseFrames old) {
    super.didUpdateWidget(old);
    if (old.urls.length != widget.urls.length) _frame = 0;
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    if (_loops) {
      _timer ??= Timer.periodic(ExerciseFrames.hold, (_) {
        if (mounted) setState(() => _frame = (_frame + 1) % _count);
      });
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  void _pin(int frame) {
    setState(() {
      _frame = frame;
      _pinned = true;
    });
    _syncTimer();
  }

  void _resume() {
    if (!_pinned) return;
    setState(() => _pinned = false);
    _syncTimer();
  }

  @override
  Widget build(BuildContext context) {
    const placeholder = ColoredBox(
      color: AppColors.hubIconButton,
      child: Center(
        child: Icon(LucideIcons.dumbbell, color: AppColors.hubTextFaint),
      ),
    );
    final count = _count;
    final frame = _frame.clamp(0, count == 0 ? 0 : count - 1);

    // Own layer: the crossfade every ~1.4 s repaints only the photo, not
    // the set table around it.
    return RepaintBoundary(
      child: Semantics(
        image: true,
        label: count > 1
            ? '${widget.exerciseName}, start and end position'
            : widget.exerciseName,
        child: AspectRatio(
          aspectRatio: ExerciseFrames.aspectRatio,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.hubHero),
            child: Stack(
              fit: StackFit.expand,
              children: [
                placeholder,
                // Both frames stay mounted (and decoded) so the swap is a
                // pure opacity change — no reload, no flash.
                for (var i = 0; i < count; i++)
                  AnimatedOpacity(
                    opacity: i == frame ? 1 : 0,
                    duration: const Duration(milliseconds: 280),
                    curve: Curves.easeInOut,
                    child: GestureDetector(
                      onTap: _resume,
                      child: NetworkPhoto(
                        url: widget.urls[i],
                        fit: BoxFit.cover,
                        placeholder: placeholder,
                      ),
                    ),
                  ),
                if (count > 1)
                  Positioned(
                    left: AppSpacing.xs,
                    bottom: AppSpacing.xs,
                    child: _FrameChips(
                      current: frame,
                      onPick: _pin,
                    ),
                  ),
                if (widget.trailing != null)
                  Positioned(
                    right: AppSpacing.xs,
                    top: AppSpacing.xs,
                    child: widget.trailing!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Start" / "End" chips: which frame is showing, tap to pin one.
class _FrameChips extends StatelessWidget {
  const _FrameChips({required this.current, required this.onPick});

  final int current;
  final ValueChanged<int> onPick;

  static const _labels = ['Start', 'End'];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.hubBackgroundBottom.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < _labels.length; i++)
            Semantics(
              button: true,
              selected: i == current,
              label: 'Show ${_labels[i].toLowerCase()} position',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => onPick(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == current
                        ? AppColors.accentProgress
                        : AppColors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    _labels[i],
                    style: AppTypography.labelMedium.copyWith(
                      color: i == current
                          ? AppColors.hubBackgroundBottom
                          : AppColors.hubTextBright,
                      fontWeight: AppTypography.semiBold,
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
