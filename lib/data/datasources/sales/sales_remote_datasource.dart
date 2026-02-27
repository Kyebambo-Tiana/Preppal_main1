import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:prepal2/data/models/sales/sale_model.dart';

abstract class SalesRemoteDataSource {
  Future<List<SaleModel>> getAllSales();
  Future<SaleModel> addSale(SaleModel sale);
}

class MockSalesRemoteDataSource implements SalesRemoteDataSource {
  // In-memory database — loaded once from JSON
  List<SaleModel> _mockDatabase = [];
  bool _initialized = false;

  Future<void> _initialize() async {
    if (_initialized) return;

    final jsonString =
        await rootBundle.loadString('assets/mock_data/sales.json');

    final List<dynamic> jsonList = json.decode(jsonString);

    _mockDatabase = jsonList.map((j) => SaleModel.fromJson(j)).toList();

    _initialized = true;
  }

  @override
  Future<List<SaleModel>> getAllSales() async {
    await Future.delayed(const Duration(milliseconds: 800));
    await _initialize();

    // Return sorted by date — most recent first
    final sorted = List<SaleModel>.from(_mockDatabase)
      ..sort((a, b) => b.date.compareTo(a.date));

    return sorted;
  }

  @override
  Future<SaleModel> addSale(SaleModel sale) async {
    await Future.delayed(const Duration(milliseconds: 800));
    await _initialize();

    _mockDatabase.add(sale);
    return sale;
  }
}
