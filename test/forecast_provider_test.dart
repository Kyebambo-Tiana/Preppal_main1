import 'package:flutter_test/flutter_test.dart';
import 'package:prepal2/data/datasources/forecast_remote_datasource.dart';
import 'package:prepal2/presentation/providers/forecast_provider.dart';

class _FakeForecastRemoteDataSource implements ForecastRemoteDataSource {
  Map<String, dynamic> sevenDayResponse;
  List<Map<String, dynamic>> productForecastResponse;
  Map<String, dynamic> accuracyResponse;
  Map<String, dynamic> insightResponse;

  bool failSevenDay;
  bool failProducts;
  bool failAccuracy;
  bool failInsights;

  _FakeForecastRemoteDataSource({
    Map<String, dynamic>? sevenDayResponse,
    List<Map<String, dynamic>>? productForecastResponse,
    Map<String, dynamic>? accuracyResponse,
    Map<String, dynamic>? insightResponse,
    this.failSevenDay = false,
    this.failProducts = false,
    this.failAccuracy = false,
    this.failInsights = false,
  }) : sevenDayResponse =
           sevenDayResponse ??
           {
             'days': [
               {'day': 'Mon', 'actual': 100, 'predicted': 110},
             ],
           },
       productForecastResponse =
           productForecastResponse ??
           [
             {
               'name': 'Puff Puff',
               'today': 20,
               'tomorrow': 24,
               'confidence': 85,
             },
           ],
       accuracyResponse = accuracyResponse ?? {'accuracy': 87},
       insightResponse =
           insightResponse ?? {'message': 'Weekend demand likely to increase.'};

  @override
  Future<Map<String, dynamic>> get7DayForecast() async {
    if (failSevenDay) throw Exception('7-day endpoint failed');
    return sevenDayResponse;
  }

  @override
  Future<List<Map<String, dynamic>>> getProductForecasts() async {
    if (failProducts) throw Exception('product endpoint failed');
    return productForecastResponse;
  }

  @override
  Future<Map<String, dynamic>> getForecastAccuracy() async {
    if (failAccuracy) throw Exception('accuracy endpoint failed');
    return accuracyResponse;
  }

  @override
  Future<Map<String, dynamic>> getAIInsights() async {
    if (failInsights) throw Exception('insight endpoint failed');
    return insightResponse;
  }
}

void main() {
  group('ForecastProvider', () {
    test(
      'loads forecast data and normalizes percent accuracy to ratio',
      () async {
        final fakeDs = _FakeForecastRemoteDataSource(
          accuracyResponse: {'accuracy': 87},
        );
        final provider = ForecastProvider(fakeDs);

        await provider.loadForecastData();

        expect(provider.status, ForecastStatus.loaded);
        expect(provider.forecastData, isNotNull);
        expect(provider.errorMessage, isNull);
        expect(provider.sevenDayForecast, isNotEmpty);
        expect(provider.productForecasts, isNotEmpty);
        expect(provider.forecastAccuracy, closeTo(0.87, 0.0001));
        expect(provider.aiInsight, 'Weekend demand likely to increase.');
      },
    );

    test('keeps screen usable when one endpoint fails', () async {
      final fakeDs = _FakeForecastRemoteDataSource(failProducts: true);
      final provider = ForecastProvider(fakeDs);

      await provider.loadForecastData();

      expect(provider.status, ForecastStatus.loaded);
      expect(provider.forecastData, isNotNull);
      expect(
        provider.errorMessage,
        'Some forecast metrics are unavailable right now.',
      );
      expect(provider.productForecasts, isEmpty);
      expect(provider.sevenDayForecast, isNotEmpty);
    });

    test('handles ratio accuracy directly without re-scaling', () async {
      final fakeDs = _FakeForecastRemoteDataSource(
        accuracyResponse: {'accuracy': 0.92},
      );
      final provider = ForecastProvider(fakeDs);

      await provider.loadForecastData();

      expect(provider.status, ForecastStatus.loaded);
      expect(provider.forecastAccuracy, closeTo(0.92, 0.0001));
    });

    test('falls back safely when 7-day, accuracy and insights fail', () async {
      final fakeDs = _FakeForecastRemoteDataSource(
        failSevenDay: true,
        failAccuracy: true,
        failInsights: true,
      );
      final provider = ForecastProvider(fakeDs);

      await provider.loadForecastData();

      expect(provider.status, ForecastStatus.loaded);
      expect(provider.sevenDayForecast, isEmpty);
      expect(provider.forecastAccuracy, 0.0);
      expect(provider.aiInsight, 'No AI insight available yet from backend.');
      expect(
        provider.errorMessage,
        'Some forecast metrics are unavailable right now.',
      );
    });
  });
}
