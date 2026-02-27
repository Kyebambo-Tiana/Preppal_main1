// lib/domain/repositories/inventory_repository.dart
// Abstract contract for inventory operations

import 'package:prepal2/data/models/inventory/product_model.dart';

abstract class InventoryRepository {
  Future<List<ProductModel>> getAllProducts();
  Future<ProductModel> addProduct(ProductModel product);
  Future<ProductModel> updateProduct(ProductModel product);
  Future<void> deleteProduct(String productId);
}
