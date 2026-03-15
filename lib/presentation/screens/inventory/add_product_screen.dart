import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/presentation/providers/inventory_provider.dart';

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _thresholdController = TextEditingController(); // optional
  final _priceController = TextEditingController();

  ProductCategory _selectedCategory = ProductCategory.others;
  ProductUnit _selectedUnit = ProductUnit.pcs;

  // currencies used in dropdown; backend doesn't persist currency yet but
  // the UI allows selection for future use.
  final List<String> _currencies = ['NGN', 'USD'];
  String _selectedCurrency = 'NGN';

  DateTime _productionDate = DateTime.now();
  final _shelfLifeController = TextEditingController(text: '168'); // hours

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _thresholdController.dispose();
    _priceController.dispose();
    _shelfLifeController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _productionDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFFD32F2F)),
        ),
        child: child!,
      ),
    );

    if (picked != null) {
      setState(() {
        _productionDate = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    // ensure shelf life is non-negative integer
    final shelfLife = int.tryParse(_shelfLifeController.text) ?? -1;
    if (shelfLife < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Shelf life must be zero or more hours'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final product = ProductModel(
      id: 'prod_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim(),
      category: _selectedCategory,
      productionDate: _productionDate,
      shelfLife: shelfLife,
      quantityAvailable: double.parse(_quantityController.text),
      price: double.parse(_priceController.text),
      shelf: 0,
      unit: _selectedUnit,
      currency: _selectedCurrency,
      lowStockThreshold: _thresholdController.text.isEmpty
          ? null
          : double.tryParse(_thresholdController.text),
    );

    final success = await context.read<InventoryProvider>().addProduct(product);

    if (success && mounted) {
      // On web, showing a SnackBar on this route and immediately popping can
      // trigger transient DOM removal errors. Return success and let the
      // previous screen show feedback.
      FocusManager.instance.primaryFocus?.unfocus();
      Navigator.pop(context, true);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<InventoryProvider>().errorMessage ??
                'Error adding product',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = context.watch<InventoryProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F),
        foregroundColor: Colors.white,
        title: const Text('Add Product'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
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
                      color: index < 2
                          ? const Color(0xFFD35A2A)
                          : const Color(0xFFEBEBEB),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Product name',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Whole Milk',
                    ),
                    validator: (v) =>
                        v!.isEmpty ? 'Product name is required' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Product type',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<ProductCategory>(
                              value: _selectedCategory,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: ProductCategory.values.map((cat) {
                                final label =
                                    cat.name[0].toUpperCase() +
                                    cat.name.substring(1);
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(label),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedCategory = val!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DatePickerField(
                          label: 'Production date',
                          date: _productionDate,
                          onTap: _pickDate,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Quantity produced',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _quantityController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'e.g. 50',
                              ),
                              validator: (v) {
                                if (v!.isEmpty) return 'Required';
                                if (double.tryParse(v) == null)
                                  return 'Invalid';
                                if (double.parse(v) <= 0) return 'Must be > 0';
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
                            const Text(
                              'Unit',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<ProductUnit>(
                              value: _selectedUnit,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: ProductUnit.values.map((unit) {
                                return DropdownMenuItem(
                                  value: unit,
                                  child: Text(unit.name.toUpperCase()),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedUnit = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Price per unit',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'e.g. 500',
                              ),
                              validator: (v) {
                                if (v!.isEmpty) return 'Required';
                                if (double.tryParse(v) == null)
                                  return 'Invalid';
                                if (double.parse(v) < 0) return 'Must be ≥ 0';
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
                            const Text(
                              'Currency',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _selectedCurrency,
                              isExpanded: true,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey.shade100,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              items: _currencies
                                  .map(
                                    (c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(c),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedCurrency = val!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Shelf life (hours)',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _shelfLifeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(hintText: 'e.g. 168'),
                        validator: (v) {
                          if (v!.isEmpty) return 'Required';
                          if (int.tryParse(v) == null) return 'Invalid';
                          if (int.parse(v) < 0) return 'Must be ≥ 0';
                          return null;
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: Color(0xFFD32F2F)),
                            foregroundColor: const Color(0xFFD32F2F),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: inventory.isLoading ? null : _handleSubmit,
                          child: inventory.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Submit'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final String label;
  final DateTime date;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.date,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}',
                  style: const TextStyle(fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
