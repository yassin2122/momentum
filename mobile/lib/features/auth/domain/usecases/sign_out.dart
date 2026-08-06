import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

/// Encapsulates signing the current user out (clears the Supabase session,
/// whether it's a guest or authenticated session).
class SignOut {
  const SignOut(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call() {
    return _repository.signOut();
  }
}
