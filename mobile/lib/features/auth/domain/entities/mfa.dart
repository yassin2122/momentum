/// A started (not yet confirmed) authenticator-app enrolment.
final class MfaEnrollment {
  const MfaEnrollment({
    required this.factorId,
    required this.secret,
    required this.otpauthUri,
  });

  final String factorId;

  /// Base32 key the user types into their authenticator app.
  final String secret;

  /// `otpauth://` link that opens an installed authenticator app directly.
  final String otpauthUri;
}

/// A confirmed second factor on the account.
final class MfaFactor {
  const MfaFactor({required this.id, this.friendlyName});

  final String id;
  final String? friendlyName;
}
