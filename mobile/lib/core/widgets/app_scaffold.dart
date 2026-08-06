import 'package:flutter/material.dart';
import '../theme/app_spacing.dart';

/// Standard page scaffold. Every screen in the app builds on this rather
/// than a raw [Scaffold], so background color, safe-area handling, and
/// horizontal padding stay identical everywhere.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    required this.body,
    this.appBar,
    this.scrollable = true,
    this.padHorizontal = true,
    this.extendBodyBehindNav = false,
    super.key,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;

  /// Wraps [body] in a [SingleChildScrollView]. Set false when [body]
  /// manages its own scrolling (e.g. a ListView).
  final bool scrollable;

  final bool padHorizontal;

  /// True when a floating nav bar overlays the bottom of this screen —
  /// adds bottom padding so content isn't obscured by it.
  final bool extendBodyBehindNav;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: EdgeInsets.only(
        left: padHorizontal ? AppSpacing.screenPadding : 0,
        right: padHorizontal ? AppSpacing.screenPadding : 0,
        bottom: extendBodyBehindNav ? AppSpacing.xl3 : 0,
      ),
      child: body,
    );

    return Scaffold(
      appBar: appBar,
      body: SafeArea(
        bottom: !extendBodyBehindNav,
        child: scrollable
            ? SingleChildScrollView(child: content)
            : content,
      ),
    );
  }
}
