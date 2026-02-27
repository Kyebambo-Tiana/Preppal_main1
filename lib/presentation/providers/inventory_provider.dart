// lib/presentation/providers/inventory_provider.dart

import 'package:flutter/material.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/domain/usecases/inventory_usecases.dart';

enum InventoryStatus { initial, loading, loaded, error }

class InventoryProvider extends ChangeNotifier {
  final GetAllProductsUseCase _getAllProducts;
  final AddProductUseCase _addProduct;
  final UpdateProductUseCase _updateProduct;
  final DeleteProductUseCase _deleteProduct;

  InventoryProvider({
    required GetAllProductsUseCase getAllProducts,
    required AddProductUseCase addProduct,
    required UpdateProductUseCase updateProduct,
    required DeleteProductUseCase deleteProduct,
  })  : _getAllProducts = getAllProducts,
        _addProduct = addProduct,
        _updateProduct = updateProduct,
        _deleteProduct = deleteProduct;

  // --- State ---
  InventoryStatus _status = InventoryStatus.initial;
  List<ProductModel> _products = [];
  String? _errorMessage;

  // Active filter/search state
  String _searchQuery = '';
  ProductCategory? _selectedCategory;

  // --- Getters ---
  InventoryStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == InventoryStatus.loading;

  // All products (unfiltered) — useful for dashboard stats
  List<ProductModel> get allProducts => _products;

  // Filtered products — what the inventory list screen shows
  List<ProductModel> get filteredProducts {
    return _products.where((product) {
      final matchesSearch = product.name
          .toLowerCase()
          .contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == null ||
              product.category == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  // Dashboard computed stats
  List<ProductModel> get lowStockProducts =>
      _products.where((p) => p.isLowStock).toList();

  List<ProductModel> get expiredProducts =>
      _products.where((p) => p.isExpired).toList();

  List<ProductModel> get expiringSoonProducts =>
      _products.where((p) => p.isExpiringSoon).toList();

  int get totalProducts => _products.length;

  // --- Actions ---
  Future<void> loadProducts() async {
    _status = InventoryStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      _products = await _getAllProducts.call();
      _status = InventoryStatus.loaded;
    } catch (e) {
      _errorMessage =
          e.toString().replaceAll('Exception: ', '');
      _status = InventoryStatus.error;
    }

    notifyListeners();
  }

  Future<bool> addProduct(ProductModel product) async {
    // set loading state so UI can display spinner / disable submit
    _status = InventoryStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final newProduct =
          await _addProduct.call(product);
      _products.add(newProduct);
      _status = InventoryStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage =
          e.toString().replaceAll('Exception: ', '');
      _status = InventoryStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(ProductModel product) async {
    try {
      final updated =
          await _updateProduct.call(product);
      final index = _products
          .indexWhere((p) => p.id == updated.id);

      if (index != -1) {
        _products[index] = updated;
        notifyListeners();
      }

      return true;
    } catch (e) {
      _errorMessage =
          e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    try {
      await _deleteProduct.call(productId);
      _products.removeWhere(
          (p) => p.id == productId);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage =
          e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // --- Filtering ---
  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(ProductCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    notifyListeners();
  }

  void reset() {
    _status = InventoryStatus.initial;
    _products = [];
    _errorMessage = null;
    _searchQuery = '';
    _selectedCategory = null;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
