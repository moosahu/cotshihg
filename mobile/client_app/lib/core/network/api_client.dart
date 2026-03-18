import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;

  ApiClient(this._dio);

  // Auth
  Future<Map<String, dynamic>> sendOTP(String phone) async {
    final res = await _dio.post('/auth/send-otp', data: {'phone': phone});
    return res.data;
  }

  Future<Map<String, dynamic>> verifyOTP(String firebaseToken, String phone) async {
    final res = await _dio.post('/auth/verify-otp', data: {'firebaseToken': firebaseToken, 'phone': phone});
    return res.data;
  }

  Future<Map<String, dynamic>> register({required String name, required String gender, required String role}) async {
    final res = await _dio.post('/auth/register', data: {'name': name, 'gender': gender, 'role': role});
    return res.data;
  }

  // Therapists
  Future<Map<String, dynamic>> getTherapists({Map<String, dynamic>? params}) async {
    final res = await _dio.get('/therapists', queryParameters: params);
    return res.data;
  }

  Future<Map<String, dynamic>> getTherapistById(String id) async {
    final res = await _dio.get('/therapists/$id');
    return res.data;
  }

  Future<Map<String, dynamic>> getTherapistAvailability(String id) async {
    final res = await _dio.get('/therapists/$id/availability');
    return res.data;
  }

  // Bookings
  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) async {
    final res = await _dio.post('/bookings', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> getMyBookings({String? status}) async {
    final res = await _dio.get('/bookings', queryParameters: status != null ? {'status': status} : null);
    return res.data;
  }

  // Chat
  Future<Map<String, dynamic>> getMessages(String bookingId, {int page = 1}) async {
    final res = await _dio.get('/chat/$bookingId/messages', queryParameters: {'page': page});
    return res.data;
  }

  // Mood
  Future<Map<String, dynamic>> logMood(Map<String, dynamic> data) async {
    final res = await _dio.post('/mood', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> getMoodHistory({int days = 30}) async {
    final res = await _dio.get('/mood', queryParameters: {'days': days});
    return res.data;
  }

  // Content
  Future<Map<String, dynamic>> getContent({Map<String, dynamic>? params}) async {
    final res = await _dio.get('/content', queryParameters: params);
    return res.data;
  }

  // Therapist profile & availability
  Future<Map<String, dynamic>> updateTherapistProfile(Map<String, dynamic> data) async {
    final res = await _dio.put('/therapists/profile', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> getMyAvailability(String therapistId) async {
    final res = await _dio.get('/therapists/$therapistId/availability');
    return res.data;
  }

  Future<Map<String, dynamic>> cancelBooking(String id) async {
    final res = await _dio.put('/bookings/$id/status', data: {'status': 'cancelled'});
    return res.data;
  }

  Future<Map<String, dynamic>> getMyOwnAvailability() async {
    final res = await _dio.get('/therapists/me/availability');
    return res.data;
  }

  Future<Map<String, dynamic>> updateAvailability(List<Map<String, dynamic>> availability) async {
    final res = await _dio.put('/therapists/availability', data: {'availability': availability});
    return res.data;
  }

  // Payments
  Future<Map<String, dynamic>> getPaymentHistory() async {
    final res = await _dio.get('/payments/history');
    return res.data;
  }

  // User
  Future<Map<String, dynamic>> getProfile() async {
    final res = await _dio.get('/users/profile');
    return res.data;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await _dio.put('/users/profile', data: data);
    return res.data;
  }
}
