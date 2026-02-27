import 'dart:convert';
import 'package:prepal2/core/network/api_client.dart';
import 'package:prepal2/core/network/api_constants.dart';

abstract class BusinessRemoteDataSource {
  Future<Map<String, dynamic>> createBusiness({
    required String businessName,
    required String businessType,
    required String location,
  });
  Future<List<Map<String, dynamic>>> getAllBusinesses();
  Future<Map<String, dynamic>> getBusinessById(String id);
  Future<Map<String, dynamic>> updateBusiness({
    required String id,
    required Map<String, dynamic> updates,
  });
  Future<void> deleteBusiness(String id);
}

class BusinessRemoteDataSourceImpl implements BusinessRemoteDataSource {
  final ApiClient _apiClient;

  BusinessRemoteDataSourceImpl(this._apiClient);

  @override
  Future<Map<String, dynamic>> createBusiness({
    required String businessName,
    required String businessType,
    required String location,
  }) async {
    final response = await _apiClient.post(
      ApiConstants.businessCreate,
      body: {
        'businessName': businessName,
        'businessType': businessType,
        'location': location,
      },
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = body['data'] as Map<String, dynamic>;
      if (data['id'] != null) {
        await _apiClient.setBusinessId(data['id'] as String);
      }
      return data;
    } else {
      if (body['errors'] != null) {
        final errors = (body['errors'] as List)
            .map((e) => (e as Map)['message'])
            .join(', ');
        throw Exception(errors);
      }
      throw Exception(body['message'] ?? 'Failed to create business');
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getAllBusinesses() async {
    final response = await _apiClient.get(ApiConstants.businessGetAll);
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    // The server returns 404 with a message like "Error fetching business:
    // Business not found" when the user has not created any businesses yet.
    // Treat that as an empty list so the UI can ask for business details.
    if (response.statusCode == 404 || body['success'] == false) {
      return [];
    }

    if (response.statusCode == 200 && body['success'] == true) {
      final rawData = body['data'];

      List<dynamic> list;
      if (rawData is List) {
        list = rawData;
      } else if (rawData is Map) {
        list = [rawData];
      } else {
        list = [];
      }

      final businesses = list.cast<Map<String, dynamic>>();

      if (businesses.isNotEmpty && businesses.first['id'] != null) {
        await _apiClient.setBusinessId(businesses.first['id'] as String);
      }

      return businesses;
    }

    throw Exception(body['message'] ?? 'Failed to fetch businesses');
  }

  @override
  Future<Map<String, dynamic>> getBusinessById(String id) async {
    final response = await _apiClient.get(ApiConstants.businessGetById(id));
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception(body['message'] ?? 'Business not found');
  }

  @override
  Future<Map<String, dynamic>> updateBusiness({
    required String id,
    required Map<String, dynamic> updates,
  }) async {
    final response = await _apiClient.put(
      ApiConstants.businessUpdate(id),
      body: updates,
    );
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      return body['data'] as Map<String, dynamic>;
    }
    throw Exception(body['message'] ?? 'Failed to update business');
  }

  @override
  Future<void> deleteBusiness(String id) async {
    final response = await _apiClient.delete(ApiConstants.businessDelete(id));

    if (response.statusCode != 200 && response.statusCode != 204) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      throw Exception(body['message'] ?? 'Failed to delete business');
    }
  }
}
