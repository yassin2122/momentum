import '../../../../core/error/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Encapsulates the "sign in with email and password" business action.
///
/// Kept as a single-purpose class (rather than calling the repository
/// directly from the UI) so business rules around sign-in — validation,
/// analytics hooks, future MFA checks — have one obvious place to live.
class SignInWithEmail {
  const SignInWithEmail(this._repository);

  final AuthRepository _repository;

  Future<Result<UserEntity>> call({
    required String email,
    required String password,
  }) {
    return _repository.signInWithEmail(email: email, password: password);
  }
}
