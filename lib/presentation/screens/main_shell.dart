import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/presentation/providers/business_provider.dart';
import 'package:prepal2/presentation/providers/dashboard_provider.dart';
import 'package:prepal2/presentation/providers/inventory_provider.dart';
import 'package:prepal2/presentation/providers/daily_sales_provider.dart';
import 'package:prepal2/presentation/providers/forecast_provider.dart';
import 'package:prepal2/presentation/screens/dashboard/dashboard_screen.dart';
import 'package:prepal2/presentation/screens/forecast/demand_forecast_screen.dart';
import 'package:prepal2/presentation/screens/inventory/inventory_list_screen.dart';
import 'package:prepal2/presentation/screens/alerts/alerts_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const DemandForecastScreen(),
    const InventoryListScreen(),
    const AlertsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;

      // 1. Load businesses first — sets businessId in ApiClient
      await context.read<BusinessProvider>().loadBusinesses();

      if (!mounted) return;

      // 2. Load inventory after businessId is available
      await context.read<InventoryProvider>().loadProducts();

      if (!mounted) return;
      final inventoryProducts = context.read<InventoryProvider>().allProducts;
      context.read<DashboardProvider>().syncInventory(inventoryProducts);

      final businessProvider = context.read<BusinessProvider>();
      if (businessProvider.hasBusiness) {
        final businessId = businessProvider.currentBusiness!.id;
        await context.read<DailySalesProvider>().loadSalesForBusiness(
          businessId,
        );
        if (!mounted) return;
        await context.read<DashboardProvider>().loadSales(businessId);
        if (!mounted) return;
        await context.read<ForecastProvider>().loadForecastData();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFD32F2F),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_outlined),
            activeIcon: Icon(Icons.show_chart),
            label: 'Forecast',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications_outlined),
            activeIcon: Icon(Icons.notifications),
            label: 'Alerts',
          ),
        ],
      ),
    );
  }
}
