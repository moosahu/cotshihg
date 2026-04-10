import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  StorageService(this._prefs, this._secure);

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';
  static const String _onboardingKey = 'onboarding_done';

  // ── Token → FlutterSecureStorage (encrypted) ──────────────────────────────
  Future<String?> getToken() => _secure.read(key: _tokenKey);
  Future<void> saveToken(String token) => _secure.write(key: _tokenKey, value: token);
  Future<void> clearToken() => _secure.delete(key: _tokenKey);

  // ── User data → SharedPreferences (non-sensitive) ─────────────────────────
  String? getUser() => _prefs.getString(_userKey);
  Future<void> saveUser(String userJson) => _prefs.setString(_userKey, userJson);

  bool get isOnboardingDone => _prefs.getBool(_onboardingKey) ?? false;
  Future<void> setOnboardingDone() => _prefs.setBool(_onboardingKey, true);

  Future<void> clearAll() async {
    await _secure.deleteAll();
    await _prefs.clear();
  }

  Future<void> clearSession() async {
    await _secure.delete(key: _tokenKey);
    await _prefs.remove(_userKey);
  }
}
