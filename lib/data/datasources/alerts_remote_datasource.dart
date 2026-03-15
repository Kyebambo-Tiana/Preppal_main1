import 'dart:convert';

import 'package:prepal2/core/network/api_client.dart';
import 'package:prepal2/core/network/api_constants.dart';

abstract class AlertsRemoteDataSource {
  Future<List<Map<String, dynamic>>> getAlertsForBusiness(String businessId);
  Future<Map<String, dynamic>> markAlertAsRead(String alertId);
  Future<void> deleteAlert(String alertId);
}

class AlertsRemoteDataSourceImpl implements AlertsRemoteDataSource {
  final ApiClient _apiClient;

  AlertsRemoteDataSourceImpl(this._apiClient);

  Map<String, dynamic> _decodeToMap(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      return <String, dynamic>{};
    } catch (_) {
      // Backend may return non-JSON body on some errors.
      return <String, dynamic>{'message': rawBody};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAlertsForBusiness(
    String businessId,
  ) async {
    if (businessId.trim().isEmpty) {
      return const [];
    }

    final response = await _apiClient.get(
      ApiConstants.alertsByBusiness(businessId),
    );
    final body = _decodeToMap(response.body);

    if (response.statusCode == 200) {
      final payload = body['data'] ?? body['alerts'] ?? body;
      if (payload is List) {
        return payload.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
      }
      if (payload is Map<String, dynamic>) {
        return [payload];
      }
      return const [];
    }

    if (response.statusCode == 404 || body['success'] == false) {
      return const [];
    }

    throw Exception(body['message'] ?? 'Failed to fetch alerts');
  }

  @override
  Future<Map<String, dynamic>> markAlertAsRead(String alertId) async {
    final response = await _apiClient.put(
      ApiConstants.alertUpdate(alertId),
      body: {'isRead': true},
    );

    final body = _decodeToMap(response.body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final payload = body['data'] ?? body;
      if (payload is Map<String, dynamic>) {
        return payload;
      }
      return {'id': alertId, 'isRead': true};
    }

    throw Exception(body['message'] ?? 'Failed to mark alert as read');
  }

  @override
  Future<void> deleteAlert(String alertId) async {
    final response = await _apiClient.delete(ApiConstants.alertDelete(alertId));

    if (response.statusCode != 200 && response.statusCode != 204) {
      final body = _decodeToMap(response.body);
      throw Exception(body['message'] ?? 'Failed to delete alert');
    }
  }
}
