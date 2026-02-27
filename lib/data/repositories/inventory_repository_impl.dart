// lib/data/repositories/inventory_repository_impl.dart

import 'package:prepal2/data/datasources/inventory/inventory_remote_datasource.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/domain/repositories/inventory_repository.dart';

class InventoryRepositoryImpl implements InventoryRepository {
  final InventoryRemoteDataSource remoteDataSource;

  InventoryRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<ProductModel>> getAllProducts() async {
    try {
      return await remoteDataSource.getAllProducts();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ProductModel> addProduct(ProductModel product) async {
    try {
      return await remoteDataSource.addProduct(product);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ProductModel> updateProduct(ProductModel product) async {
    try {
      return await remoteDataSource.updateProduct(product);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> deleteProduct(String productId) async {
    try {
      await remoteDataSource.deleteProduct(productId);
    } catch (e) {
      rethrow;
    }
  }
}
