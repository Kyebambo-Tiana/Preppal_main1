import 'package:flutter/material.dart';
import 'package:prepal2/core/di/service_locator.dart';

enum DailySalesStatus { initial, loading, loaded, error }

class DailySalesProvider extends ChangeNotifier {
  DailySalesStatus _status = DailySalesStatus.initial;
  String? _errorMessage;
  List<Map<String, dynamic>> _sales = [];

  DailySalesStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _status == DailySalesStatus.loading;
  List<Map<String, dynamic>> get sales => _sales;

  Future<void> loadSalesForBusiness(String businessId) async {
    _status = DailySalesStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final ds = serviceLocator.dailySalesRemoteDataSource;
      final result = await ds.getSalesForBusiness(businessId);
      _sales = result;
      _status = DailySalesStatus.loaded;
    } catch (e) {
      _errorMessage = _clean(e);
      _status = DailySalesStatus.error;
    }

    notifyListeners();
  }

  Future<bool> addSale(Map<String, dynamic> saleData) async {
    try {
      final ds = serviceLocator.dailySalesRemoteDataSource;
      final newSale = await ds.addSale(saleData);
      // Wait, let's prepend the new sale to current sales list
      _sales.insert(0, newSale);
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
