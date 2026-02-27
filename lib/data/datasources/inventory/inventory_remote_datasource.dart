import 'dart:convert';
import 'package:prepal2/core/network/api_client.dart';
import 'package:prepal2/core/network/api_constants.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';

abstract class InventoryRemoteDataSource {
  Future<List<ProductModel>> getAllProducts();
  Future<ProductModel> addProduct(ProductModel product);
  Future<ProductModel> updateProduct(ProductModel product);
  Future<void> deleteProduct(String productId);
}

class InventoryRemoteDataSourceImpl implements InventoryRemoteDataSource {
  final ApiClient _apiClient;

  InventoryRemoteDataSourceImpl(this._apiClient);

  @override
  Future<List<ProductModel>> getAllProducts() async {
    // Assuming we fetch inventory for the user's selected business.
    final businessId = _apiClient.getBusinessId();
    if (businessId == null) {
      throw Exception('Business ID not found in ApiClient. Please select a business.');
    }

    final response = await _apiClient.get(
      ApiConstants.inventoryByBusiness(businessId),
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200) {
      // Typically returns an array directly, or wrapped in 'data'
      final dynamic rawData = body['data'] ?? body;
      if (rawData is List) {
        return rawData
            .map((j) => ProductModel.fromJson(j as Map<String, dynamic>))
            .where((p) => p.isActive)
            .toList();
      }
      return [];
    } else {
      throw Exception(body['message'] ?? 'Failed to load products');
    }
  }

  @override
  Future<ProductModel> addProduct(ProductModel product) async {
    final businessId = _apiClient.getBusinessId();
    if (businessId == null) {
      throw Exception('No selected business ID found.');
    }

    // use toApiJson to avoid sending internal/legacy keys that the server
    // rejects (id, name, category, etc). we also must attach the businessId
    // levied by the backend validation.
    final Map<String, dynamic> requestBody = product.toApiJson();
    requestBody['businessId'] = businessId;

    final response = await _apiClient.post(
      ApiConstants.inventoryCreate,
      body: requestBody,
    );
    
    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
       final data = body['data'] ?? body;
       return ProductModel.fromJson(data as Map<String, dynamic>);
    } else {
       throw Exception(body['message'] ?? 'Failed to add product');
    }
  }

  @override
  Future<ProductModel> updateProduct(ProductModel product) async {
    final businessId = _apiClient.getBusinessId();
    if (businessId == null) {
      throw Exception('No selected business ID found.');
    }

    // the backend only cares about the same fields used when creating a
    // product; any extra keys will trigger validation errors. we also
    // pass the businessId because the server validates it on update as
    // well (despite it being part of the URL).
    final Map<String, dynamic> requestBody = product.toApiJson();
    requestBody['businessId'] = businessId;

    final response = await _apiClient.put(
      ApiConstants.inventoryUpdate(product.id),
      body: requestBody,
    );

    final body = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode == 200 || response.statusCode == 201) {
       final data = body['data'] ?? body;
       return ProductModel.fromJson(data as Map<String, dynamic>);
    } else {
       throw Exception(body['message'] ?? 'Failed to update product');
    }
  }

  @override
  Future<void> deleteProduct(String productId) async {
    final response = await _apiClient.delete(
      ApiConstants.inventoryDelete(productId),
    );

    if (response.statusCode != 200 && response.statusCode != 204) {
       final body = jsonDecode(response.body) as Map<String, dynamic>;
       throw Exception(body['message'] ?? 'Failed to delete product');
    }
  }
}
