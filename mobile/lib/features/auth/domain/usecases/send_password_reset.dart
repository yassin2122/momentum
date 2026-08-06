import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

/// Encapsulates the "forgot password" business action.
class SendPasswordReset {
  const SendPasswordReset(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call(String email) {
    return _repository.sendPasswordResetEmail(email);
  }
}
