import 'package:prepal2/core/network/api_client.dart';
import 'package:prepal2/data/datasources/auth_remote_datasource.dart';
import 'package:prepal2/data/datasources/business_remote_datasource.dart';
import 'package:prepal2/data/datasources/daily_sales_remote_datasource.dart';
import 'package:prepal2/data/datasources/inventory/inventory_remote_datasource.dart';
import 'package:prepal2/data/datasources/forecast_remote_datasource.dart';
import 'package:prepal2/data/datasources/alerts_remote_datasource.dart';

class ServiceLocator {
  static final ServiceLocator _instance = ServiceLocator._internal();
  factory ServiceLocator() => _instance;
  ServiceLocator._internal();

  late ApiClient _apiClient;
  late AuthRemoteDataSource _authRemoteDataSource;
  late BusinessRemoteDataSource _businessRemoteDataSource;
  late DailySalesRemoteDataSource _dailySalesRemoteDataSource;
  late InventoryRemoteDataSource _inventoryRemoteDataSource;
  late ForecastRemoteDataSource _forecastRemoteDataSource;
  late AlertsRemoteDataSource _alertsRemoteDataSource;

  Future<void> init() async {
    _apiClient = ApiClient();
    await _apiClient.init();

    _authRemoteDataSource = AuthRemoteDataSourceImpl(_apiClient);
    _businessRemoteDataSource = BusinessRemoteDataSourceImpl(_apiClient);
    _dailySalesRemoteDataSource = DailySalesRemoteDataSourceImpl(_apiClient);
    _inventoryRemoteDataSource = InventoryRemoteDataSourceImpl(_apiClient);
    _forecastRemoteDataSource = ForecastRemoteDataSourceImpl(_apiClient);
    _alertsRemoteDataSource = AlertsRemoteDataSourceImpl(_apiClient);
  }

  ApiClient get apiClient => _apiClient;
  AuthRemoteDataSource get authRemoteDataSource => _authRemoteDataSource;
  BusinessRemoteDataSource get businessRemoteDataSource =>
      _businessRemoteDataSource;
  DailySalesRemoteDataSource get dailySalesRemoteDataSource =>
      _dailySalesRemoteDataSource;
  InventoryRemoteDataSource get inventoryRemoteDataSource =>
      _inventoryRemoteDataSource;
  ForecastRemoteDataSource get forecastRemoteDataSource =>
      _forecastRemoteDataSource;
  AlertsRemoteDataSource get alertsRemoteDataSource => _alertsRemoteDataSource;
}

final serviceLocator = ServiceLocator();

Future<void> setupServiceLocator() async {
  await serviceLocator.init();
}
