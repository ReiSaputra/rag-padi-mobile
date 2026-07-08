import '../../../core/api_client.dart';
import 'home_models.dart';

class HomeRepository {
  final _dio = ApiClient.instance.dio;

  /// GET /sensor/latest
  Future<SensorData> fetchLatestSensor() async {
    final res = await _dio.get('/sensor/latest');
    return SensorData.fromJson(res.data as Map<String, dynamic>);
  }

  /// POST /analyze
  Future<AnalyzeResult> analyze() async {
    final res = await _dio.post('/analyze');
    return AnalyzeResult.fromJson(res.data as Map<String, dynamic>);
  }

  /// GET /history
  Future<List<HistoryItem>> fetchHistory() async {
    final res = await _dio.get('/history');
    final list = res.data as List<dynamic>;
    return list
        .map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
