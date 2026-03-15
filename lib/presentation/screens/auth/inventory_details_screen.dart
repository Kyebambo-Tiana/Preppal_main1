import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/presentation/providers/inventory_provider.dart';
import 'package:prepal2/presentation/screens/main_shell.dart';

class InventoryDetailsScreen extends StatefulWidget {
  const InventoryDetailsScreen({super.key});

  @override
  State<InventoryDetailsScreen> createState() => _InventoryDetailsScreenState();
}

class _InventoryDetailsScreenState extends State<InventoryDetailsScreen> {
  static const double _defaultOnboardingPrice = 1.0;
  static const int _defaultShelfLifeHours = 168;

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();

  final List<ProductModel> _queuedProducts = [];

  String _selectedTypeLabel = 'Pastries';
  String _selectedUnitLabel = 'PCS';
  DateTime _productionDate = DateTime.now();
  bool _submitting = false;

  final List<String> _productTypes = const [
    'Pastries',
    'Beverages',
    'Dairy',
    'Snacks',
    'Produce',
    'Bakery',
    'Meat',
    'Spices',
    'Frozen',
    'Others',
  ];

  final List<String> _unitLabels = const [
    'KG',
    'G',
    'L',
    'ML',
    'PCS',
    'DOZEN',
    'OTHERS',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  ProductCategory _categoryFromLabel(String label) {
    switch (label) {
      case 'Pastries':
        return ProductCategory.bakery;
      case 'Beverages':
        return ProductCategory.beverages;
      case 'Dairy':
        return ProductCategory.dairy;
      case 'Snacks':
        return ProductCategory.snacks;
      case 'Produce':
        return ProductCategory.produce;
      case 'Bakery':
        return ProductCategory.bakery;
      case 'Meat':
        return ProductCategory.meat;
      case 'Spices':
        return ProductCategory.spices;
      case 'Frozen':
        return ProductCategory.frozen;
      default:
        return ProductCategory.others;
    }
  }

  ProductUnit _unitFromLabel(String label) {
    switch (label) {
      case 'KG':
        return ProductUnit.kg;
      case 'G':
        return ProductUnit.g;
      case 'L':
        return ProductUnit.litre;
      case 'ML':
        return ProductUnit.ml;
      case 'DOZEN':
        return ProductUnit.dozen;
      case 'OTHERS':
        // Keep backend payload compatible with current enum contract.
        return ProductUnit.pcs;
      default:
        return ProductUnit.pcs;
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _productionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _productionDate = picked);
    }
  }

  ProductModel _buildCurrentProduct() {
    return ProductModel(
      id: 'prod_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      category: _categoryFromLabel(_selectedTypeLabel),
      productionDate: _productionDate,
      shelfLife: _defaultShelfLifeHours,
      quantityAvailable: double.parse(_quantityController.text.trim()),
      // Backend requires price > 0; onboarding captures core details first.
      price: _defaultOnboardingPrice,
      unit: _unitFromLabel(_selectedUnitLabel),
      shelf: 0,
      currency: 'NGN',
    );
  }

  void _resetCurrentForm() {
    _nameController.clear();
    _quantityController.clear();
    _productionDate = DateTime.now();
    _selectedTypeLabel = 'Pastries';
    _selectedUnitLabel = 'PCS';
  }

  Future<void> _addAnotherProduct() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _queuedProducts.add(_buildCurrentProduct());
      _resetCurrentForm();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Saved locally: ${_queuedProducts.length} product(s)'),
        backgroundColor: const Color(0xFF4CAF50),
      ),
    );
  }

  Future<void> _saveCurrentToApi() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    final inventory = context.read<InventoryProvider>();
    final ok = await inventory.addProduct(_buildCurrentProduct());

    if (!mounted) return;

    setState(() {
      _submitting = false;
      if (ok) {
        _resetCurrentForm();
      }
    });

    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Product saved successfully'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(inventory.errorMessage ?? 'Failed to save product'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _submitAll() async {
    final List<ProductModel> toSubmit = List<ProductModel>.from(
      _queuedProducts,
    );

    // If current form has values, validate and include it in submit batch.
    final hasCurrentInput =
        _nameController.text.trim().isNotEmpty ||
        _quantityController.text.trim().isNotEmpty;

    if (hasCurrentInput) {
      if (!_formKey.currentState!.validate()) return;
      toSubmit.add(_buildCurrentProduct());
    }

    if (toSubmit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add at least one product before submitting'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final inventory = context.read<InventoryProvider>();
    var failedCount = 0;
    for (final p in toSubmit) {
      final ok = await inventory.addProduct(p);
      if (!ok) failedCount++;
    }

    if (!mounted) return;

    setState(() => _submitting = false);

    if (failedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved ${toSubmit.length - failedCount}/${toSubmit.length}. ${inventory.errorMessage ?? 'Some products failed.'}',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    await inventory.loadProducts();

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
    );
  }

  void _skipToDashboard() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
      (route) => false,
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
          onPressed: _submitting ? null : () => Navigator.pop(context),
        ),
        title: const Text(
          'PrepPal',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i <= 2
                              ? const Color(0xFFD35A2A)
                              : const Color(0xFFE8DEF8),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                const Center(
                  child: Text(
                    'Inventory details',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 28),
                _label('Product name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration('Mega meat pie'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Product name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Product type'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedTypeLabel,
                            decoration: _inputDecoration(''),
                            items: _productTypes
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedTypeLabel = v);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Production date'),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: _pickDate,
                            child: InputDecorator(
                              decoration: _inputDecoration(''),
                              child: Text(
                                '${_productionDate.day.toString().padLeft(2, '0')}-'
                                '${_productionDate.month.toString().padLeft(2, '0')}-'
                                '${_productionDate.year}',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Quantity produced'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _quantityController,
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('24'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              final parsed = double.tryParse(v.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Must be > 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _label('Unit'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedUnitLabel,
                            decoration: _inputDecoration(''),
                            items: _unitLabels
                                .map(
                                  (u) => DropdownMenuItem<String>(
                                    value: u,
                                    child: Text(u),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedUnitLabel = v);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _submitting ? null : _addAnotherProduct,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD35A2A),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add another product'),
                  ),
                ),
                if (_queuedProducts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      '${_queuedProducts.length} product(s) queued for submit',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _submitting ? null : _skipToDashboard,
                    child: const Text('Skip for now'),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _saveCurrentToApi,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFF3CDD3),
                          foregroundColor: const Color(0xFF5A3A3A),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF5A3A3A),
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _submitAll,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD35A2A),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Submit',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: Colors.black,
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFFBDBDBD)),
      filled: true,
      fillColor: const Color(0xFFE8DEF8),
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
    );
  }
}
