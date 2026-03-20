// lib/presentation/providers/inventory_provider.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:prepal2/core/di/service_locator.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/domain/usecases/inventory_usecases.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum InventoryStatus { initial, loading, loaded, error }

class InventoryProvider extends ChangeNotifier {
  static const String _kCachedProducts = 'cached_inventory_products';
  static const String _kAuthUserKey = 'auth_user';

  final GetAllProductsUseCase _getAllProducts;
  final AddProductUseCase _addProduct;
  final UpdateProductUseCase _updateProduct;
  final DeleteProductUseCase _deleteProduct;

  InventoryProvider({
    required GetAllProductsUseCase getAllProducts,
    required AddProductUseCase addProduct,
    required UpdateProductUseCase updateProduct,
    required DeleteProductUseCase deleteProduct,
  }) : _getAllProducts = getAllProducts,
       _addProduct = addProduct,
       _updateProduct = updateProduct,
       _deleteProduct = deleteProduct {
    _hydrateFromCache();
  }

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
      final matchesSearch = product.name.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );

      final matchesCategory =
          _selectedCategory == null || product.category == _selectedCategory;

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

  String _scopedKey(String suffix) => '${_kCachedProducts}_$suffix';

  Future<String?> _cacheScope([SharedPreferences? prefs]) async {
    final preferences = prefs ?? await SharedPreferences.getInstance();

    String? userId;
    final rawUser = preferences.getString(_kAuthUserKey);
    if (rawUser != null && rawUser.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawUser);
        if (decoded is Map<String, dynamic>) {
          final id = decoded['id'] as String?;
          if (id != null && id.trim().isNotEmpty) {
            userId = id.trim();
          }
        }
      } catch (_) {
        // Ignore malformed cached auth payloads.
      }
    }

    final businessId =
        serviceLocator.apiClient.getBusinessId() ??
        preferences.getString('business_id');

    if (userId == null && (businessId == null || businessId.isEmpty)) {
      return null;
    }

    return '${userId ?? 'anonymous'}_${businessId ?? 'no_business'}';
  }

  Future<void> _hydrateFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scope = await _cacheScope(prefs);
      final raw = scope == null
          ? prefs.getString(_kCachedProducts)
          : prefs.getString(_scopedKey(scope)) ??
                prefs.getString(_kCachedProducts);

      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final cached = decoded
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList(growable: true);

      if (cached.isEmpty) return;

      _products = cached;
      _status = InventoryStatus.loaded;
      notifyListeners();
    } catch (_) {
      // Ignore malformed local cache and continue with remote fetches.
    }
  }

  Future<void> _saveCache() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = await _cacheScope(prefs);
    final key = scope == null ? _kCachedProducts : _scopedKey(scope);
    final payload = jsonEncode(
      _products.map((product) => product.toJson()).toList(growable: false),
    );
    await prefs.setString(key, payload);
  }

  Future<void> clearPersistedCache() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = await _cacheScope(prefs);
    if (scope != null) {
      await prefs.remove(_scopedKey(scope));
    }
    await prefs.remove(_kCachedProducts);
  }

  // --- Actions ---
  Future<void> loadProducts() async {
    if (_products.isEmpty) {
      await _hydrateFromCache();
    }

    final hadCachedProducts = _products.isNotEmpty;
    _status = InventoryStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final remoteProducts = await _getAllProducts.call();
      if (remoteProducts.isNotEmpty || !hadCachedProducts) {
        _products = remoteProducts;
        await _saveCache();
      }
      _status = InventoryStatus.loaded;
    } catch (e) {
      _errorMessage = _cleanApiError(e);
      _status = hadCachedProducts
          ? InventoryStatus.loaded
          : InventoryStatus.error;
    }

    notifyListeners();
  }

  Future<bool> addProduct(ProductModel product) async {
    // set loading state so UI can display spinner / disable submit
    _status = InventoryStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final newProduct = await _addProduct.call(product);
      _products.add(newProduct);
      await _saveCache();
      _status = InventoryStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanApiError(e);
      _status = InventoryStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProduct(ProductModel product) async {
    _status = InventoryStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final updated = await _updateProduct.call(product);
      final index = _products.indexWhere((p) => p.id == updated.id);

      if (index != -1) {
        _products[index] = updated;
      }

      await _saveCache();
      _status = InventoryStatus.loaded;
      notifyListeners();

      return true;
    } catch (e) {
      _errorMessage = _cleanApiError(e);
      _status = InventoryStatus.error;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProduct(String productId) async {
    _status = InventoryStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      await _deleteProduct.call(productId);
      _products.removeWhere((p) => p.id == productId);
      await _saveCache();
      _status = InventoryStatus.loaded;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _cleanApiError(e);
      _status = InventoryStatus.error;
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

  String _cleanApiError(Object e) {
    final raw = e.toString().replaceAll('Exception: ', '').trim();

    // Keep user-facing errors concise if backend includes full JSON payloads.
    if (raw.startsWith('{') && raw.endsWith('}')) {
      final messageMatch = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(raw);
      if (messageMatch != null) {
        return messageMatch.group(1)!;
      }

      final detailMsgMatch = RegExp(r'"msg"\s*:\s*"([^"]+)"').firstMatch(raw);
      if (detailMsgMatch != null) {
        return detailMsgMatch.group(1)!;
      }
    }

    return raw;
  }
}
