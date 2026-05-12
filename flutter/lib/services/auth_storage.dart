import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// AuthStorage owns persistence for the refresh token and the
/// currently-cached access token. Refresh is held in secure storage
/// (Keychain on iOS, EncryptedSharedPreferences on Android) so a
/// device backup can't lift it. Access is held in memory only — it's
/// short-lived (15min) and we re-derive it from the refresh on cold
/// start.
///
/// Why not just stash the refresh in SharedPreferences alongside the
/// other auth state? SharedPreferences on Android is plaintext under
/// `/data/data/{pkg}/shared_prefs/` — vulnerable to any process running
/// as the same UID, and lifted by adb backup unless the app opts out.
/// The refresh token is the keys-to-the-kingdom for a 30-day session;
/// it gets the stronger lock.
class AuthStorage {
  static const _refreshKey = 'auth.refresh_token';
  final FlutterSecureStorage _store;
  String? _accessToken;
  DateTime? _accessExpiresAt;

  AuthStorage({FlutterSecureStorage? store})
      : _store = store ?? const FlutterSecureStorage();

  Future<String?> readRefreshToken() => _store.read(key: _refreshKey);

  Future<void> writeRefreshToken(String value) =>
      _store.write(key: _refreshKey, value: value);

  Future<void> clearRefreshToken() => _store.delete(key: _refreshKey);

  /// Returns the cached access token if it's still within its TTL.
  /// A 30s safety margin avoids the race where we ship a request
  /// that expires mid-flight on the server.
  String? get accessToken {
    if (_accessToken == null || _accessExpiresAt == null) return null;
    if (DateTime.now()
        .isAfter(_accessExpiresAt!.subtract(const Duration(seconds: 30)))) {
      return null;
    }
    return _accessToken;
  }

  void setAccessToken(String token, Duration ttl) {
    _accessToken = token;
    _accessExpiresAt = DateTime.now().add(ttl);
  }

  void clearAccessToken() {
    _accessToken = null;
    _accessExpiresAt = null;
  }
}
