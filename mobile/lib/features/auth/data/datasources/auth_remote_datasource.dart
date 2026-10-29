import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/constants/app_constants.dart';
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

  /// Raw Supabase session events. Errors on this stream (e.g. a token
  /// refresh failing offline, or an expired reset link) are the caller's
  /// to handle — an unhandled one surfaces as an uncaught exception.
  Stream<supabase.AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

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
    String? displayName,
  }) async {
    final supabase.AuthResponse response;
    try {
      response = await _client.auth.signUp(
        email: email,
        password: password,
        data: displayName == null ? null : {'display_name': displayName},
      );
    } on supabase.AuthException catch (e) {
      throw AuthException(e.code ?? 'unknown', e.message);
    } catch (_) {
      throw const NetworkException();
    }
    // Thrown outside the try so the catch-all above can't rewrite them
    // as network errors.
    final user = response.user;
    if (user == null) {
      throw const AuthException('no_user', 'Registration failed');
    }
    // With email confirmation enabled, sign-up returns a user but no
    // session — there's nothing to log in with until they confirm.
    if (response.session == null) {
      throw const AuthException(
        'confirmation_required',
        'Email confirmation required',
      );
    }
    return user;
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

  /// Initiates an OAuth sign-in flow (e.g. Google, Apple).
  ///
  /// Supabase will redirect back to [AppConstants.authRedirectUrl] after the
  /// user authenticates in the browser/web-view.
  Future<void> signInWithOAuth(supabase.OAuthProvider provider) async {
    try {
      await _client.auth.signInWithOAuth(
        provider,
        redirectTo: AppConstants.authRedirectUrl,
      );
    } on supabase.AuthException catch (e) {
      throw AuthException(e.code ?? 'unknown', e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }

  /// Sends a password-reset email.
  ///
  /// [AppConstants.authRedirectUrl] is passed as `redirectTo` so the reset
  /// link reopens the app on the password-update screen instead of a browser.
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(
        email,
        redirectTo: AppConstants.authRedirectUrl,
      );
    } on supabase.AuthException catch (e) {
      throw AuthException(e.code ?? 'unknown', e.message);
    } catch (_) {
      throw const NetworkException();
    }
  }

  /// Sets a new password on the current session's user, then revokes every
  /// other session so a stolen refresh token stops working.
  Future<void> updatePassword(String newPassword) async {
    try {
      await _client.auth.updateUser(
        supabase.UserAttributes(password: newPassword),
      );
    } on supabase.AuthException catch (e) {
      throw AuthException(e.code ?? 'unknown', e.message);
    } catch (_) {
      throw const NetworkException();
    }
    // Best effort: the password already changed even if this fails.
    try {
      await _client.auth.signOut(scope: supabase.SignOutScope.others);
    } catch (_) {}
  }

  // ---- Two-factor (TOTP authenticator app) ----

  /// Signed in with a password but the account has 2FA and this session
  /// hasn't passed it yet (aal1 -> aal2 pending). The database rejects
  /// every API call from such a session, so the app must stop here too.
  bool get needsMfaVerification {
    if (_client.auth.currentSession == null) return false;
    final aal = _client.auth.mfa.getAuthenticatorAssuranceLevel();
    return aal.currentLevel == supabase.AuthenticatorAssuranceLevels.aal1 &&
        aal.nextLevel == supabase.AuthenticatorAssuranceLevels.aal2;
  }

  Future<List<supabase.Factor>> verifiedTotpFactors() => _guard(() async {
        final res = await _client.auth.mfa.listFactors();
        return res.totp
            .where((f) => f.status == supabase.FactorStatus.verified)
            .toList();
      });

  /// Starts TOTP enrolment. Half-finished enrolments from earlier attempts
  /// are removed first so they don't pile up.
  Future<supabase.AuthMFAEnrollResponse> enrollTotp() => _guard(() async {
        final existing = await _client.auth.mfa.listFactors();
        for (final f in existing.all) {
          if (f.status != supabase.FactorStatus.verified) {
            await _client.auth.mfa.unenroll(f.id);
          }
        }
        return _client.auth.mfa.enroll(
          factorType: supabase.FactorType.totp,
          issuer: AppConstants.appName,
        );
      });

  /// Checks a 6-digit code. On success the session is upgraded to aal2
  /// (and an unverified factor becomes verified).
  Future<void> verifyTotp({required String factorId, required String code}) =>
      _guard(() => _client.auth.mfa
          .challengeAndVerify(factorId: factorId, code: code));

  Future<void> unenrollFactor(String factorId) =>
      _guard(() => _client.auth.mfa.unenroll(factorId));

  Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
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
