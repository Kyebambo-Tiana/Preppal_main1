import 'package:flutter/material.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';

class ProductDetailScreen extends StatelessWidget {
  final ProductModel product;

  const ProductDetailScreen({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        title: const Text('Product Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit feature coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product name
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Category badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD32F2F).withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                product.category.name[0].toUpperCase() + 
                    product.category.name.substring(1),
                style: const TextStyle(
                  color: Color(0xFFD32F2F),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Details
            _DetailRow(
              label: 'Quantity Available',
              value: '${product.quantityAvailable} ${product.unit.name}',
            ),
            const SizedBox(height: 16),
            
            _DetailRow(
              label: 'Production Date',
              value: '${product.productionDate.day}-${product.productionDate.month}-${product.productionDate.year}',
            ),
            const SizedBox(height: 16),
            
            _DetailRow(
              label: 'Shelf life',
              value: '${product.shelfLife} days',
            ),
            const SizedBox(height: 16),
            
            _DetailRow(
              label: 'Low Stock Threshold',
              value: '${product.effectiveThreshold} ${product.unit.name}',
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Status indicators
            if (product.isExpired)
              _StatusCard(
                icon: Icons.cancel_outlined,
                label: 'Expired',
                color: Colors.grey,
              )
            else if (product.isExpiringSoon)
              _StatusCard(
                icon: Icons.schedule,
                label: 'Expiring Soon',
                color: Colors.orange,
              ),
            
            if (product.isLowStock)
              const SizedBox(height: 12),
            
            if (product.isLowStock)
              _StatusCard(
                icon: Icons.warning_amber,
                label: 'Low Stock',
                color: Colors.red,
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusCard({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
