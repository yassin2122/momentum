import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// "12:34" (or "1:02:03") since [since], ticking every second.
class ElapsedTime extends StatefulWidget {
  const ElapsedTime({required this.since, this.style, super.key});

  final DateTime since;

  /// Defaults to the active-workout header style.
  final TextStyle? style;

  /// Formats a duration the way [ElapsedTime] shows it.
  static String format(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return d.inHours > 0
        ? '${d.inHours}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${d.inMinutes}:${two(d.inSeconds % 60)}';
  }

  @override
  State<ElapsedTime> createState() => _ElapsedTimeState();
}

class _ElapsedTimeState extends State<ElapsedTime> {
  late final Timer _timer =
      Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = ElapsedTime.format(DateTime.now().difference(widget.since));
    return Text(
      text,
      semanticsLabel: 'Workout time $text',
      style: widget.style ??
          AppTypography.numeric(AppTypography.headlineSmall).copyWith(
            color: AppColors.hubTextBright,
            fontWeight: AppTypography.semiBold,
          ),
    );
  }
}
