import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/presentation/providers/inventory_provider.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/presentation/screens/inventory/product_detail_screen.dart';
import 'package:prepal2/presentation/screens/inventory/add_product_screen.dart';

class InventoryListScreen extends StatefulWidget {
  const InventoryListScreen({super.key});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<InventoryProvider>().loadProducts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Stock classification helpers ───────────────────────────
  double _optimal(ProductModel p) => (p.lowStockThreshold ?? 10) * 2;

  bool _isOverStock(ProductModel p) => p.quantityAvailable > _optimal(p);

  bool _isOptimalStock(ProductModel p) =>
      p.quantityAvailable > (p.lowStockThreshold ?? 10) &&
      p.quantityAvailable <= _optimal(p);

  bool _isCritical(ProductModel p) =>
      p.quantityAvailable <= (p.lowStockThreshold ?? 10) * 0.25 &&
      p.quantityAvailable > 0;

  bool _isLow(ProductModel p) =>
      p.quantityAvailable <= (p.lowStockThreshold ?? 10) && !_isCritical(p);

  String _statusLabel(ProductModel p) {
    if (_isCritical(p)) return 'Critical';
    if (_isLow(p)) return 'Low';
    if (_isOverStock(p)) return 'Over stock';
    return 'Optimal';
  }

  Color _statusColor(ProductModel p) {
    if (_isCritical(p)) return const Color(0xFFD32F2F);
    if (_isLow(p)) return const Color(0xFFFFA726);
    if (_isOverStock(p)) return const Color(0xFFEF5350);
    return const Color(0xFF66BB6A);
  }

  // ── Smart insight generation ────────────────────────────────
  List<Map<String, String>> _generateInsights(InventoryProvider inv) {
    final insights = <Map<String, String>>[];
    for (final p in inv.allProducts) {
      if (_isCritical(p)) {
        insights.add({
          'message': 'Restock ${p.name} immediately',
          'product': p.name,
          'label': 'Critical',
        });
      } else if (_isLow(p)) {
        insights.add({
          'message': '${p.name} is running low',
          'product': p.name,
          'label': 'Low',
        });
      } else if (_isOverStock(p)) {
        insights.add({
          'message': '${p.name} is overstocked',
          'product': p.name,
          'label': 'Over',
        });
      }
    }
    return insights;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      body: Consumer<InventoryProvider>(
        builder: (context, inv, _) {
          // Filtered products
          List<ProductModel> filtered = List.from(inv.allProducts);
          if (_searchQuery.isNotEmpty) {
            filtered = filtered
                .where(
                  (p) =>
                      p.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ) ||
                      p.category.name.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                )
                .toList();
          }

          final lowCount =
              inv.allProducts.where(_isLow).length +
              inv.allProducts.where(_isCritical).length;
          final overCount = inv.allProducts.where(_isOverStock).length;
          final optimalCount = inv.allProducts.where(_isOptimalStock).length;
          final insights = _generateInsights(inv);

          return Column(
            children: [
              // ── Red Header ─────────────────────────────────
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFE53935), Color(0xFFD32F2F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.maybePop(context),
                              child: const Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Inventory Management',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Real-time stock tracking',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AddProductScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                padding: const EdgeInsets.all(6),
                                child: const Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Search bar
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _searchQuery = v),
                            style: const TextStyle(fontSize: 14),
                            decoration: const InputDecoration(
                              hintText: 'Search inventory',
                              hintStyle: TextStyle(
                                color: Color(0xFFBDBDBD),
                                fontSize: 14,
                              ),
                              prefixIcon: Icon(
                                Icons.search,
                                color: Color(0xFF9E9E9E),
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ── Body ───────────────────────────────────────
              Expanded(
                child: inv.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : inv.errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                inv.errorMessage!,
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => inv.loadProducts(),
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => inv.loadProducts(),
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            const SizedBox(height: 16),
                            // ── Stat pills ─────────────
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  _StatPill(
                                    count: inv.totalProducts,
                                    label: 'Total',
                                    color: const Color(0xFF424242),
                                  ),
                                  _StatPill(
                                    count: lowCount,
                                    label: 'Low',
                                    color: const Color(0xFFFFA726),
                                  ),
                                  _StatPill(
                                    count: overCount,
                                    label: 'Over',
                                    color: const Color(0xFFEF5350),
                                  ),
                                  _StatPill(
                                    count: optimalCount,
                                    label: 'Optimal',
                                    color: const Color(0xFF66BB6A),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // ── Product cards ──────────
                            if (filtered.isEmpty)
                              const Padding(
                                padding: EdgeInsets.all(32),
                                child: Center(
                                  child: Text(
                                    'No products found.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ),
                              )
                            else
                              ...filtered.map(
                                (p) => _ProductCard(
                                  product: p,
                                  optimal: _optimal(p),
                                  statusLabel: _statusLabel(p),
                                  statusColor: _statusColor(p),
                                  onTap: () async {
                                    final changed = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProductDetailScreen(product: p),
                                      ),
                                    );

                                    if (changed == true && mounted) {
                                      await context
                                          .read<InventoryProvider>()
                                          .loadProducts();
                                    }
                                  },
                                ),
                              ),

                            // ── Smart Insights ─────────
                            if (insights.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _SmartInsightsSection(insights: insights),
                            ],

                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Stat Pill Widget ──────────────────────────────────────────
class _StatPill extends StatelessWidget {
  final int count;
  final String label;
  final Color color;

  const _StatPill({
    required this.count,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Color bg = color.withValues(alpha: 0.12);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

// ── Product Card Widget ───────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final double optimal;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.optimal,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    double pct = optimal > 0 ? product.quantityAvailable / optimal : 0;
    if (pct > 1) pct = 1;

    final unitStr = product.unit.name.toUpperCase();
    final prodDate =
        '${product.productionDate.day.toString().padLeft(2, '0')}-${product.productionDate.month.toString().padLeft(2, '0')}-${product.productionDate.year}';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image placeholder
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3E0),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    product.name.isNotEmpty
                        ? product.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF8A65),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name + status badge
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              product.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: statusColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      // Category
                      Text(
                        product.category.name[0].toUpperCase() +
                            product.category.name.substring(1),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                      const SizedBox(height: 6),
                      // Stock / Optimal row
                      Row(
                        children: [
                          Text(
                            'Stock: ${product.quantityAvailable.toStringAsFixed(0)}$unitStr',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Optimal: ${optimal.toStringAsFixed(0)}$unitStr',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[400],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: const Color(0xFFEEEEEE),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 6),
            // Production date
            Text(
              'Production date: $prodDate',
              style: TextStyle(fontSize: 11, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Smart Insights Section ────────────────────────────────────
class _SmartInsightsSection extends StatelessWidget {
  final List<Map<String, String>> insights;

  const _SmartInsightsSection({required this.insights});

  Color _labelColor(String label) {
    switch (label) {
      case 'Critical':
        return const Color(0xFFD32F2F);
      case 'Low':
        return const Color(0xFFFFA726);
      case 'Over':
        return const Color(0xFFEF5350);
      default:
        return const Color(0xFF66BB6A);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8F0),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Smart Insights',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          ...insights.take(3).map((item) {
            final color = _labelColor(item['label'] ?? '');
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: color, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['message'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          item['product'] ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item['label'] ?? '',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
