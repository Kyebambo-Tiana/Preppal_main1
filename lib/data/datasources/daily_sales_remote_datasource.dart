import 'dart:convert';
import 'package:prepal2/core/network/api_client.dart';
import 'package:prepal2/core/network/api_constants.dart';

abstract class DailySalesRemoteDataSource {
  Future<List<Map<String, dynamic>>> getSalesForBusiness(String businessId);
  Future<Map<String, dynamic>> getSaleById(String id);
  Future<Map<String, dynamic>> addSale(Map<String, dynamic> saleData);
  Future<Map<String, dynamic>> updateSale(
    String id,
    Map<String, dynamic> updates,
  );
  Future<void> deleteSale(String id);
}

class DailySalesRemoteDataSourceImpl implements DailySalesRemoteDataSource {
  final ApiClient _apiClient;

  DailySalesRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<Map<String, dynamic>>> getSalesForBusiness(
    String businessId,
  ) async {
    final response = await _apiClient.get(
      ApiConstants.salesByBusiness(businessId),
    );
    final decoded = jsonDecode(response.body);
    final body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode == 200 && body['success'] == true) {
      final rawData = body['data'];
      if (rawData is List) {
        return rawData.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
      }
      if (rawData is Map<String, dynamic>) {
        return [rawData];
      }
      return [];
    } else if (body['success'] == false) {
      return []; // No sales yet — not an error
    } else {
      throw Exception(body['message'] ?? 'Failed to fetch sales');
    }
  }

  @override
  Future<Map<String, dynamic>> getSaleById(String id) async {
    final response = await _apiClient.get(ApiConstants.saleById(id));
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return body['data'] as Map<String, dynamic>;
    } else {
      throw Exception(body['message'] ?? 'Sale not found');
    }
  }

  @override
  Future<Map<String, dynamic>> addSale(Map<String, dynamic> saleData) async {
    final payload = <String, dynamic>{...saleData};

    // Ensure businessId is added to saleData if needed.
    final businessId = _apiClient.getBusinessId();
    if (businessId != null && !payload.containsKey('businessId')) {
      payload['businessId'] = businessId;
    }

    final response = await _apiClient.post(
      ApiConstants.salesCreate,
      body: payload,
    );
    final decoded = jsonDecode(response.body);
    final body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = body['data'];
      if (data is Map<String, dynamic>) {
        return data;
      }
      return payload;
    } else {
      throw Exception(body['message'] ?? 'Failed to add sale');
    }
  }

  @override
  Future<Map<String, dynamic>> updateSale(
    String id,
    Map<String, dynamic> updates,
  ) async {
    final response = await _apiClient.put(
      ApiConstants.saleUpdate(id),
      body: updates,
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return body['data'] as Map<String, dynamic>;
    } else {
      throw Exception(body['message'] ?? 'Failed to update sale');
    }
  }

  @override
  Future<void> deleteSale(String id) async {
    final response = await _apiClient.delete(ApiConstants.saleDelete(id));

    if (response.statusCode != 200 && response.statusCode != 204) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to delete sale');
    }
  }
}
