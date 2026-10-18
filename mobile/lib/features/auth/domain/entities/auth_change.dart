import 'user_entity.dart';

/// What kind of session change just happened.
enum AuthChangeKind {
  /// Session established or refreshed — includes sessions that arrive via a
  /// deep link (OAuth callback) rather than a sign-in call made in-app.
  signedIn,

  signedOut,

  /// The user opened a password-reset link. They hold a short-lived session
  /// and must be sent to the set-new-password screen.
  passwordRecovery,
}

/// Domain-level session event, so the presentation layer can react to
/// auth changes without importing Supabase's own AuthState type.
final class AuthChange {
  const AuthChange(this.kind, this.user);

  final AuthChangeKind kind;

  /// The session's user, or null after sign-out.
  final UserEntity? user;
}
