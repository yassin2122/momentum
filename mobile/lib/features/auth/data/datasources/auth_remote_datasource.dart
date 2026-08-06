import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/error/exceptions.dart';

/// Wraps raw Supabase Auth SDK calls. This is the ONLY place in the app
/// that talks to `supabase_flutter`'s auth API directly.
///
/// Every method throws an [AuthException] (or [NetworkException]) on
/// failure instead of letting Supabase's raw AuthException/SocketException
/// leak upward — the repository is responsible for turning these into
/// domain [Failure]s.
class AuthRemoteDataSource {
  const AuthRemoteDataSource(this._client);

  final supabase.SupabaseClient _client;

  supabase.User? get currentUser => _client.auth.currentUser;

  Future<supabase.User> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('no_user', 'Sign in failed');
      }
      return user;
    } on supabase.AuthException catch (e) {
      throw AuthException(e.code ?? 'unknown', e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }

  Future<supabase.User> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      final user = response.user;
      if (user == null) {
        throw const AuthException('no_user', 'Registration failed');
      }
      return user;
    } on supabase.AuthException catch (e) {
      throw AuthException(e.code ?? 'unknown', e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }

  Future<supabase.User> signInAnonymously() async {
    try {
      final response = await _client.auth.signInAnonymously();
      final user = response.user;
      if (user == null) {
        throw const AuthException('no_user', 'Could not start guest session');
      }
      return user;
    } on supabase.AuthException catch (e) {
      throw AuthException(e.code ?? 'unknown', e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on supabase.AuthException catch (e) {
      throw AuthException(e.code ?? 'unknown', e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }

  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
    } on supabase.AuthException catch (e) {
      throw AuthException(e.code ?? 'unknown', e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }
}
