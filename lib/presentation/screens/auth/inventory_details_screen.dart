import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/data/models/inventory/product_model.dart';
import 'package:prepal2/presentation/providers/business_provider.dart';
import 'package:prepal2/presentation/providers/inventory_provider.dart';
import 'package:prepal2/presentation/screens/main_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InventoryDetailsScreen extends StatefulWidget {
  const InventoryDetailsScreen({super.key});

  @override
  State<InventoryDetailsScreen> createState() => _InventoryDetailsScreenState();
}

class _InventoryDetailsScreenState extends State<InventoryDetailsScreen> {
  static const _brandPrimary = Color(0xFF0F7A6B);
  static const _brandSoft = Color(0xFFC8E6C9);
  static const _surfaceSoft = Color(0xFFF5E1E8);

  static const double _defaultOnboardingPrice = 1.0;
  static const int _defaultShelfLifeHours = 168;
  static const String _kInventoryOnboardingCompleted =
      'inventory_onboarding_completed';
  static const String _kDraftName = 'inventory_draft_name';
  static const String _kDraftQuantity = 'inventory_draft_quantity';
  static const String _kDraftType = 'inventory_draft_type';
  static const String _kDraftUnit = 'inventory_draft_unit';
  static const String _kDraftDate = 'inventory_draft_date';
  static const String _kDraftPrice = 'inventory_draft_price';
  static const String _kDraftCurrency = 'inventory_draft_currency';
  static const String _kDraftShelfLife = 'inventory_draft_shelf_life';
  static const String _kDraftShelfLifeUnit = 'inventory_draft_shelf_life_unit';
  static const String _kAuthUserKey = 'auth_user';

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _shelfLifeController = TextEditingController();

  final List<ProductModel> _queuedProducts = [];

  String _selectedTypeLabel = 'Pastries';
  String _selectedUnitLabel = 'PCS';
  String _selectedShelfLifeUnit = 'hours';
  String _selectedCurrency = 'NGN';
  DateTime _productionDate = DateTime.now();
  bool _submitting = false;
  int _lastServerSavedCount = 0;

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
  void initState() {
    super.initState();
    Future.microtask(() async {
      await _restoreDraft();
      if (!mounted) return;
      await _ensureBusinessReady();
    });
  }

