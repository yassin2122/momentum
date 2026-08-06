/// Base type for all domain-level failures.
///
/// The data layer catches raw exceptions (Supabase, network, etc.) and
/// converts them into one of these typed Failures. The presentation layer
/// never sees a raw exception — only these, which carry a user-safe [message].
sealed class Failure {
  const Failure(this.message);

  final String message;
}

// ---- Auth-specific failures ----

final class InvalidCredentialsFailure extends Failure {
  const InvalidCredentialsFailure()
      : super('Incorrect email or password. Please try again.');
}

final class EmailAlreadyInUseFailure extends Failure {
  const EmailAlreadyInUseFailure()
      : super('An account with this email already exists.');
}

final class WeakPasswordFailure extends Failure {
  const WeakPasswordFailure()
      : super('Password must be at least 8 characters.');
}

final class InvalidEmailFailure extends Failure {
  const InvalidEmailFailure() : super('Please enter a valid email address.');
}

final class UserNotFoundFailure extends Failure {
  const UserNotFoundFailure() : super('No account found for this email.');
}

// ---- General failures ----

final class NetworkFailure extends Failure {
  const NetworkFailure()
      : super('No internet connection. Please check your network.');
}

final class ServerFailure extends Failure {
  const ServerFailure(
      [super.message = 'Something went wrong. Please try again.']);
}

final class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'An unexpected error occurred.']);
}
