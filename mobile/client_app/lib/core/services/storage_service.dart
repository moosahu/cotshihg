import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  final SharedPreferences _prefs;

  StorageService(this._prefs);

  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'current_user';
  static const String _onboardingKey = 'onboarding_done';

  String? getToken() => _prefs.getString(_tokenKey);

  Future<void> saveToken(String token) => _prefs.setString(_tokenKey, token);

  Future<void> clearToken() => _prefs.remove(_tokenKey);

  String? getUser() => _prefs.getString(_userKey);

  Future<void> saveUser(String userJson) => _prefs.setString(_userKey, userJson);

  bool get isOnboardingDone => _prefs.getBool(_onboardingKey) ?? false;

  Future<void> setOnboardingDone() => _prefs.setBool(_onboardingKey, true);

  Future<void> clearAll() => _prefs.clear();
}
