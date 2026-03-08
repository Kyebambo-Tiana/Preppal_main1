import 'package:flutter/material.dart';
import 'package:prepal2/core/di/service_locator.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';

class DashboardAlert {
  final String productName;
  final String message;
  final String severity; // "High", "Medium", "Low"
  const DashboardAlert({
    required this.productName,
    required this.message,
    required this.severity,
  });
}

class DashboardRecommendation {
  final String productName;
  final String message;
  const DashboardRecommendation({
    required this.productName,
    required this.message,
  });
}

class DashboardProvider extends ChangeNotifier {
  List<ProductModel> _products = [];
  String _inventorySignature = '';
  double _todayRevenue = 0;
  double _yesterdayRevenue = 0;
  bool _isLoadingSales = false;
  String? _salesError;

  bool get isLoadingSales => _isLoadingSales;
  String? get salesError => _salesError;

  //Call this whenever inventory loads/changes
  void syncInventory(List<ProductModel> products) {
    final nextSignature = products
        .map(
          (p) =>
              '${p.id}:${p.quantityAvailable}:${p.productionDate.toIso8601String()}',
        )
        .join('|');

    if (_inventorySignature == nextSignature) {
      return;
    }

    _inventorySignature = nextSignature;
    _products = products;
    notifyListeners();
  }

  //Load today's & yesterday's sales from API
  Future<void> loadSales(String businessId) async {
    _isLoadingSales = true;
    _salesError = null;
    notifyListeners();

    try {
      final ds = serviceLocator.dailySalesRemoteDataSource;
      final raw = await ds.getSalesForBusiness(businessId);

      final today = _dateStr(DateTime.now());
      final yesterday = _dateStr(
        DateTime.now().subtract(const Duration(days: 1)),
      );

      double todayTotal = 0;
      double yesterdayTotal = 0;

      for (final sale in raw) {
        final dateVal =
            sale['date'] as String? ?? sale['createdAt'] as String? ?? '';
        final dateOnly = dateVal.length >= 10
            ? dateVal.substring(0, 10)
            : dateVal;

        // Total revenue: sum of (quantity * price) per item in the sale
        double saleRevenue = 0;
        final items = sale['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final qty = _asDouble(item['quantitySold'] ?? item['quantity']);
          final price = _asDouble(item['unitPrice'] ?? item['price']);
          saleRevenue += qty * price;
        }
        // Fallback: API may return a top-level totalAmount field
        if (saleRevenue == 0) {
          saleRevenue = _asDouble(sale['totalAmount'] ?? sale['total']);
        }

        if (dateOnly == today) todayTotal += saleRevenue;
        if (dateOnly == yesterday) yesterdayTotal += saleRevenue;
      }

      _todayRevenue = todayTotal;
      _yesterdayRevenue = yesterdayTotal;
    } catch (e) {
      _salesError = e.toString().replaceAll('Exception: ', '');
    }

    _isLoadingSales = false;
    notifyListeners();
  }

  // ── Today's revenue display ─────────────────────────────────
  String get todayRevenueFormatted {
    if (_todayRevenue == 0) return '₦0.00';
    return '₦${_todayRevenue.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  String get revenueChangeLabel {
    if (_yesterdayRevenue == 0) {
      return _todayRevenue > 0
          ? 'First sales today 🎉'
          : 'No sales recorded yet';
    }
    final pct = ((_todayRevenue - _yesterdayRevenue) / _yesterdayRevenue) * 100;
    final sign = pct >= 0 ? '+' : '';
    return '$sign${pct.toStringAsFixed(1)}% from yesterday';
  }

  bool get revenueIsUp => _todayRevenue >= _yesterdayRevenue;

  // ── Waste Reduction % ───────────────────────────────────────
  // % of products NOT expired this week = "reduction" proxy
  String get wasteReductionPercent {
    if (_products.isEmpty) return '0%';
    final safe = _products.where((p) => !p.isExpired).length;
    final pct = (safe / _products.length * 100).round();
    return '$pct%';
  }

  // ── Waste Risk Levels ───────────────────────────────────────
  // Computed from inventory expiry — no extra API needed
  int get highRiskCount =>
      _products.where((p) => p.isExpired || _daysLeft(p) <= 1).length;

  int get mediumRiskCount => _products.where((p) {
    final d = _daysLeft(p);
    return !p.isExpired && d > 1 && d <= 3;
  }).length;

  int get lowRiskCount => _products.where((p) {
    final d = _daysLeft(p);
    return !p.isExpired && d > 3 && d <= 7;
  }).length;

  // ── Daily Alerts ────────────────────────────────────────────
  List<DashboardAlert> get dailyAlerts {
    final alerts = <DashboardAlert>[];

    for (final p in _products) {
      if (p.isExpired) {
        alerts.add(
          DashboardAlert(
            productName: p.name,
            message: 'Expired — remove from stock immediately',
            severity: 'High',
          ),
        );
      } else if (_daysLeft(p) <= 1) {
        alerts.add(
          DashboardAlert(
            productName: p.name,
            message: 'Expires in ${_daysLeft(p)} day — use first',
            severity: 'High',
          ),
        );
      } else if (p.isLowStock) {
        final needed = (p.effectiveThreshold - p.quantityAvailable).ceil();
        alerts.add(
          DashboardAlert(
            productName: p.name,
            message: 'Prepare $needed ${p.unit.name} more',
            severity: 'Medium',
          ),
        );
      } else if (p.isExpiringSoon) {
        alerts.add(
          DashboardAlert(
            productName: p.name,
            message: 'Expiring in ${_daysLeft(p)} days — plan ahead',
            severity: 'Low',
          ),
        );
      }
    }

    alerts.sort((a, b) => _rank(a.severity).compareTo(_rank(b.severity)));
    return alerts.take(5).toList();
  }

  // ── Smart Recommendations ────────────────────────────────────
  List<DashboardRecommendation> get smartRecommendations {
    final recs = <DashboardRecommendation>[];

    for (final p in _products) {
      final days = _daysLeft(p);
      if (!p.isExpired && days <= 2) {
        recs.add(
          DashboardRecommendation(
            productName: p.name,
            message: 'Use before expiry in $days day(s) to reduce waste',
          ),
        );
      } else if (p.isLowStock) {
        final target = p.effectiveThreshold.ceil();
        recs.add(
          DashboardRecommendation(
            productName: p.name,
            message:
                'Prepare $target instead of ${p.quantityAvailable.toInt()} ${p.unit.name}',
          ),
        );
      } else if (p.quantityAvailable > p.effectiveThreshold * 1.5) {
        recs.add(
          DashboardRecommendation(
            productName: '${p.name} sales',
            message:
                'Push sales — ${p.quantityAvailable.toInt()} ${p.unit.name} in stock',
          ),
        );
      }
    }

    return recs.take(3).toList();
  }

  // ── Helpers ─────────────────────────────────────────────────
  int _daysLeft(ProductModel p) {
    final expiry = p.productionDate.add(Duration(days: p.shelfLife));
    return expiry.difference(DateTime.now()).inDays;
  }

  String _dateStr(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int _rank(String s) {
    switch (s) {
      case 'High':
        return 0;
      case 'Medium':
        return 1;
      default:
        return 2;
    }
  }

  double _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
