import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/presentation/providers/business_provider.dart';
import 'package:prepal2/presentation/screens/auth/inventory_details_screen.dart';

class BusinessDetailsScreen extends StatefulWidget {
  const BusinessDetailsScreen({super.key});

  @override
  State<BusinessDetailsScreen> createState() => _BusinessDetailsScreenState();
}

class _BusinessDetailsScreenState extends State<BusinessDetailsScreen> {
  static const _brandPrimary = Color(0xFF0F7A6B);
  static const _brandPrimaryDark = Color(0xFF0F7A6B);
  static const _brandSoft = Color(0xFFC8E6C9);
  static const _surfaceSoft = Color(0xFFEEF7C0);

  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _locationController =
      TextEditingController(); // renamed from contactAddress
  final _contactNumberController = TextEditingController();
  final _websiteController = TextEditingController();

  // API confirmed businessType values
  String _selectedBusinessType = 'Cafe';
  final List<String> _businessTypes = [
    'Cafe',
    'Restaurant',
    'Hotel kitchen',
    'Private Kitchen',
    'Others',
  ];

  bool _formPrefilled = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_prefillFromExistingBusiness);
  }

  Future<void> _prefillFromExistingBusiness() async {
    if (!mounted || _formPrefilled) return;

    final provider = context.read<BusinessProvider>();
    if (!provider.hasBusiness) {
      await provider.loadBusinesses();
      if (!mounted) return;
    }

    final existing = context.read<BusinessProvider>().currentBusiness;
    if (existing == null || _formPrefilled) return;

    _businessNameController.text = existing.businessName;
    _locationController.text = existing.location;
    _contactNumberController.text = existing.contactNumber;
    _websiteController.text = existing.website;
    if (_businessTypes.contains(existing.businessType)) {
      _selectedBusinessType = existing.businessType;
    }
    _formPrefilled = true;
    setState(() {});
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _locationController.dispose();
    _contactNumberController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _submit({bool navigateAfter = true}) async {
    if (!_formKey.currentState!.validate()) return;

    final success = await context.read<BusinessProvider>().registerBusiness(
      businessName: _businessNameController.text.trim(),
      businessType: _selectedBusinessType,
      // API only accepts: businessName, businessType, location
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : 'Not provided',
      contactNumber: _contactNumberController.text.trim(),
      website: _websiteController.text.trim(),
    );

    if (success && mounted && navigateAfter) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const InventoryDetailsScreen()),
      );
    } else if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Business details saved ✅'),
          backgroundColor: _brandPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BusinessProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.maybePop(context),
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
                // Progress bar
                Row(
                  children: List.generate(
                    4,
                    (i) => Expanded(
                      child: Container(
                        height: 6,
                        margin: EdgeInsets.only(right: i < 3 ? 8 : 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(3),
                          color: i <= 2 ? _brandPrimary : _brandSoft,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                const Center(
                  child: Text(
                    'Business details',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 32),

                // Business Name
                _buildLabel('Business name'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _businessNameController,
                  onChanged: (_) => provider.clearError(),
                  decoration: _inputDecoration('Deliciousness Delight'),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Business name is required'
                      : null,
                ),
                const SizedBox(height: 24),

                // Location (maps to API "location" field)
                _buildLabel('Location (Optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _locationController,
                  maxLines: 2,
                  onChanged: (_) => provider.clearError(),
                  decoration: _inputDecoration(
                    '25, Tomash money close, Mushin, Lagos',
                  ),
                ),
                const SizedBox(height: 24),

                // Business Type & Contact Number row
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLabel('Business type'),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _selectedBusinessType,
                            // ensure the button fills available space rather than
                            // sizing itself to its content. prevents the internal
                            // RenderFlex from collapsing too small and overflowing
                            // when a long business type string is selected.
                            isExpanded: true,
                            decoration: _inputDecoration(''),
                            items: _businessTypes
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              if (v != null)
                                setState(() => _selectedBusinessType = v);
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
                          _buildLabel('Contact number'),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _contactNumberController,
                            keyboardType: TextInputType.phone,
                            onChanged: (_) => provider.clearError(),
                            decoration: _inputDecoration('+234 801 234 5678'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Website
                _buildLabel('Website (Optional)'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _websiteController,
                  keyboardType: TextInputType.url,
                  onChanged: (_) => provider.clearError(),
                  decoration: _inputDecoration('www.deliciousness.com'),
                ),
                const SizedBox(height: 24),

                // Error
                if (provider.errorMessage != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      provider.errorMessage!,
                      style: const TextStyle(
                        color: Color(0xFFB00020),
                        fontSize: 13,
                      ),
                    ),
                  ),

                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: provider.isLoading
                            ? null
                            : () => _submit(navigateAfter: false),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandSoft,
                          foregroundColor: _brandPrimaryDark,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: provider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: _brandPrimaryDark,
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
                        onPressed: provider.isLoading
                            ? null
                            : () => _submit(navigateAfter: true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _brandPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 4,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: provider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Next',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
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
