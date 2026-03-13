import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/presentation/providers/inventory_provider.dart';

class ProductDetailScreen extends StatefulWidget {
  final ProductModel product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  late ProductModel _product;
  bool _isWorking = false;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  Future<void> _editProduct() async {
    final nameController = TextEditingController(text: _product.name);
    final quantityController = TextEditingController(
      text: _product.quantityAvailable.toString(),
    );
    final priceController = TextEditingController(
      text: _product.price.toString(),
    );
    final thresholdController = TextEditingController(
      text: _product.lowStockThreshold?.toString() ?? '',
    );
    final shelfLifeController = TextEditingController(
      text: _product.shelfLife.toString(),
    );

    final formKey = GlobalKey<FormState>();
    ProductCategory selectedCategory = _product.category;
    ProductUnit selectedUnit = _product.unit;
    DateTime selectedProductionDate = _product.productionDate;

    final updated = await showDialog<ProductModel>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit product'),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                        validator: (v) =>
                            v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: quantityController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final parsed = double.tryParse(v);
                          if (parsed == null || parsed < 0) return 'Invalid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: priceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Price'),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final parsed = double.tryParse(v);
                          if (parsed == null || parsed < 0) return 'Invalid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: shelfLifeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Shelf life (hours)',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final parsed = int.tryParse(v);
                          if (parsed == null || parsed < 0) return 'Invalid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: thresholdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Low stock threshold (optional)',
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final parsed = double.tryParse(v);
                          if (parsed == null || parsed < 0) return 'Invalid';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<ProductCategory>(
                        initialValue: selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                        ),
                        items: ProductCategory.values
                            .map(
                              (cat) => DropdownMenuItem(
                                value: cat,
                                child: Text(cat.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedCategory = value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<ProductUnit>(
                        initialValue: selectedUnit,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: ProductUnit.values
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(unit.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => selectedUnit = value);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Production date:'),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selectedProductionDate.day.toString().padLeft(2, '0')}-'
                              '${selectedProductionDate.month.toString().padLeft(2, '0')}-'
                              '${selectedProductionDate.year}',
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedProductionDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime(2035),
                              );
                              if (picked != null) {
                                setDialogState(
                                  () => selectedProductionDate = picked,
                                );
                              }
                            },
                            child: const Text('Pick'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(
                  ctx,
                  _product.copyWith(
                    name: nameController.text.trim(),
                    quantityAvailable: double.parse(quantityController.text),
                    price: double.parse(priceController.text),
                    shelfLife: int.parse(shelfLifeController.text),
                    lowStockThreshold: thresholdController.text.trim().isEmpty
                        ? null
                        : double.parse(thresholdController.text),
                    category: selectedCategory,
                    unit: selectedUnit,
                    productionDate: selectedProductionDate,
                  ),
                );
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (!mounted || updated == null) return;

    setState(() => _isWorking = true);
    final success = await context.read<InventoryProvider>().updateProduct(
      updated,
    );
    if (!mounted) return;

    setState(() => _isWorking = false);
    if (success) {
      setState(() => _product = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product updated successfully')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<InventoryProvider>().errorMessage ??
                'Failed to update product',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteProduct() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete product'),
        content: const Text('Are you sure you want to delete this product?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    setState(() => _isWorking = true);
    final success = await context.read<InventoryProvider>().deleteProduct(
      _product.id,
    );
    if (!mounted) return;
    setState(() => _isWorking = false);

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Product deleted successfully')),
      );
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<InventoryProvider>().errorMessage ??
                'Failed to delete product',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        title: const Text('Product Details'),
        actions: [
          if (_isWorking)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: _isWorking ? null : _editProduct,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: _isWorking ? null : _deleteProduct,
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
              _product.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
                _product.category.name[0].toUpperCase() +
                    _product.category.name.substring(1),
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
              value: '${_product.quantityAvailable} ${_product.unit.name}',
            ),
            const SizedBox(height: 16),

            _DetailRow(
              label: 'Production Date',
              value:
                  '${_product.productionDate.day}-${_product.productionDate.month}-${_product.productionDate.year}',
            ),
            const SizedBox(height: 16),

            _DetailRow(
              label: 'Shelf life',
              value: '${_product.shelfLife} hours',
            ),
            const SizedBox(height: 16),

            _DetailRow(
              label: 'Low Stock Threshold',
              value: '${_product.effectiveThreshold} ${_product.unit.name}',
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),

            // Status indicators
            if (_product.isExpired)
              _StatusCard(
                icon: Icons.cancel_outlined,
                label: 'Expired',
                color: Colors.grey,
              )
            else if (_product.isExpiringSoon)
              _StatusCard(
                icon: Icons.schedule,
                label: 'Expiring Soon',
                color: Colors.orange,
              ),

            if (_product.isLowStock) const SizedBox(height: 12),

            if (_product.isLowStock)
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

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 14)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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
            style: TextStyle(color: color, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
