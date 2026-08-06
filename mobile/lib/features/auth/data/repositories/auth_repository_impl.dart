import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failure.dart';
import '../../../../core/error/result.dart';
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
  }) async {
    try {
      final user = await _remoteDataSource.registerWithEmail(
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
      default:
        return ServerFailure(e.message);
    }
  }
}
