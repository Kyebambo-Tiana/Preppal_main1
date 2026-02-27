import 'dart:convert';
import 'package:prepal2/core/network/api_client.dart';

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

  @override
  Future<Map<String, dynamic>> get7DayForecast() async {
    // Call ML service to get 7-day forecast
    // ML service endpoint: https://preppal-2mb4.onrender.com/api/predict
    final response = await _apiClient.mlPost(
      'https://preppal-2mb4.onrender.com/api/predict',
      body: {
        'type': '7day_forecast',
        'businessId': _apiClient.getBusinessId() ?? '',
      },
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return body['data'] ?? body;
    } else {
      throw Exception(body['message'] ?? 'Failed to fetch 7-day forecast');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getProductForecasts() async {
    // Get product-level forecasts from ML service
    final response = await _apiClient.mlPost(
      'https://preppal-2mb4.onrender.com/api/predict',
      body: {
        'type': 'product_forecast',
        'businessId': _apiClient.getBusinessId() ?? '',
      },
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      final data = body['data'] ?? [];
      if (data is List) {
        return data.cast<Map<String, dynamic>>();
      } else if (data is Map) {
        return [data as Map<String, dynamic>];
      }
      return [];
    } else {
      throw Exception(
          body['message'] ?? 'Failed to fetch product forecasts');
    }
  }

  @override
  Future<Map<String, dynamic>> getForecastAccuracy() async {
    // Get historical forecast accuracy (last 30 days)
    final response = await _apiClient.mlPost(
      'https://preppal-2mb4.onrender.com/api/predict',
      body: {
        'type': 'accuracy_metrics',
        'businessId': _apiClient.getBusinessId() ?? '',
        'days': 30,
      },
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return body['data'] ?? body;
    } else {
      // If ML service can't compute accuracy, return defaults
      return {
        'accuracy': 0.0,
        'daysAnalyzed': 30,
      };
    }
  }

  @override
  Future<Map<String, dynamic>> getAIInsights() async {
    // Get AI-generated insights about forecast patterns
    final response = await _apiClient.mlPost(
      'https://preppal-2mb4.onrender.com/api/predict',
      body: {
        'type': 'insights',
        'businessId': _apiClient.getBusinessId() ?? '',
      },
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return body['data'] ?? body;
    } else {
      // Return sensible default if ML service fails
      return {
        'message': 'AI insights pending',
        'type': 'info',
      };
    }
  }
}
