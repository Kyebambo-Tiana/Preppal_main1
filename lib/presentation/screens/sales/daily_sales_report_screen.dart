import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/presentation/providers/business_provider.dart';
import 'package:prepal2/presentation/providers/daily_sales_provider.dart';
import 'package:prepal2/presentation/providers/inventory_provider.dart';
import 'package:prepal2/presentation/screens/main_shell.dart';

class DailySalesReportScreen extends StatefulWidget {
  const DailySalesReportScreen({super.key});

  @override
  State<DailySalesReportScreen> createState() => _DailySalesReportScreenState();
}

class _DailySalesReportScreenState extends State<DailySalesReportScreen> {
  final _formKey = GlobalKey<FormState>();
  final List<_SalesEntry> _salesEntries = [_SalesEntry()];
  bool _isSubmitting = false;

  static const List<String> _fallbackProductTypes = [
    'Pastries',
    'Cakes',
    'Bread',
    'Drinks',
  ];
  static const List<String> _fallbackUnits = ['PCS', 'KG', 'L', 'BOX'];

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      if (!mounted) return;

      final businessProvider = context.read<BusinessProvider>();
      if (!businessProvider.hasBusiness) {
        await businessProvider.loadBusinesses();
      }

      if (!mounted) return;
      final inventory = context.read<InventoryProvider>();
      if (inventory.allProducts.isEmpty) {
        await inventory.loadProducts();
      }
    });
  }

  @override
  void dispose() {
    for (final entry in _salesEntries) {
      entry.dispose();
    }
    super.dispose();
  }

  void _addProductRow() {
    setState(() {
      _salesEntries.add(_SalesEntry());
    });
  }

  void _removeProductRow(int index) {
    setState(() {
      final entry = _salesEntries.removeAt(index);
      entry.dispose();
    });
  }

  int? _tryParseInt(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return int.tryParse(value);
  }

  bool _isEntryActive(_SalesEntry entry) {
    final stockRaw = entry.stockLeftController.text.trim();
    final hasMeaningfulStock = stockRaw.isNotEmpty && stockRaw != '0';

    return entry.productNameController.text.trim().isNotEmpty ||
        entry.productionDateController.text.trim().isNotEmpty ||
        entry.quantitySoldController.text.trim().isNotEmpty ||
        hasMeaningfulStock;
  }

  ProductModel? _findProductByName(List<ProductModel> products, String name) {
    final needle = name.trim().toLowerCase();
    // 1. Exact case-insensitive match
    for (final p in products) {
      if (p.name.trim().toLowerCase() == needle) return p;
    }
    // 2. Partial match fallback (handles "Meat Pie" vs "meat pie" typos)
    for (final p in products) {
      if (p.name.trim().toLowerCase().contains(needle) ||
          needle.contains(p.name.trim().toLowerCase()))
        return p;
    }
    return null;
  }

  String _categoryLabel(ProductCategory category) {
    switch (category) {
      case ProductCategory.beverages:
        return 'Beverages';
      case ProductCategory.dairy:
        return 'Dairy';
      case ProductCategory.snacks:
        return 'Snacks';
      case ProductCategory.produce:
        return 'Produce';
      case ProductCategory.bakery:
        return 'Bakery';
      case ProductCategory.meat:
        return 'Meat';
      case ProductCategory.spices:
        return 'Spices';
      case ProductCategory.frozen:
        return 'Frozen';
      case ProductCategory.others:
        return 'Others';
    }
  }

  String _unitLabel(ProductUnit unit) {
    switch (unit) {
      case ProductUnit.kg:
        return 'KG';
      case ProductUnit.g:
        return 'G';
      case ProductUnit.litre:
        return 'L';
      case ProductUnit.ml:
        return 'ML';
      case ProductUnit.pcs:
        return 'PCS';
      case ProductUnit.dozen:
        return 'DOZEN';
      case ProductUnit.others:
        return 'OTHERS';
    }
  }

  List<String> _productTypeOptions(List<ProductModel> inventoryProducts) {
    final values =
        inventoryProducts
            .map((p) => _categoryLabel(p.category))
            .toSet()
            .toList()
          ..sort();

    return values.isEmpty ? _fallbackProductTypes : values;
  }

  List<String> _unitOptions(List<ProductModel> inventoryProducts) {
    final values =
        inventoryProducts.map((p) => _unitLabel(p.unit)).toSet().toList()
          ..sort();

    return values.isEmpty ? _fallbackUnits : values;
  }

  void _syncEntryFromSelectedProduct(
    _SalesEntry entry,
    List<ProductModel> inventoryProducts,
  ) {
    final selected = _findProductByName(
      inventoryProducts,
      entry.productNameController.text.trim(),
    );
    if (selected == null) return;

    entry.productType = _categoryLabel(selected.category);
    entry.unit = _unitLabel(selected.unit);
  }

  String _todayIsoDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _handleClose() async {
    final didPop = await Navigator.maybePop(context);
    if (didPop || !mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  Future<void> _submitToBackend({required bool popAfterSuccess}) async {
    if (!_formKey.currentState!.validate()) return;

    final inventoryProducts = context.read<InventoryProvider>().allProducts;
    if (inventoryProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No inventory products found. Add inventory before recording sales.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final items = <Map<String, dynamic>>[];
    final unmatchedProducts = <String>[];
    double totalAmount = 0;

    for (final entry in _salesEntries) {
      final selectedProductName = entry.productName;
      if (selectedProductName == null || selectedProductName.isEmpty) {
        continue;
      }

      final product = _findProductByName(
        inventoryProducts,
        selectedProductName,
      );
      if (product == null) {
        unmatchedProducts.add(selectedProductName);
        continue;
      }

      final quantity = _tryParseInt(entry.quantitySoldController.text) ?? 0;
      if (quantity <= 0) {
        continue;
      }
      final stockLeft = _tryParseInt(entry.stockLeftController.text) ?? 0;
      final unitPrice = product.price;

      items.add({
        'productId': product.id,
        'productName': product.name,
        'productType': entry.productType,
        'productionDate': entry.productionDateController.text.trim().isEmpty
            ? _todayIsoDate()
            : entry.productionDateController.text.trim(),
        'quantitySold': quantity,
        'unit': entry.unit,
        'stockLeft': stockLeft,
        'unitPrice': unitPrice,
      });

      totalAmount += quantity * unitPrice;
    }

    if (unmatchedProducts.isNotEmpty) {
      setState(() => _isSubmitting = false);
      final names = unmatchedProducts.toSet().take(3).join(', ');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Select valid inventory product(s): $names'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (items.isEmpty) {
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one valid product sale entry.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final payload = {
      'date': _todayIsoDate(),
      'items': items,
      'totalAmount': totalAmount,
    };

    final success = await context.read<DailySalesProvider>().addSale(payload);
    setState(() => _isSubmitting = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            popAfterSuccess
                ? 'Sales report submitted successfully'
                : 'Sales report saved successfully',
          ),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );

      if (popAfterSuccess) {
        Navigator.pop(context);
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.read<DailySalesProvider>().errorMessage ??
              'Failed to submit sales report',
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: _handleClose,
        ),
        title: const Text(
          'Prepal',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Progress indicator
              Row(
                children: List.generate(
                  4,
                  (index) => Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(right: index < 3 ? 8 : 0),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(3),
                        color: index < 3
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFFFD8B0),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              const Center(
                child: Text(
                  'Daily sales report',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product entries
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _salesEntries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 24),
                      itemBuilder: (context, index) {
                        final inventoryProducts = context
                            .watch<InventoryProvider>()
                            .allProducts;
                        return _buildProductEntry(
                          context,
                          _salesEntries[index],
                          index,
                          inventoryProducts,
                        );
                      },
                    ),

                    const SizedBox(height: 24),

                    // Add another product button
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: _isSubmitting ? null : _addProductRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Add another product'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Save and Submit buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () =>
                                      _submitToBackend(popAfterSuccess: false),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE8F5E9),
                              foregroundColor: const Color(0xFF1B5E20),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    'Save',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () => _submitToBackend(popAfterSuccess: true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E7D32),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Submit',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductEntry(
    BuildContext context,
    _SalesEntry entry,
    int index,
    List<ProductModel> inventoryProducts,
  ) {
    final productNames = inventoryProducts.map((p) => p.name).toSet().toList();
    final productTypeOptions = _productTypeOptions(inventoryProducts);
    final unitOptions = _unitOptions(inventoryProducts);

    if (!productTypeOptions.contains(entry.productType)) {
      entry.productType = productTypeOptions.first;
    }
    if (!unitOptions.contains(entry.unit)) {
      entry.unit = unitOptions.first;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Product name
        const Text(
          'Product name',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: entry.productNameController,
          onChanged: (_) {
            setState(() {
              _syncEntryFromSelectedProduct(entry, inventoryProducts);
            });
          },
          validator: (value) {
            if (!_isEntryActive(entry)) return null;
            return (value?.trim().isEmpty ?? true)
                ? 'Please enter a product name'
                : null;
          },
          decoration: InputDecoration(
            hintText: productNames.isNotEmpty
                ? 'e.g., ${productNames.first}'
                : 'Enter product name',
            hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
            filled: true,
            fillColor: const Color(0xFFE8D8E8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        if (productNames.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: productNames
                  .map(
                    (product) => GestureDetector(
                      onTap: () => setState(() {
                        entry.productNameController.text = product;
                        _syncEntryFromSelectedProduct(entry, inventoryProducts);
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF2E7D32),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          product,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF2E7D32),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        const SizedBox(height: 16),

        // Product type and Production date (Side by side)
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product type',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: entry.productType,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFE8D8E8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: productTypeOptions
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => entry.productType = value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Production date',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: entry.productionDateController,
                    readOnly: true,
                    decoration: InputDecoration(
                      hintText: '14-02-2026',
                      hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                      filled: true,
                      fillColor: const Color(0xFFE8D8E8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        setState(
                          () => entry.productionDateController.text =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Quantity sold and Unit (Side by side)
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Quantity sold',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: entry.quantitySoldController,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (!_isEntryActive(entry)) return null;
                      final raw = v?.trim() ?? '';
                      if (raw.isEmpty) return 'Enter valid quantity';
                      final quantity = int.tryParse(raw);
                      if (quantity == null || quantity <= 0) {
                        return 'Must be greater than 0';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      hintText: '24',
                      hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
                      filled: true,
                      fillColor: const Color(0xFFE8D8E8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Unit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: entry.unit,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFE8D8E8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: unitOptions
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => entry.unit = value);
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Stock left
        const Text(
          'Stock left',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: entry.stockLeftController,
          keyboardType: TextInputType.number,
          validator: (v) {
            if (!_isEntryActive(entry)) return null;
            final raw = v?.trim() ?? '';
            if (raw.isEmpty) return null;
            final stock = int.tryParse(raw);
            if (stock == null || stock < 0) {
              return 'Enter valid stock';
            }
            return null;
          },
          decoration: InputDecoration(
            hintText: '0 pcs',
            hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
            filled: true,
            fillColor: const Color(0xFFE8D8E8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),

        // Remove button if multiple entries
        if (_salesEntries.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: TextButton(
              onPressed: () => _removeProductRow(index),
              child: const Text(
                'Remove this item',
                style: TextStyle(color: Color(0xFF2E7D32)),
              ),
            ),
          ),
      ],
    );
  }
}

class _SalesEntry {
  final TextEditingController productNameController = TextEditingController();
  String productType = 'Pastries';
  final TextEditingController productionDateController =
      TextEditingController();
  final TextEditingController quantitySoldController = TextEditingController();
  String unit = 'PCS';
  final TextEditingController stockLeftController = TextEditingController(
    text: '0',
  );

  String? get productName => productNameController.text.trim().isEmpty
      ? null
      : productNameController.text.trim();

  void dispose() {
    productNameController.dispose();
    productionDateController.dispose();
    quantitySoldController.dispose();
    stockLeftController.dispose();
  }
}
