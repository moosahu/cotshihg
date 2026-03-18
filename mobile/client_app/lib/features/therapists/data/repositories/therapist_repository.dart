import '../../../../core/network/api_client.dart';

class TherapistRepository {
  final ApiClient _api;
  TherapistRepository(this._api);

  Future<List<dynamic>> getTherapists({Map<String, dynamic>? filters}) async {
    final result = await _api.getTherapists(params: filters);
    return result['data'] ?? [];
  }

  Future<Map<String, dynamic>> getTherapistById(String id) async {
    final result = await _api.getTherapistById(id);
    return result['data'];
  }

  Future<List<dynamic>> getAvailability(String id) async {
    final result = await _api.getTherapistAvailability(id);
    return result['data'] ?? [];
  }
}
