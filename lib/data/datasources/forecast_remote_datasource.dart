import 'dart:convert';
import 'package:prepal2/core/network/api_client.dart';
import 'package:prepal2/core/network/api_constants.dart';

abstract class ForecastRemoteDataSource {
  /// Calls ML service to get 7-day demand forecast
  Future<Map<String, dynamic>> get7DayForecast();

  /// Get per-product forecast predictions from ML service
  Future<List<Map<String, dynamic>>> getProductForecasts();

  /// Get forecast accuracy metrics (last 30 days)
  Future<Map<String, dynamic>> getForecastAccuracy();

  /// Get AI insights based on current forecast data
  Future<Map<String, dynamic>> getAIInsights();
}

class ForecastRemoteDataSourceImpl implements ForecastRemoteDataSource {
  final ApiClient _apiClient;

  ForecastRemoteDataSourceImpl(this._apiClient);

  String _today() => DateTime.now().toIso8601String().split('T').first;

  Map<String, dynamic> _basePayload(
    String type, {
    Map<String, dynamic>? extra,
  }) {
    return {
      'type': type,
      'businessId': _apiClient.getBusinessId() ?? '',
      // Required by current ML validation contract.
      'item_name': 'all_items',
      'business_type': 'Cafe',
      'date': _today(),
      'price': 0,
      'shelf_life_hours': 24,
      ...?extra,
    };
  }

  Future<Map<String, dynamic>> _predict(
    String type, {
    Map<String, dynamic>? extra,
  }) async {
    final response = await _apiClient.mlPost(
      ApiConstants.mlPredict,
      body: _basePayload(type, extra: extra),
    );

    final decoded = jsonDecode(response.body);

    if (response.statusCode != 200) {
      if (decoded is Map<String, dynamic> && decoded['message'] is String) {
        throw Exception(decoded['message']);
      }
      throw Exception('ML request failed for $type');
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid ML response format for $type');
    }

    final data = decoded['data'];
    if (data is Map<String, dynamic>) return data;
    if (data is List) return {'data': data};
    return decoded;
  }

  @override
  Future<Map<String, dynamic>> get7DayForecast() async {
    final data = await _predict('7day_forecast');
    final days = data['days'];
    if (days is List && days.isNotEmpty) {
      return {'days': days};
    }
    final listData = data['data'];
    if (listData is List && listData.isNotEmpty) {
      return {'days': listData};
    }
    throw Exception('No 7-day forecast data returned by backend');
  }

  @override
  Future<List<Map<String, dynamic>>> getProductForecasts() async {
    final data = await _predict('product_forecast');
    final payload = data['data'] ?? data;
    if (payload is List) {
      return payload.whereType<Map<String, dynamic>>().toList();
    }
    if (payload is Map<String, dynamic> && payload.isNotEmpty) {
      return [payload];
    }
    return const [];
  }

  @override
  Future<Map<String, dynamic>> getForecastAccuracy() async {
    final data = await _predict('accuracy_metrics', extra: {'days': 30});
    final accuracyRaw = data['accuracy'];
    if (accuracyRaw is num) {
      return {
        'accuracy': accuracyRaw.toDouble(),
        'daysAnalyzed': data['daysAnalyzed'] ?? 30,
      };
    }

    throw Exception('No forecast accuracy data returned by backend');
  }

  @override
  Future<Map<String, dynamic>> getAIInsights() async {
    final data = await _predict('insights');
    final message = data['message'];
    if (message is String && message.isNotEmpty) {
      return {'message': message, 'type': data['type'] ?? 'info'};
    }

    return const {
      'message': 'No AI insight available yet from backend.',
      'type': 'info',
    };
  }
}
