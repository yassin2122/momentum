import '../../../../core/error/result.dart';
import '../entities/user_entity.dart';

/// Contract for all authentication operations.
///
/// The domain and presentation layers depend only on this interface, never
/// on Supabase directly. [AuthRepositoryImpl] (data layer) is the only
/// place that knows Supabase exists — swapping auth providers later means
/// writing a new implementation of this interface, nothing else changes.
abstract interface class AuthRepository {
  /// Returns the current user if a session exists (guest or authenticated),
  /// or null if there is no active session.
  Future<UserEntity?> getCurrentUser();

  Future<Result<UserEntity>> signInWithEmail({
    required String email,
    required String password,
  });

  Future<Result<UserEntity>> registerWithEmail({
    required String email,
    required String password,
  });

  /// Starts an anonymous session so the user can use the app without an
  /// account. Returns a [UserEntity] with `isGuest = true`.
  Future<Result<UserEntity>> continueAsGuest();

  Future<Result<void>> sendPasswordResetEmail(String email);

  Future<Result<void>> signOut();
}
