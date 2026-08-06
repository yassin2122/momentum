import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Exposes the initialized Supabase client to the rest of the app.
///
/// Supabase.initialize() is called once in main.dart before runApp; this
/// provider just hands out the already-initialized singleton instance so
/// data sources never reach for `Supabase.instance` directly (that would
/// bypass dependency injection and make testing harder).
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

/// Streams Supabase auth state changes (sign in / sign out / token refresh)
/// so any feature can react to session changes without polling.
final authStateChangesProvider = StreamProvider<AuthState>((ref) {
  final client = ref.watch(supabaseClientProvider);
  return client.auth.onAuthStateChange;
});
