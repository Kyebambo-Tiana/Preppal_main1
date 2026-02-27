import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/presentation/providers/inventory_provider.dart';
import 'package:prepal2/presentation/screens/inventory/add_product_screen.dart';
import 'package:prepal2/presentation/screens/inventory/product_detail_screen.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        title: const Text('Inventory'),
        elevation: 0,
        actions: [
          // Filter by category
          PopupMenuButton<ProductCategory?>(
            icon: const Icon(Icons.filter_list),
            onSelected: inventory.setCategory,
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: null,
                child: Text('All Categories'),
              ),
              ...ProductCategory.values.map(
                (cat) => PopupMenuItem(
                  value: cat,
                  child: Text(
                    cat.name[0].toUpperCase() +
                        cat.name.substring(1),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ───────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: inventory.setSearchQuery,
              decoration: InputDecoration(
                hintText: 'Search products...',
                prefixIcon: const Icon(
                  Icons.search,
                  color: Colors.grey,
                ),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Product List ──────────────────────────────────
          Expanded(
            child: (inventory.isLoading && inventory.filteredProducts.isEmpty)
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFFD32F2F),
                    ),
                  )
                : inventory.filteredProducts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.inventory_2_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'No products found',
                              style: TextStyle(
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton(
                              onPressed:
                                  inventory.clearFilters,
                              child:
                                  const Text('Clear filters'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(
                                horizontal: 16),
                        itemCount: inventory
                            .filteredProducts.length,
                        itemBuilder:
                            (context, index) {
                          final product =
                              inventory.filteredProducts[
                                  index];

                          return _ProductCard(
                            product: product,
                            onTap: () =>
                                Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    ProductDetailScreen(
                                  product: product,
                                ),
                              ),
                            ),
                            onDelete: () async {
                              final confirm =
                                  await _showDeleteDialog(
                                      context);
                              if (confirm == true) {
                                await inventory
                                    .deleteProduct(
                                        product.id);
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),

      // Add product FAB
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: () =>
            Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                const AddProductScreen(),
          ),
        ),
        backgroundColor:
            const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Product'),
      ),
    );
  }

  Future<bool?> _showDeleteDialog(
      BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: const Text(
            'Are you sure you want to remove this product?'),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
                foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// ── Product Card ───────────────────────────────────────────────

class _ProductCard extends StatelessWidget {
  final ProductModel product;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _ProductCard({
    required this.product,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin:
            const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black
                  .withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Status indicator dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: product.isExpired
                    ? Colors.grey
                    : product.isLowStock
                        ? Colors.red
                        : Colors.green,
              ),
            ),
            const SizedBox(width: 12),

            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${product.category.name} • ${product.quantityAvailable} ${product.unit.name}',
                    style:
                        const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                  if (product.isExpiringSoon)
                    const Text(
                      'Expiring soon!',
                      style:
                          TextStyle(
                        color: Colors.orange,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  if (product.isExpired)
                    const Text(
                      'Expired',
                      style:
                          TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),

            // Stock badge
            Container(
              padding:
                  const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4),
              decoration: BoxDecoration(
                color: product.isLowStock
                    ? Colors.red.shade50
                    : Colors.green
                        .shade50,
                borderRadius:
                    BorderRadius.circular(8),
              ),
              child: Text(
                product.isLowStock
                    ? 'Low'
                    : 'OK',
                style: TextStyle(
                  color: product.isLowStock
                      ? Colors.red
                      : Colors.green,
                  fontWeight:
                      FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 8),

            // Delete button
            IconButton(
              icon: const Icon(
                Icons.delete_outline,
                color: Colors.grey,
              ),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
