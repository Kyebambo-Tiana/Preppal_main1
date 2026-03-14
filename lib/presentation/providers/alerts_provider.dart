import 'package:flutter/material.dart';
import 'package:prepal2/core/di/service_locator.dart';

enum AlertsStatus { initial, loading, loaded, error }

class AppAlert {
  final String id;
  final String productName;
  final String message;
  final String severity;
  final bool isRead;
  final DateTime? createdAt;

  const AppAlert({
    required this.id,
    required this.productName,
    required this.message,
    required this.severity,
    required this.isRead,
    required this.createdAt,
  });

  AppAlert copyWith({
    String? id,
    String? productName,
    String? message,
    String? severity,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppAlert(
      id: id ?? this.id,
      productName: productName ?? this.productName,
      message: message ?? this.message,
      severity: severity ?? this.severity,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory AppAlert.fromMap(Map<String, dynamic> map) {
    final rawSeverity =
        (map['severity'] ?? map['level'] ?? map['priority'] ?? 'Low')
            .toString();

    return AppAlert(
      id: (map['id'] ?? map['_id'] ?? '').toString(),
      productName:
          (map['productName'] ?? map['title'] ?? map['name'] ?? 'Alert')
              .toString(),
      message: (map['message'] ?? map['description'] ?? map['body'] ?? '')
          .toString(),
      severity: _normalizeSeverity(rawSeverity),
      isRead:
          (map['isRead'] == true) ||
          (map['read'] == true) ||
          (map['status']?.toString().toLowerCase() == 'read'),
      createdAt: _tryParseDate(
        (map['createdAt'] ?? map['created_at'] ?? map['date'])?.toString(),
      ),
    );
  }

  static String _normalizeSeverity(String value) {
    final v = value.toLowerCase();
    if (v == 'high' || v == 'critical') return 'High';
    if (v == 'medium' || v == 'warning') return 'Medium';
    return 'Low';
  }

  static DateTime? _tryParseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateTime.tryParse(value);
  }
}

class AlertsProvider extends ChangeNotifier {
  AlertsStatus _status = AlertsStatus.initial;
  String? _errorMessage;
  List<AppAlert> _alerts = [];

  AlertsStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == AlertsStatus.loading;
  List<AppAlert> get alerts => _alerts;

  Future<void> loadAlerts(String businessId) async {
    _status = AlertsStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final ds = serviceLocator.alertsRemoteDataSource;
      final raw = await ds.getAlertsForBusiness(businessId);
      _alerts = raw.map(AppAlert.fromMap).toList(growable: false);
      _status = AlertsStatus.loaded;
    } catch (e) {
      _errorMessage = _clean(e);
      _alerts = [];
      _status = AlertsStatus.error;
    }

    notifyListeners();
  }

  Future<bool> markAsRead(String alertId) async {
    try {
      final ds = serviceLocator.alertsRemoteDataSource;
      await ds.markAlertAsRead(alertId);

      final index = _alerts.indexWhere((a) => a.id == alertId);
      if (index != -1) {
        _alerts[index] = _alerts[index].copyWith(isRead: true);
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = _clean(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteAlert(String alertId) async {
    try {
      final ds = serviceLocator.alertsRemoteDataSource;
      await ds.deleteAlert(alertId);
      _alerts = _alerts.where((a) => a.id != alertId).toList(growable: false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _clean(e);
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _clean(Object e) => e.toString().replaceAll('Exception: ', '');
}
