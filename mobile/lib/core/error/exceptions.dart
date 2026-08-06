/// Exceptions thrown by the data layer (datasources). Repositories catch
/// these and translate them into [Failure]s for the domain/presentation
/// layers — exceptions should never cross the repository boundary.
class ServerException implements Exception {
  const ServerException([this.message = 'Server error']);
  final String message;
}

class NetworkException implements Exception {
  const NetworkException([this.message = 'Network error']);
  final String message;
}

class AuthException implements Exception {
  const AuthException(this.code, [this.message = 'Authentication error']);

  /// Provider-specific error code (e.g. Supabase's error code), used by the
  /// repository to map to a precise [Failure] subtype.
  final String code;
  final String message;
}
