import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
import '../../domain/entities/auth_change.dart';
import '../../domain/entities/mfa.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';
import '../models/user_model.dart';

/// Concrete [AuthRepository] backed by Supabase Auth.
///
/// Responsible for two things only: calling the data source, and mapping
/// whatever it throws into a typed [Failure]. No business rules live here.
class AuthRepositoryImpl implements AuthRepository {
  const AuthRepositoryImpl(this._remoteDataSource);

  final AuthRemoteDataSource _remoteDataSource;

  @override
  Future<UserEntity?> getCurrentUser() async {
    final user = _remoteDataSource.currentUser;
    if (user == null) return null;
    return UserModel.fromSupabaseUser(user);
  }

  @override
  Stream<AuthChange> watchAuthChanges() {
    return _remoteDataSource.authStateChanges.map((state) {
      final user = state.session?.user;
      final entity = user == null ? null : UserModel.fromSupabaseUser(user);
      if (state.event == supabase.AuthChangeEvent.passwordRecovery) {
        return AuthChange(AuthChangeKind.passwordRecovery, entity);
      }
      // Every other event (initial session, sign-in, token refresh, user
      // update) is described fully by whether a session exists.
      return AuthChange(
        entity == null ? AuthChangeKind.signedOut : AuthChangeKind.signedIn,
        entity,
      );
    });
  }

  @override
  Future<Result<UserEntity>> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final user = await _remoteDataSource.signInWithEmail(
        email: email,
        password: password,
      );
      return Result.success(UserModel.fromSupabaseUser(user));
    } on AuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  @override
  Future<Result<UserEntity>> registerWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final user = await _remoteDataSource.registerWithEmail(
        email: email,
        password: password,
        displayName: displayName,
      );
      return Result.success(UserModel.fromSupabaseUser(user));
    } on AuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  @override
  Future<Result<UserEntity>> continueAsGuest() async {
    try {
      final user = await _remoteDataSource.signInAnonymously();
      return Result.success(UserModel.fromSupabaseUser(user));
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> sendPasswordResetEmail(String email) async {
    try {
      await _remoteDataSource.sendPasswordResetEmail(email);
      return const Result.success(null);
    } on AuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> updatePassword(String newPassword) async {
    try {
      await _remoteDataSource.updatePassword(newPassword);
      return const Result.success(null);
    } on AuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  @override
  Future<Result<void>> signOut() async {
    try {
      await _remoteDataSource.signOut();
      return const Result.success(null);
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  @override
  bool needsMfaVerification() => _remoteDataSource.needsMfaVerification;

  @override
  Future<Result<List<MfaFactor>>> getMfaFactors() => _run(() async {
        final factors = await _remoteDataSource.verifiedTotpFactors();
        return [
          for (final f in factors)
            MfaFactor(id: f.id, friendlyName: f.friendlyName),
        ];
      });

  @override
  Future<Result<MfaEnrollment>> startMfaEnrollment() => _run(() async {
        final res = await _remoteDataSource.enrollTotp();
        final totp = res.totp;
        if (totp == null) {
          throw const AuthException('no_totp', 'Could not start 2FA setup');
        }
        return MfaEnrollment(
          factorId: res.id,
          secret: totp.secret,
          otpauthUri: totp.uri,
        );
      });

  @override
  Future<Result<void>> verifyMfaCode({
    required String factorId,
    required String code,
  }) =>
      _run(() =>
          _remoteDataSource.verifyTotp(factorId: factorId, code: code));

  @override
  Future<Result<void>> removeMfaFactor(String factorId) =>
      _run(() => _remoteDataSource.unenrollFactor(factorId));

  Future<Result<T>> _run<T>(Future<T> Function() body) async {
    try {
      return Result.success(await body());
    } on AuthException catch (e) {
      return Result.failure(_mapAuthError(e));
    } on NetworkException {
      return const Result.failure(NetworkFailure());
    } catch (_) {
      return const Result.failure(UnknownFailure());
    }
  }

  /// Maps Supabase's auth error codes to precise domain failures so the UI
  /// can show a specific, actionable message instead of a generic one.
  Failure _mapAuthError(AuthException e) {
    switch (e.code) {
      case 'invalid_credentials':
        return const InvalidCredentialsFailure();
      case 'user_already_exists':
      case 'email_exists':
        return const EmailAlreadyInUseFailure();
      case 'weak_password':
        return const WeakPasswordFailure();
      case 'invalid_email':
      case 'email_address_invalid':
        return const InvalidEmailFailure();
      case 'user_not_found':
        return const UserNotFoundFailure();
      case 'confirmation_required':
      case 'email_not_confirmed':
        return const EmailConfirmationRequiredFailure();
      case 'over_request_rate_limit':
      case 'over_email_send_rate_limit':
        return const TooManyAttemptsFailure();
      case 'mfa_verification_failed':
      case 'mfa_verification_rejected':
        return const ServerFailure('That code is incorrect or expired.');
      case 'mfa_challenge_expired':
        return const ServerFailure('That code expired. Enter the new one.');
      case 'insufficient_aal':
        return const ServerFailure('Verify with your authenticator app first.');
      case 'same_password':
        return const ServerFailure(
          'Choose a password different from your current one.',
        );
      default:
        return ServerFailure(e.message);
    }
  }
}
