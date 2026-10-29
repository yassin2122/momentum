import 'dart:typed_data';

import '../../../../core/error/result.dart';
import '../entities/health_entities.dart';

/// Contract for the Doctors & Physiotherapists marketplace. Discovery and
/// contact only — there is deliberately no booking method here.
abstract interface class HealthRepository {
  // ---- athletes ----

  Future<Result<List<HealthDirectoryEntry>>> getDirectory({
    String? search,
    HealthKind? kind,
    String? specialty,
    HealthServiceMode? mode,
    bool verifiedOnly = false,
  });

  Future<Result<HealthProviderDetail>> getProvider(String listingId);

  Future<Result<List<HealthDirectoryEntry>>> getSaved();

  Future<Result<void>> setSaved(String listingId, bool saved);

  // ---- providers ----

  /// The caller's own health profiles (at most one per type).
  Future<Result<List<MyHealthProfile>>> getMine();

  /// Creates a private draft; returns its listing id.
  Future<Result<String>> create({
    required HealthKind kind,
    required String name,
    required String specialty,
    required String city,
    required String phone,
  });

  Future<Result<void>> update(MyHealthProfile current, HealthProfilePatch patch);

  Future<Result<void>> setPhoto(MyHealthProfile current, Uint8List bytes, String contentType);

  Future<Result<void>> submit(String listingId);

  Future<Result<void>> setVisible(String listingId, bool visible);

  /// [document] (PDF/JPG/PNG) asks Grit to verify; without one the
  /// qualification is shown as provider-submitted.
  Future<Result<void>> addCredential(
    String listingId,
    HealthCredentialDraft draft, {
    Uint8List? document,
    String? documentType,
  });

  Future<Result<void>> deleteCredential(HealthCredential credential);
}
