import '../../../../core/error/result.dart';
import '../repositories/auth_repository.dart';

/// Sets a new password for the current session — the last step of the
/// password-reset flow, after the user opens the emailed reset link.
class UpdatePassword {
  const UpdatePassword(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call(String newPassword) {
    return _repository.updatePassword(newPassword);
  }
}
