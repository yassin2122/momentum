import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Draw behind the status and system navigation bars (dark-only app).
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlay);

  // Credentials are injected at build time via --dart-define.
  // Run:  flutter run --dart-define-from-file=.env   (from mobile/)
  const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // Without the defines the URL is empty, every request goes to the local
  // dev server, and login fails with an opaque "empty response, 404".
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw StateError(
      'SUPABASE_URL / SUPABASE_ANON_KEY are not set. '
      'Run from mobile/ with: flutter run --dart-define-from-file=.env',
    );
  }

  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);

  runApp(
    const ProviderScope(
      child: MomentumApp(),
    ),
  );
}

/// Convenient top-level accessor — use `supabase.auth`, `supabase.from(...)`,
/// etc. anywhere in the app without reaching for `Supabase.instance.client`.
final supabase = Supabase.instance.client;

class MomentumApp extends ConsumerWidget {
  const MomentumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      routerConfig: router,
      // Re-assert the dark system-bar style on every route, since most
      // screens have no AppBar to carry it.
      builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
        value: AppTheme.systemOverlay,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
