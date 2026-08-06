import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/constants/app_constants.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Supabase.initialize(
      // Project URL (NOT /rest/v1/)
      url: 'https://adskpshwfymknhvqjmlu.supabase.co',

      // Your Publishable (Anon) Key
      publishableKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFkc2twc2h3Znlta25odnFqbWx1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODQ3NDI3ODIsImV4cCI6MjEwMDMxODc4Mn0.YrE5JJDakpkQceUSwvvAueuE0FySld7m3lMr7eRjKW4',
    );

    debugPrint('✅ Supabase initialized successfully');
  } catch (e, stackTrace) {
    debugPrint('❌ Failed to initialize Supabase: $e');
    debugPrintStack(stackTrace: stackTrace);
  }

  runApp(
    const ProviderScope(
      child: GymApp(),
    ),
  );
}

class GymApp extends ConsumerWidget {
  const GymApp({super.key});

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
    );
  }
}
