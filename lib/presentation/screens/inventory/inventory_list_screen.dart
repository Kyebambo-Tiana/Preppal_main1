import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/presentation/providers/inventory_provider.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/presentation/screens/inventory/product_detail_screen.dart';
import 'package:prepal2/presentation/screens/inventory/add_product_screen.dart';
import 'package:prepal2/presentation/screens/alerts/alerts_screen.dart';
import 'package:prepal2/presentation/screens/auth/business_details_screen.dart';
import 'package:prepal2/core/utills/food_visuals.dart';

const kInventoryPrimary = Color(0xFF0F7A6B);
const kInventoryPrimaryLight = Color(0xFF168B7B);
const kInventorySurface = Color(0xFFF5F2F4);
const kInventoryCard = Color(0xFFFFFEFE);
const kInventoryTextPrimary = Color(0xFF1F2937);
const kInventoryTextSecondary = Color(0xFF7C8798);

class InventoryListScreen extends StatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onOpenAlerts;

  const InventoryListScreen({super.key, this.onClose, this.onOpenAlerts});

  @override
  State<InventoryListScreen> createState() => _InventoryListScreenState();
}

class _InventoryListScreenState extends State<InventoryListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }

    Navigator.maybePop(context);
  }

  Future<void> _handleOpenAlerts() async {
    if (widget.onOpenAlerts != null) {
      widget.onOpenAlerts!();
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AlertsScreen()));
  }

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

  Future<void> _copyInventorySummary(InventoryProvider inv) async {
    final lowCount =
        inv.allProducts.where(_isLow).length +
        inv.allProducts.where(_isCritical).length;
    final overCount = inv.allProducts.where(_isOverStock).length;
    final optimalCount = inv.allProducts.where(_isOptimalStock).length;

    final lines = <String>[
      'Inventory Management',
      'Total items: ${inv.totalProducts}',
      'Low stock: $lowCount',
      'Over stock: $overCount',
      'Optimal: $optimalCount',
    ];

    for (final product in inv.allProducts.take(5)) {
      lines.add(
        '${product.name}: ${product.quantityAvailable.toStringAsFixed(0)} ${product.unit.name.toUpperCase()}',
      );
    }

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Inventory summary copied')));
  }

  Future<void> _openMoreActions(InventoryProvider inv) async {
    final action = await showModalBottomSheet<_InventoryAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                _InventoryActionTile(
                  icon: Icons.add,
                  label: 'Add product',
                  onTap: () =>
                      Navigator.pop(sheetContext, _InventoryAction.add),
                ),
                _InventoryActionTile(
                  icon: Icons.refresh,
                  label: 'Refresh inventory',
                  onTap: () =>
                      Navigator.pop(sheetContext, _InventoryAction.refresh),
                ),
                _InventoryActionTile(
                  icon: Icons.notifications_none,
                  label: 'Open alerts',
                  onTap: () =>
                      Navigator.pop(sheetContext, _InventoryAction.alerts),
                ),
                _InventoryActionTile(
                  icon: Icons.content_copy_outlined,
                  label: 'Copy summary',
                  onTap: () =>
                      Navigator.pop(sheetContext, _InventoryAction.copy),
                ),
              ],
            ),
          ),
        );
      },
    );

    switch (action) {
      case _InventoryAction.add:
        await _openAddProduct();
      case _InventoryAction.refresh:
        await inv.loadProducts();
      case _InventoryAction.alerts:
        await _handleOpenAlerts();
      case _InventoryAction.copy:
        await _copyInventorySummary(inv);
      case null:
        return;
    }
  }

  Future<void> _openAddProduct() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddProductScreen()),
    );

    if (!mounted || created != true) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Product added successfully!'),
        backgroundColor: kInventoryPrimary,
      ),
    );
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
      backgroundColor: kInventorySurface,
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
              _InventoryTopBar(
                onClose: _handleClose,
                onOpenAlerts: _handleOpenAlerts,
                onCopy: () => _copyInventorySummary(inv),
                onMore: () => _openMoreActions(inv),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [kInventoryPrimaryLight, kInventoryPrimary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: kInventoryPrimary.withValues(alpha: 0.16),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: _handleClose,
                            borderRadius: BorderRadius.circular(99),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                                size: 16,
                              ),
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
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Real-time stock tracking',
                                  style: TextStyle(
                                    color: Color(0xFFD9F5EF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          InkWell(
                            onTap: _openAddProduct,
                            borderRadius: BorderRadius.circular(99),
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  width: 1.6,
                                ),
                                color: Colors.white.withValues(alpha: 0.08),
                              ),
                              child: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) =>
                              setState(() => _searchQuery = value.trim()),
                          decoration: const InputDecoration(
                            hintText: 'Search inventory',
                            hintStyle: TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: Color(0xFF6B7280),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

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
                                onPressed: () {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const BusinessDetailsScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Add Business'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => inv.loadProducts(),
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _StatPill(
                                    count: inv.totalProducts,
                                    label: 'Total',
                                    color: const Color(0xFF44363E),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatPill(
                                    count: lowCount,
                                    label: 'Low',
                                    color: const Color(0xFFE3A300),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatPill(
                                    count: overCount,
                                    label: 'Over',
                                    color: const Color(0xFFE35158),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: _StatPill(
                                    count: optimalCount,
                                    label: 'Optimal',
                                    color: const Color(0xFF7BAF6C),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // ── Product cards ──────────
                            if (filtered.isEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 8),
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: kInventoryCard,
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: const Center(
                                  child: Text(
                                    'No products found.',
                                    style: TextStyle(
                                      color: kInventoryTextSecondary,
                                    ),
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
                                    final inventoryProvider = context
                                        .read<InventoryProvider>();
                                    final changed = await Navigator.push<bool>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            ProductDetailScreen(product: p),
                                      ),
                                    );

                                    if (changed == true) {
                                      await inventoryProvider.loadProducts();
                                    }
                                  },
                                ),
                              ),

                            // ── Smart Insights ─────────
                            const SizedBox(height: 10),
                            _SmartInsightsSection(insights: insights),

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: kInventoryTextSecondary,
            ),
          ),
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
        decoration: BoxDecoration(
          color: kInventoryCard,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0F7A6B).withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product image placeholder
                Builder(
                  builder: (_) {
                    if (product.imageUrl.trim().isNotEmpty) {
                      return CircleAvatar(
                        radius: 21,
                        backgroundColor: const Color(0xFFFFF4D6),
                        onBackgroundImageError: (_, __) {},
                        backgroundImage: NetworkImage(product.imageUrl),
                      );
                    }

                    final colors = FoodVisuals.colorsFor(product.name);
                    return Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Color(colors.bg),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        FoodVisuals.emojiFor(product.name),
                        style: const TextStyle(fontSize: 20),
                      ),
                    );
                  },
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
                                height: 1,
                                fontWeight: FontWeight.w700,
                                color: kInventoryTextPrimary,
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
                              borderRadius: BorderRadius.circular(999),
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
                        style: const TextStyle(
                          fontSize: 12,
                          color: kInventoryTextSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Stock / Optimal row
                      Row(
                        children: [
                          Text(
                            'Stock: ${product.quantityAvailable.toStringAsFixed(0)}$unitStr',
                            style: const TextStyle(
                              fontSize: 12,
                              color: kInventoryTextSecondary,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Optimal: ${optimal.toStringAsFixed(0)}$unitStr',
                            style: const TextStyle(
                              fontSize: 12,
                              color: kInventoryTextSecondary,
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
                minHeight: 5,
                backgroundColor: const Color(0xFFE6E0E5),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Production date: $prodDate',
              style: const TextStyle(
                fontSize: 11,
                color: kInventoryTextSecondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Price per unit: ${product.currency} ${product.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 11,
                color: kInventoryTextSecondary,
              ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CF),
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
              color: kInventoryTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (insights.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    color: kInventoryPrimary,
                    size: 20,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'All current stock levels look healthy.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: kInventoryTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ...insights.take(3).map((item) {
            final color = _labelColor(item['label'] ?? '');
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.9),
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
                          item['product'] ?? '',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kInventoryTextPrimary,
                          ),
                        ),
                        Text(
                          item['message'] ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: kInventoryTextSecondary,
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

class _InventoryTopBar extends StatelessWidget {
  final VoidCallback onClose;
  final VoidCallback onOpenAlerts;
  final VoidCallback onCopy;
  final VoidCallback onMore;

  const _InventoryTopBar({
    required this.onClose,
    required this.onOpenAlerts,
    required this.onCopy,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
        child: Row(
          children: [
            IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close, color: Colors.black87),
            ),
            const Expanded(
              child: Text(
                'Prepal',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
            IconButton(
              onPressed: onOpenAlerts,
              icon: const Icon(Icons.notifications_none, color: Colors.black87),
            ),
            IconButton(
              onPressed: onCopy,
              icon: const Icon(
                Icons.content_copy_outlined,
                color: Colors.black87,
              ),
            ),
            IconButton(
              onPressed: onMore,
              icon: const Icon(Icons.more_vert, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }
}

enum _InventoryAction { add, refresh, alerts, copy }

class _InventoryActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _InventoryActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: kInventoryPrimary),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: kInventoryTextPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}
