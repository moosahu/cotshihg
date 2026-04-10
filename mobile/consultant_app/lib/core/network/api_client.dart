import 'package:dio/dio.dart';

class ApiClient {
  final Dio _dio;
  ApiClient(this._dio);

  Future<Map<String, dynamic>> verifyOTP(String firebaseToken, String phone) async {
    final res = await _dio.post('/auth/verify-otp', data: {'firebaseToken': firebaseToken, 'phone': phone});
    return res.data;
  }

  Future<Map<String, dynamic>> getProfile() async {
    final res = await _dio.get('/users/profile');
    return res.data;
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> data) async {
    final res = await _dio.put('/users/profile', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> updateTherapistProfile(Map<String, dynamic> data) async {
    final res = await _dio.put('/therapists/profile', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> getCoachDashboardStats() async {
    final res = await _dio.get('/bookings/coach-stats');
    return res.data;
  }

  Future<Map<String, dynamic>> getMyBookings({String? status}) async {
    final res = await _dio.get('/bookings', queryParameters: status != null ? {'status': status} : null);
    return res.data;
  }

  Future<Map<String, dynamic>> confirmBooking(String id) async {
    final res = await _dio.put('/bookings/$id/confirm');
    return res.data;
  }

  Future<Map<String, dynamic>> cancelBooking(String id) async {
    final res = await _dio.put('/bookings/$id/cancel');
    return res.data;
  }

  Future<Map<String, dynamic>> getPaymentHistory() async {
    final res = await _dio.get('/payments/history');
    return res.data;
  }

  Future<Map<String, dynamic>> getCoachEarnings() async {
    final res = await _dio.get('/payments/coach-earnings');
    return res.data;
  }

  Future<Map<String, dynamic>> getBankDetails() async {
    final res = await _dio.get('/therapists/bank-details');
    return res.data;
  }

  Future<Map<String, dynamic>> updateBankDetails(Map<String, dynamic> data) async {
    final res = await _dio.put('/therapists/bank-details', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> requestPayout() async {
    final res = await _dio.post('/therapists/request-payout');
    return res.data;
  }

  Future<Map<String, dynamic>> getPayoutRequests() async {
    final res = await _dio.get('/therapists/payout-requests');
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
}
