import '../../../../core/network/api_client.dart';

class BookingRepository {
  final ApiClient _api;
  BookingRepository(this._api);

  Future<Map<String, dynamic>> createBooking(Map<String, dynamic> data) async {
    final result = await _api.createBooking(data);
    return result['data'];
  }

  Future<List<dynamic>> getMyBookings({String? status}) async {
    final result = await _api.getMyBookings(status: status);
    return result['data'] ?? [];
  }

  Future<void> cancelBooking(String bookingId) async {
    await _api.cancelBooking(bookingId);
  }
}
