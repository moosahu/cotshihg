import '../../../../core/network/api_client.dart';

class MoodRepository {
  final ApiClient _api;
  MoodRepository(this._api);

  Future<void> logMood(int score, String label, {String? note}) async {
    await _api.logMood({'mood_score': score, 'mood_label': label, 'note': note});
  }

  Future<List<dynamic>> getHistory({int days = 30}) async {
    final result = await _api.getMoodHistory(days: days);
    return result['data'] ?? [];
  }
}
