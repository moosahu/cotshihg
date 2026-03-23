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
    final res = await _dio.put('/bookings/$id/cancel');
    return res.data;
  }

  Future<Map<String, dynamic>> confirmBooking(String id) async {
    final res = await _dio.put('/bookings/$id/confirm');
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

  Future<Map<String, dynamic>> toggleInstantAvailability(bool isAvailable) async {
    final res = await _dio.put('/therapists/instant-availability', data: {'is_available': isAvailable});
    return res.data;
  }

  Future<Map<String, dynamic>> createInstantBooking(String therapistId, String sessionType) async {
    final res = await _dio.post('/bookings/instant', data: {'therapist_id': therapistId, 'session_type': sessionType});
    return res.data;
  }

  Future<Map<String, dynamic>> getInstantTherapists() async {
    final res = await _dio.get('/therapists', queryParameters: {'instant': 'true'});
    return res.data;
  }

  // Sessions (Agora)
  Future<Map<String, dynamic>> startSession(String bookingId) async {
    final res = await _dio.post('/sessions/$bookingId/start');
    return res.data;
  }

  Future<Map<String, dynamic>> getAgoraToken(String bookingId) async {
    final res = await _dio.get('/sessions/$bookingId/token');
    return res.data;
  }

  Future<void> endSession(String sessionId) async {
    await _dio.post('/sessions/$sessionId/end');
  }

  Future<void> saveFcmToken(String token) async {
    await _dio.put('/users/fcm-token', data: {'fcm_token': token});
  }

  Future<void> submitReview(String bookingId, int rating, {String? comment}) async {
    await _dio.post('/bookings/$bookingId/review', data: {
      'rating': rating,
      if (comment != null && comment.isNotEmpty) 'comment': comment,
    });
  }

  // Payments
  Future<Map<String, dynamic>> confirmBookingAfterPayment(String bookingId) async {
    final res = await _dio.put('/bookings/$bookingId/confirm-payment');
    return res.data;
  }

  Future<Map<String, dynamic>> initiatePayment(String bookingId) async {
    final res = await _dio.post('/payments/initiate', data: {'booking_id': bookingId});
    return res.data;
  }

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

  // Questionnaires
  Future<Map<String, dynamic>> getMyQuestionnaires() async {
    final res = await _dio.get('/questionnaires');
    return res.data;
  }

  Future<Map<String, dynamic>> createQuestionnaire(Map<String, dynamic> data) async {
    final res = await _dio.post('/questionnaires', data: data);
    return res.data;
  }

  Future<Map<String, dynamic>> updateQuestionnaire(String id, Map<String, dynamic> data) async {
    final res = await _dio.put('/questionnaires/$id', data: data);
    return res.data;
  }

  Future<void> deleteQuestionnaire(String id) async {
    await _dio.delete('/questionnaires/$id');
  }

  Future<Map<String, dynamic>> setDefaultQuestionnaire(String id) async {
    final res = await _dio.put('/questionnaires/$id/set-default');
    return res.data;
  }

  Future<Map<String, dynamic>> assignQuestionnaire(String templateId, String bookingId) async {
    final res = await _dio.post('/questionnaires/$templateId/assign/$bookingId');
    return res.data;
  }

  Future<Map<String, dynamic>> getBookingAssignments(String bookingId) async {
    final res = await _dio.get('/questionnaires/assignments/booking/$bookingId');
    return res.data;
  }

  Future<Map<String, dynamic>> getAssignment(String assignmentId) async {
    final res = await _dio.get('/questionnaires/assignments/$assignmentId');
    return res.data;
  }

  Future<Map<String, dynamic>> submitAnswers(String assignmentId, Map<String, dynamic> answers) async {
    final res = await _dio.post('/questionnaires/assignments/$assignmentId/respond', data: {'answers': answers});
    return res.data;
  }
}
