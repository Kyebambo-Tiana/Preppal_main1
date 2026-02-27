// lib/domain/usecases/inventory_usecases.dart

import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/domain/repositories/inventory_repository.dart';

class GetAllProductsUseCase {
  final InventoryRepository repository;

  GetAllProductsUseCase({required this.repository});

  Future<List<ProductModel>> call() => repository.getAllProducts();
}

class AddProductUseCase {
  final InventoryRepository repository;

  AddProductUseCase({required this.repository});

  Future<ProductModel> call(ProductModel product) async {
    // Domain validation
    if (product.name.isEmpty) throw Exception('Product name is required');

    if (product.quantityAvailable < 0) {
      throw Exception('Quantity cannot be negative');
    }

    if (product.shelfLife < 0) {
      throw Exception('Shelf life cannot be negative');
    }

    return repository.addProduct(product);
  }
}

class UpdateProductUseCase {
  final InventoryRepository repository;

  UpdateProductUseCase({required this.repository});

  Future<ProductModel> call(ProductModel product) async {
    if (product.name.isEmpty) throw Exception('Product name is required');

    if (product.quantityAvailable < 0) {
      throw Exception('Quantity cannot be negative');
    }

    return repository.updateProduct(product);
  }
}

class DeleteProductUseCase {
  final InventoryRepository repository;

  DeleteProductUseCase({required this.repository});

  Future<void> call(String productId) =>
      repository.deleteProduct(productId);
}
