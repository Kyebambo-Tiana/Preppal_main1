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

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return fallback;
  }

  // Backends may return accuracy either as ratio (0.87) or percent (87).
  // Normalize to ratio so UI rendering remains consistent.
  double _normalizeAccuracyToRatio(dynamic value) {
    final raw = _toDouble(value);
    if (raw <= 0) return 0;
    if (raw > 1) return (raw / 100).clamp(0.0, 1.0);
    return raw.clamp(0.0, 1.0);
  }

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
  String get aiInsight => _forecastData?.aiInsight ?? 'AI insights pending';

  /// Load all forecast data from ML service
  Future<void> loadForecastData() async {
    _status = ForecastStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      var hadAnyFailure = false;

      // Keep the page usable even if one ML endpoint has no data yet.
      final sevenDay = await _dataSource.get7DayForecast().catchError((_) {
        hadAnyFailure = true;
        return <String, dynamic>{'days': <Map<String, dynamic>>[]};
      });

      final productForecasts = await _dataSource
          .getProductForecasts()
          .catchError((_) {
            hadAnyFailure = true;
            return <Map<String, dynamic>>[];
          });

      final accuracy = await _dataSource.getForecastAccuracy().catchError((_) {
        hadAnyFailure = true;
        return <String, dynamic>{'accuracy': 0.0, 'daysAnalyzed': 0};
      });

      final insights = await _dataSource.getAIInsights().catchError((_) {
        hadAnyFailure = true;
        return <String, dynamic>{
          'message': 'No AI insight available yet from backend.',
          'type': 'info',
        };
      });

      // Format 7-day forecast data
      final sevenDayList = _formatSevenDayForecast(sevenDay);

      // Extract accuracy percentage
      final accuracyPercent = _normalizeAccuracyToRatio(accuracy['accuracy']);

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

      if (hadAnyFailure) {
        _errorMessage = 'Some forecast metrics are unavailable right now.';
      }

      _status = ForecastStatus.loaded;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      _status = ForecastStatus.error;
      print('ForecastProvider error: $_errorMessage');
    }

    notifyListeners();
  }

  /// Format ML response into 7-day forecast structure
  List<Map<String, dynamic>> _formatSevenDayForecast(
    Map<String, dynamic> data,
  ) {
    // ML service should return data in format: {days: [{day, actual, predicted}]}
    final daysData = data['days'] as List?;

    if (daysData == null || daysData.isEmpty) {
      // Fallback: return empty list or default structure
      return [];
    }

    return daysData
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
