import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:prepal2/core/di/service_locator.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DailySalesStatus { initial, loading, loaded, error }

class DailySalesProvider extends ChangeNotifier {
  static const String _kCachedSales = 'cached_daily_sales';
  static const String _kAuthUserKey = 'auth_user';

  DailySalesStatus _status = DailySalesStatus.initial;
  String? _errorMessage;
  List<Map<String, dynamic>> _sales = [];

  DailySalesProvider() {
    _hydrateFromCache();
  }

  DailySalesStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == DailySalesStatus.loading;
  List<Map<String, dynamic>> get sales => _sales;

  String _scopedKey(String suffix) => '${_kCachedSales}_$suffix';

  Future<String?> _cacheScope({
    SharedPreferences? prefs,
    String? businessIdOverride,
  }) async {
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
        businessIdOverride ??
        serviceLocator.apiClient.getBusinessId() ??
        preferences.getString('business_id');

    if (userId == null && (businessId == null || businessId.isEmpty)) {
      return null;
    }

    return '${userId ?? 'anonymous'}_${businessId ?? 'no_business'}';
  }

  Future<void> _hydrateFromCache({String? businessIdOverride}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final scope = await _cacheScope(
        prefs: prefs,
        businessIdOverride: businessIdOverride,
      );
      final raw = scope == null
          ? prefs.getString(_kCachedSales)
          : prefs.getString(_scopedKey(scope)) ??
                prefs.getString(_kCachedSales);

      if (raw == null || raw.isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      _sales = decoded
          .whereType<Map<String, dynamic>>()
          .map((sale) => Map<String, dynamic>.from(sale))
          .toList(growable: false);
      _status = DailySalesStatus.loaded;
      notifyListeners();
    } catch (_) {
      // Ignore malformed local cache and continue with remote fetches.
    }
  }

  Future<void> _saveCache({String? businessIdOverride}) async {
    final prefs = await SharedPreferences.getInstance();
    final scope = await _cacheScope(
      prefs: prefs,
      businessIdOverride: businessIdOverride,
    );
    final key = scope == null ? _kCachedSales : _scopedKey(scope);
    await prefs.setString(key, jsonEncode(_sales));
  }

  Future<void> clearPersistedCache() async {
    final prefs = await SharedPreferences.getInstance();
    final scope = await _cacheScope(prefs: prefs);
    if (scope != null) {
      await prefs.remove(_scopedKey(scope));
    }
    await prefs.remove(_kCachedSales);
  }

  Future<void> loadSalesForBusiness(String businessId) async {
    if (_sales.isEmpty) {
      await _hydrateFromCache(businessIdOverride: businessId);
    }

    final hadCachedSales = _sales.isNotEmpty;
    _status = DailySalesStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final ds = serviceLocator.dailySalesRemoteDataSource;
      final result = await ds.getSalesForBusiness(businessId);
      if (result.isNotEmpty || !hadCachedSales) {
        _sales = result;
        await _saveCache(businessIdOverride: businessId);
      }
      _status = DailySalesStatus.loaded;
    } catch (e) {
      _errorMessage = _clean(e);
      _status = hadCachedSales
          ? DailySalesStatus.loaded
          : DailySalesStatus.error;
    }

    notifyListeners();
  }

  Future<bool> addSale(Map<String, dynamic> saleData) async {
    try {
      final ds = serviceLocator.dailySalesRemoteDataSource;
      final newSale = await ds.addSale(saleData);
      // Wait, let's prepend the new sale to current sales list
      _sales.insert(0, newSale);
      await _saveCache(businessIdOverride: saleData['businessId'] as String?);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _clean(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateSale(String id, Map<String, dynamic> updates) async {
    try {
      final ds = serviceLocator.dailySalesRemoteDataSource;
      final updatedSale = await ds.updateSale(id, updates);

      final index = _sales.indexWhere((s) => s['id'] == id);
      if (index != -1) {
        _sales[index] = updatedSale;
        await _saveCache();
        notifyListeners();
      }
      return true;
    } catch (e) {
      _errorMessage = _clean(e);
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteSale(String id) async {
    try {
      final ds = serviceLocator.dailySalesRemoteDataSource;
      await ds.deleteSale(id);
      _sales.removeWhere((s) => s['id'] == id);
      await _saveCache();
      notifyListeners();
    } catch (e) {
      _errorMessage = _clean(e);
      notifyListeners();
    }
  }

  void reset() {
    _status = DailySalesStatus.initial;
    _errorMessage = null;
    _sales = [];
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  String _clean(Object e) => e.toString().replaceAll('Exception: ', '');
}