  String _scopedPrefsKey(String baseKey, SharedPreferences prefs) {
    final rawUser = prefs.getString(_kAuthUserKey);
    if (rawUser == null || rawUser.isEmpty) return baseKey;

    try {
      final decoded = jsonDecode(rawUser);
      if (decoded is Map<String, dynamic>) {
        final userId = decoded['id'] as String?;
        if (userId != null && userId.trim().isNotEmpty) {
          return '${baseKey}_${userId.trim()}';
        }
      }
    } catch (_) {
      // Ignore malformed cached auth payloads.
    }

    return baseKey;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _shelfLifeController.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final nameKey = _scopedPrefsKey(_kDraftName, prefs);
    final quantityKey = _scopedPrefsKey(_kDraftQuantity, prefs);
    final typeKey = _scopedPrefsKey(_kDraftType, prefs);
    final unitKey = _scopedPrefsKey(_kDraftUnit, prefs);
    final dateKey = _scopedPrefsKey(_kDraftDate, prefs);

    final priceKey = _scopedPrefsKey(_kDraftPrice, prefs);
    final currencyKey = _scopedPrefsKey(_kDraftCurrency, prefs);
    final shelfLifeKey = _scopedPrefsKey(_kDraftShelfLife, prefs);
    final shelfLifeUnitKey = _scopedPrefsKey(_kDraftShelfLifeUnit, prefs);

    final cachedName =
        prefs.getString(nameKey) ?? prefs.getString(_kDraftName) ?? '';
    final cachedQuantity =
        prefs.getString(quantityKey) ?? prefs.getString(_kDraftQuantity) ?? '';
    final cachedType = prefs.getString(typeKey) ?? prefs.getString(_kDraftType);
    final cachedUnit = prefs.getString(unitKey) ?? prefs.getString(_kDraftUnit);
    final cachedDate = prefs.getString(dateKey) ?? prefs.getString(_kDraftDate);
    final cachedPrice =
        prefs.getString(priceKey) ?? prefs.getString(_kDraftPrice) ?? '';
    final cachedCurrency =
        prefs.getString(currencyKey) ??
        prefs.getString(_kDraftCurrency) ??
        'NGN';
    final cachedShelfLife =
        prefs.getString(shelfLifeKey) ??
        prefs.getString(_kDraftShelfLife) ??
        '';
    final cachedShelfLifeUnit =
        prefs.getString(shelfLifeUnitKey) ??
        prefs.getString(_kDraftShelfLifeUnit) ??
        'hours';

    _nameController.text = cachedName;
    _quantityController.text = cachedQuantity;
    _priceController.text = cachedPrice;
    _shelfLifeController.text = cachedShelfLife;

    const validCurrencies = ['NGN', r'$'];
    if (validCurrencies.contains(cachedCurrency)) {
      _selectedCurrency = cachedCurrency;
    }

    const validShelfLifeUnits = ['hours', 'days', 'months', 'years'];
    if (validShelfLifeUnits.contains(cachedShelfLifeUnit)) {
      _selectedShelfLifeUnit = cachedShelfLifeUnit;
    }

    if (cachedType != null && _productTypes.contains(cachedType)) {
      _selectedTypeLabel = cachedType;
    }
    if (cachedUnit != null && _unitLabels.contains(cachedUnit)) {
      _selectedUnitLabel = cachedUnit;
    }
    if (cachedDate != null) {
      final parsedDate = DateTime.tryParse(cachedDate);
      if (parsedDate != null) {
        _productionDate = parsedDate;
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _persistDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _scopedPrefsKey(_kDraftName, prefs),
      _nameController.text.trim(),
    );
    await prefs.setString(
      _scopedPrefsKey(_kDraftQuantity, prefs),
      _quantityController.text.trim(),
    );
    await prefs.setString(
      _scopedPrefsKey(_kDraftType, prefs),
      _selectedTypeLabel,
    );
    await prefs.setString(
      _scopedPrefsKey(_kDraftUnit, prefs),
      _selectedUnitLabel,
    );
    await prefs.setString(
      _scopedPrefsKey(_kDraftDate, prefs),
      _productionDate.toIso8601String(),
    );
    await prefs.setString(
      _scopedPrefsKey(_kDraftPrice, prefs),
      _priceController.text.trim(),
    );
    await prefs.setString(
      _scopedPrefsKey(_kDraftCurrency, prefs),
      _selectedCurrency,
    );
    await prefs.setString(
      _scopedPrefsKey(_kDraftShelfLife, prefs),
      _shelfLifeController.text.trim(),
    );
    await prefs.setString(
      _scopedPrefsKey(_kDraftShelfLifeUnit, prefs),
      _selectedShelfLifeUnit,
    );
  }

  Future<void> _markOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _scopedPrefsKey(_kInventoryOnboardingCompleted, prefs),
      true,
    );
  }

  Future<bool> _ensureBusinessReady() async {
    final business = context.read<BusinessProvider>();
    if (business.hasBusiness) return true;

    await business.loadBusinesses();
    return business.hasBusiness;
  }

  ProductCategory _categoryFromLabel(String label) {
    switch (label) {
      case 'Pastries':
      case 'Bakery':
        return ProductCategory.bakery;
      case 'Beverages':
        return ProductCategory.beverages;
      case 'Dairy':
        return ProductCategory.dairy;
      case 'Snacks':
        return ProductCategory.snacks;
      case 'Produce':
        return ProductCategory.produce;
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

  Future<void> _handleClose() async {
    final didPop = await Navigator.maybePop(context);
    if (didPop || !mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  ProductModel _buildCurrentProduct() {
    return ProductModel(
      id: 'prod_${DateTime.now().microsecondsSinceEpoch}',
      name: _nameController.text.trim(),
      category: _categoryFromLabel(_selectedTypeLabel),
      productionDate: _productionDate,
      shelfLife: () {
        final shelfLifeValue =
            int.tryParse(_shelfLifeController.text.trim()) ??
            _defaultShelfLifeHours;
        int shelfLife;
        switch (_selectedShelfLifeUnit) {
          case 'days':
            shelfLife = shelfLifeValue * 24;
            break;
          case 'months':
            shelfLife = shelfLifeValue * 24 * 30;
            break;
          case 'years':
            shelfLife = shelfLifeValue * 24 * 365;
            break;
          default: // hours
            shelfLife = shelfLifeValue;
        }
        return shelfLife;
      }(),
      quantityAvailable: double.parse(_quantityController.text.trim()),
      price:
          double.tryParse(_priceController.text.trim()) ??
          _defaultOnboardingPrice,
      unit: _unitFromLabel(_selectedUnitLabel),
      shelf: 0,
      currency: _selectedCurrency == r'$' ? 'USD' : 'NGN',
    );
  }

  void _resetCurrentForm() {
    _nameController.clear();
    _quantityController.clear();
    _priceController.clear();
    _shelfLifeController.clear();
    _productionDate = DateTime.now();
    _selectedTypeLabel = 'Pastries';
    _selectedUnitLabel = 'PCS';
    _selectedShelfLifeUnit = 'hours';
    _selectedCurrency = 'NGN';
    _persistDraft();
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
        backgroundColor: _brandPrimary,
      ),
    );
  }

  void _removeQueuedProductAt(int index) {
    if (index < 0 || index >= _queuedProducts.length) return;

    final removed = _queuedProducts[index];
    setState(() {
      _queuedProducts.removeAt(index);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Removed ${removed.name} from queue'),
        backgroundColor: _brandPrimary,
      ),
    );
  }

  Future<void> _saveCurrentToApi() async {
    final List<ProductModel> toSubmit = List<ProductModel>.from(
      _queuedProducts,
    );

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
          content: Text('Add at least one product before saving'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final hasBusiness = await _ensureBusinessReady();
    if (!mounted) return;
    if (!hasBusiness) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create business details before saving inventory.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    final inventory = context.read<InventoryProvider>();
    var failedCount = 0;
    for (final product in toSubmit) {
      final ok = await inventory.addProduct(product);
      if (!ok) failedCount++;
    }
    final successCount = toSubmit.length - failedCount;

    if (!mounted) return;

    setState(() {
      _submitting = false;
      _lastServerSavedCount = successCount;
      if (failedCount == 0) {
        _queuedProducts.clear();
        _resetCurrentForm();
      }
    });

    if (failedCount == 0) {
      await _markOnboardingCompleted();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Saved $successCount product(s) to server'),
          backgroundColor: _brandPrimary,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Saved $successCount/${toSubmit.length}. ${inventory.errorMessage ?? 'Some products failed.'}',
          ),
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

    final hasBusiness = await _ensureBusinessReady();
    if (!mounted) return;
    if (!hasBusiness) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Create business details before submitting inventory.'),
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

    setState(() {
      _submitting = false;
      _lastServerSavedCount = toSubmit.length - failedCount;
    });

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

    await _markOnboardingCompleted();

    await inventory.loadProducts();

    if (!mounted) return;

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
          onPressed: _submitting ? null : _handleClose,
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
                          color: i <= 1 ? _brandPrimary : _brandSoft,
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
                  onChanged: (_) => _persistDraft(),
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
                                _persistDraft();
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
                            onTap: () async {
                              await _pickDate();
                              await _persistDraft();
                            },
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
                            onChanged: (_) => _persistDraft(),
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
                                _persistDraft();
                              }
                            },
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
                          _label('Shelf life'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _shelfLifeController,
                            onChanged: (_) => _persistDraft(),
                            keyboardType: TextInputType.number,
                            decoration: _inputDecoration('e.g. 7'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Required';
                              }
                              final parsed = int.tryParse(v.trim());
                              if (parsed == null || parsed <= 0) {
                                return 'Must be > 0';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedShelfLifeUnit,
                            decoration: _inputDecoration(''),
                            items: const [
                              DropdownMenuItem(
                                value: 'hours',
                                child: Text('Hours'),
                              ),
                              DropdownMenuItem(
                                value: 'days',
                                child: Text('Days'),
                              ),
                              DropdownMenuItem(
                                value: 'months',
                                child: Text('Months'),
                              ),
                              DropdownMenuItem(
                                value: 'years',
                                child: Text('Years'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedShelfLifeUnit = v);
                                _persistDraft();
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
                          _label('Price'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _priceController,
                            onChanged: (_) => _persistDraft(),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: _inputDecoration('e.g. 500'),
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
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            isExpanded: true,
                            value: _selectedCurrency,
                            decoration: _inputDecoration(''),
                            items: const [
                              DropdownMenuItem(
                                value: 'NGN',
                                child: Text('NGN'),
                              ),
                              DropdownMenuItem(value: r'$', child: Text(r'$')),
                            ],
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _selectedCurrency = v);
                                _persistDraft();
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
                      backgroundColor: _brandPrimary,
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
                  const SizedBox(height: 12),
                  ...List.generate(_queuedProducts.length, (index) {
                    final item = _queuedProducts[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F7F7),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${item.quantityAvailable.toStringAsFixed(item.quantityAvailable % 1 == 0 ? 0 : 2)} ${item.unit.name.toUpperCase()}',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Delete product',
                            onPressed: _submitting
                                ? null
                                : () => _removeQueuedProductAt(index),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                if (_lastServerSavedCount > 0) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Saved to server: $_lastServerSavedCount product(s)',
                      style: const TextStyle(
                        color: _brandPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _submitting ? null : _saveCurrentToApi,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandSoft,
                          foregroundColor: _brandPrimary,
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
                                  color: _brandPrimary,
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
                          backgroundColor: _brandPrimary,
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
      fillColor: _surfaceSoft,
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
