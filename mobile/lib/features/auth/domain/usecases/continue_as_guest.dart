import '../../../../core/error/result.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

/// Encapsulates starting a Guest Mode (anonymous) session.
class ContinueAsGuest {
  const ContinueAsGuest(this._repository);

  final AuthRepository _repository;

  Future<Result<UserEntity>> call() {
    return _repository.continueAsGuest();
  }
}
