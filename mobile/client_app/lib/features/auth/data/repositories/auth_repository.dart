import '../../../../core/network/api_client.dart';
import '../../../../core/services/storage_service.dart';
import 'dart:convert';

class AuthRepository {
  final ApiClient _api;
  final StorageService _storage;

  AuthRepository(this._api, this._storage);

  Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = _storage.getToken();
    if (token == null) return null;
    try {
      final result = await _api.getProfile();
      return result['data'];
    } catch (_) {
      return null;
    }
  }

  Future<void> sendOTP(String phone) async {
    await _api.sendOTP(phone);
  }

  Future<Map<String, dynamic>> verifyOTP(String firebaseToken, String phone) async {
    final result = await _api.verifyOTP(firebaseToken, phone);
    await _storage.saveToken(result['data']['token']);
    await _storage.saveUser(jsonEncode(result['data']['user']));
    return result['data'];
  }

  Future<Map<String, dynamic>> register({
    required String name,
    required String gender,
    required String role,
  }) async {
    final result = await _api.register(name: name, gender: gender, role: role);
    final user = result['data'];
    await _storage.saveUser(jsonEncode(user));
    return user;
  }

  Future<void> logout() async {
    await _storage.clearAll();
  }
}
