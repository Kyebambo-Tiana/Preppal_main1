// lib/presentation/providers/forecast_provider.dart

import 'package:flutter/material.dart';
import 'package:prepal2/data/datasources/forecast_remote_datasource.dart';

enum ForecastStatus { initial, loading, loaded, error }

class ForecastData {
  final List<Map<String, dynamic>> sevenDayForecast;
  final List<Map<String, dynamic>> productForecasts;
  final double forecastAccuracy;
  final String aiInsight;

  const ForecastData({
    required this.sevenDayForecast,
    required this.productForecasts,
    required this.forecastAccuracy,
    required this.aiInsight,
  });
}

class ForecastProvider extends ChangeNotifier {
  final ForecastRemoteDataSource _dataSource;

  ForecastProvider(this._dataSource);

  ForecastStatus _status = ForecastStatus.initial;
  String? _errorMessage;
  ForecastData? _forecastData;

  ForecastStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == ForecastStatus.loading;
  ForecastData? get forecastData => _forecastData;

  // Get 7-day forecast with proper formatting
  List<Map<String, dynamic>> get sevenDayForecast =>
      _forecastData?.sevenDayForecast ?? [];

  // Get product forecasts
  List<Map<String, dynamic>> get productForecasts =>
      _forecastData?.productForecasts ?? [];

  // Get forecast accuracy percentage
  double get forecastAccuracy => _forecastData?.forecastAccuracy ?? 0.0;

  // Get AI generated insight
  String get aiInsight =>
      _forecastData?.aiInsight ?? 'AI insights pending';

  /// Load all forecast data from ML service
  Future<void> loadForecastData() async {
    _status = ForecastStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      // Fetch all forecast data in parallel
      final sevenDayFuture = _dataSource.get7DayForecast();
      final productForecastsFuture = _dataSource.getProductForecasts();
      final accuracyFuture = _dataSource.getForecastAccuracy();
      final insightsFuture = _dataSource.getAIInsights();

      final results = await Future.wait([
        sevenDayFuture,
        productForecastsFuture,
        accuracyFuture,
        insightsFuture,
      ]);

      final sevenDay = results[0] as Map<String, dynamic>;
      final productForecasts = results[1] as List<Map<String, dynamic>>;
      final accuracy = results[2] as Map<String, dynamic>;
      final insights = results[3] as Map<String, dynamic>;

      // Format 7-day forecast data
      final sevenDayList = _formatSevenDayForecast(sevenDay);

      // Extract accuracy percentage
      final accuracyPercent =
          (accuracy['accuracy'] as num?)?.toDouble() ?? 0.0;

      // Extract AI insight message
      final insightMessage =
          (insights['message'] as String?) ??
          'Weekend demand expected to increase';

      _forecastData = ForecastData(
        sevenDayForecast: sevenDayList,
        productForecasts: productForecasts,
        forecastAccuracy: accuracyPercent,
        aiInsight: insightMessage,
      );

      _status = ForecastStatus.loaded;
    } catch (e) {
      _errorMessage =
          e.toString().replaceAll('Exception: ', '');
      _status = ForecastStatus.error;
      print('ForecastProvider error: $_errorMessage');
    }

    notifyListeners();
  }

  /// Format ML response into 7-day forecast structure
  List<Map<String, dynamic>> _formatSevenDayForecast(
      Map<String, dynamic> data) {
    // ML service should return data in format: {days: [{day, actual, predicted}]}
    final daysData = data['days'] as List?;

    if (daysData == null || daysData.isEmpty) {
      // Fallback: return empty list or default structure
      return [];
    }

    return daysData.cast<Map<String, dynamic>>();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
