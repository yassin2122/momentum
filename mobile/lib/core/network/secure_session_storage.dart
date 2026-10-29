import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Keeps the Supabase session (access + refresh token) in the OS keystore
/// (Android Keystore / iOS Keychain) instead of plain SharedPreferences,
/// where any root/backup/file-read could lift the refresh token.
///
/// iOS items are `first_unlock_this_device`: readable for background token
/// refresh, but never synced to iCloud or restored onto another device.
const FlutterSecureStorage _secure = FlutterSecureStorage(
  iOptions: IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
  mOptions: MacOsOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  ),
);

/// supabase_flutter's own default key, so an existing session can be moved
/// over on first launch after this change.
String supabaseSessionKey(String supabaseUrl) =>
    'sb-${Uri.parse(supabaseUrl).host.split('.').first}-auth-token';

class SecureLocalStorage extends LocalStorage {
  SecureLocalStorage({required this.persistSessionKey});

  final String persistSessionKey;

  @override
  Future<void> initialize() async {
    // One-time move of a session left in plaintext SharedPreferences by
    // older builds. The plaintext copy is always deleted.
    final prefs = await SharedPreferences.getInstance();
    final legacy = prefs.getString(persistSessionKey);
    if (legacy != null) {
      if (!await _safeContains(persistSessionKey)) {
        await _secure.write(key: persistSessionKey, value: legacy);
      }
      await prefs.remove(persistSessionKey);
    }
  }

  @override
  Future<bool> hasAccessToken() => _safeContains(persistSessionKey);

  @override
  Future<String?> accessToken() async {
    try {
      return await _secure.read(key: persistSessionKey);
    } catch (_) {
      // Keystore entry unreadable (e.g. restored from another device):
      // drop it and start signed out rather than crash on launch.
      await removePersistedSession();
      return null;
    }
  }

  @override
  Future<void> persistSession(String persistSessionString) =>
      _secure.write(key: persistSessionKey, value: persistSessionString);

  @override
  Future<void> removePersistedSession() async {
    try {
      await _secure.delete(key: persistSessionKey);
    } catch (_) {}
  }

  Future<bool> _safeContains(String key) async {
    try {
      return await _secure.containsKey(key: key);
    } catch (_) {
      return false;
    }
  }
}

/// PKCE code verifiers (OAuth / reset-link exchange) also go to the keystore.
class SecureGotrueAsyncStorage extends GotrueAsyncStorage {
  const SecureGotrueAsyncStorage();

  @override
  Future<String?> getItem({required String key}) => _secure.read(key: key);

  @override
  Future<void> setItem({required String key, required String value}) =>
      _secure.write(key: key, value: value);

  @override
  Future<void> removeItem({required String key}) => _secure.delete(key: key);
}
