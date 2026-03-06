import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/presentation/providers/auth_provider.dart';
import 'package:prepal2/presentation/providers/business_provider.dart';
import 'package:prepal2/presentation/providers/dashboard_provider.dart';
import 'package:prepal2/presentation/providers/inventory_provider.dart';
import 'package:prepal2/presentation/providers/daily_sales_provider.dart';
import 'package:prepal2/presentation/screens/sales/daily_sales_report_screen.dart';
import 'package:prepal2/presentation/screens/forecast/demand_forecast_screen.dart';
import 'package:prepal2/presentation/screens/alerts/alerts_screen.dart';
import 'package:prepal2/presentation/screens/auth/business_details_screen.dart';
import 'package:prepal2/presentation/screens/auth/login_screen.dart';
import 'package:prepal2/presentation/screens/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Changed to StatefulWidget so we can call loadSales() on init
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _profileImagePrefsKey = 'dashboard_profile_image_base64';
  Uint8List? _profileImageBytes;
  bool _notificationsEnabled = true;
  bool _compactMode = false;

  @override
  void initState() {
    super.initState();
    _loadSavedHeaderPreferences();
    // Load real sales data from API when dashboard first opens
    Future.microtask(() async {
      if (!mounted) return;
      final business = context.read<BusinessProvider>().currentBusiness;
      final dashboard = context.read<DashboardProvider>();
      // Sync inventory products for alert/recommendation computations
      dashboard.syncInventory(context.read<InventoryProvider>().allProducts);
      // Fetch today's sales from API if business exists
      if (business != null && business.id.isNotEmpty) {
        await dashboard.loadSales(business.id);
      }
    });
  }

  Future<void> _loadSavedHeaderPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final profileBase64 = prefs.getString(_profileImagePrefsKey);
    if (profileBase64 != null && profileBase64.isNotEmpty) {
      setState(() {
        _profileImageBytes = base64Decode(profileBase64);
      });
    }
    setState(() {
      _notificationsEnabled = prefs.getBool('dashboard_notifications_enabled') ?? true;
      _compactMode = prefs.getBool('dashboard_compact_mode') ?? false;
    });
  }

  Future<void> _pickAndSaveProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 512,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_profileImagePrefsKey, base64Encode(bytes));

    if (!mounted) return;
    setState(() {
      _profileImageBytes = bytes;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile picture updated')),
    );
  }

  Future<void> _persistSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _logout() async {
    context.read<BusinessProvider>().reset();
    context.read<InventoryProvider>().reset();
    context.read<DailySalesProvider>().reset();
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete account'),
          content: const Text(
            'This will remove your account session and local app data on this device. Continue?',
          ),
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
        );
      },
    );

    if (confirmed != true || !mounted) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_profileImagePrefsKey);
    await prefs.remove('dashboard_notifications_enabled');
    await prefs.remove('dashboard_compact_mode');

    await _logout();
  }

  Future<void> _goToLogin() async {
    context.read<BusinessProvider>().reset();
    context.read<InventoryProvider>().reset();
    context.read<DailySalesProvider>().reset();
    await context.read<AuthProvider>().logout();
    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openBusinessDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const BusinessDetailsScreen()),
    );

    if (!mounted) return;
    await context.read<BusinessProvider>().loadBusinesses();
  }

  void _openMenuSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              const ListTile(
                title: Text(
                  'Quick Menu',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.photo_camera_back_outlined),
                title: const Text('Update profile picture'),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndSaveProfileImage();
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openSettingsSheet();
                },
              ),
              ListTile(
                leading: const Icon(Icons.business_outlined),
                title: const Text('Business details'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openBusinessDetails();
                },
              ),
              ListTile(
                leading: const Icon(Icons.login),
                title: const Text('Login'),
                onTap: () {
                  Navigator.pop(ctx);
                  _goToLogin();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.red),
                title: const Text('Delete account'),
                onTap: () {
                  Navigator.pop(ctx);
                  _deleteAccount();
                },
              ),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(ctx);
                  _logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Notifications'),
                      value: _notificationsEnabled,
                      onChanged: (v) {
                        setState(() => _notificationsEnabled = v);
                        setModalState(() {});
                        _persistSetting('dashboard_notifications_enabled', v);
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Compact dashboard cards'),
                      value: _compactMode,
                      onChanged: (v) {
                        setState(() => _compactMode = v);
                        setModalState(() {});
                        _persistSetting('dashboard_compact_mode', v);
                      },
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _pickAndSaveProfileImage();
                        },
                        icon: const Icon(Icons.photo_camera_back_outlined),
                        label: const Text('Change profile picture'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final business = context.watch<BusinessProvider>().currentBusiness;
    final inventory = context.watch<InventoryProvider>();
    final dashboard = context.watch<DashboardProvider>();

    // Keep dashboard synced whenever inventory rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) dashboard.syncInventory(inventory.allProducts);
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _DashboardHeader(
                businessName: business?.businessName ?? 'Business',
                wasteReduction: dashboard.wasteReductionPercent,
                highRisk: dashboard.highRiskCount,
                mediumRisk: dashboard.mediumRiskCount,
                lowRisk: dashboard.lowRiskCount,
                profileImageBytes: _profileImageBytes,
                onMenuTap: _openMenuSheet,
                onProfileTap: _pickAndSaveProfileImage,
                onSettingsTap: _openSettingsSheet,
                onBusinessDetailsTap: _openBusinessDetails,
                onDeleteAccountTap: _deleteAccount,
                onLogoutTap: _logout,
              ),
              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //Stats Row
                    _StatsRow(inventory: inventory),
                    const SizedBox(height: 16),

                    //Today's Demand Forecast
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Today\'s demand forecast',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const DemandForecastScreen(),
                              ),
                            );
                          },
                          child: const Text(
                            'View all (6)',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFFD35A2A),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 4,
                            children: [
                              const Text('Predicted Sales', overflow: TextOverflow.ellipsis),
                              _buildLegendItem(label: 'Predicted Sales', color: const Color(0xFFD32F2F)),
                              _buildLegendItem(label: 'Actual Sales', color: const Color(0xFFFFC107)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Align(
                            alignment: Alignment.centerRight,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const DemandForecastScreen(),
                                  ),
                                );
                              },
                              child: Text(
                                'View all (6)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.red[400],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 150,
                            child: CustomPaint(
                              size: const Size(double.infinity, 150),
                              painter: _LineChartPainter(),
                            ),
                          ),
                          // X-axis labels to match wireframe
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('6am', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text('9am', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text('12 noon', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text('3pm', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                Text('6pm', style: TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    //Daily Alert Section 
                 
                    _buildSectionHeader(
                      title: 'Daily Alert',
                      actionText: 'View all (${dashboard.dailyAlerts.length})',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AlertsScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    if (dashboard.dailyAlerts.isEmpty)
                      _buildEmptyCard('✅ No alerts today!')
                    else
                      ...dashboard.dailyAlerts.map((alert) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildAlertCard(
                              title: alert.productName,
                              subtitle: alert.message,
                              severity: alert.severity,
                            ),
                          )),

                    const SizedBox(height: 16),

                    // ── Smart Recommendation Section
                   
                    _buildSectionHeader(
                      title: 'Smart Recommendation',
                      actionText: 'View all (${dashboard.smartRecommendations.length})',
                    ),
                    const SizedBox(height: 8),
                    if (dashboard.smartRecommendations.isEmpty)
                      _buildEmptyCard('✅ All stock levels look good!')
                    else
                      ...dashboard.smartRecommendations.map((rec) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildRecommendationCard(
                              title: rec.productName,
                              subtitle: rec.message,
                            ),
                          )),

                    const SizedBox(height: 16),

                    //Today's Sales Summary
    
                    _buildSalesSummaryCard(dashboard),

                    const SizedBox(height: 24),

                    //Bottom Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.pie_chart_outline,
                            title: 'Today\'s report\nand insights',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DailySalesReportScreen(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildActionButton(
                            icon: Icons.access_time,
                            title: 'Input today\'s\nsales',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DailySalesReportScreen(),
                                ),
                              );
                            },
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



  Widget _buildSectionHeader({
    required String title,
    required String actionText,
    VoidCallback? onTap,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        GestureDetector(
          onTap: onTap,
          child: Text(actionText,
              style: TextStyle(fontSize: 10, color: Colors.red[400], fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildLegendItem({required String label, required Color color}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      CircleAvatar(radius: 5, backgroundColor: color),
      const SizedBox(width: 4),
      Text(label, style: const TextStyle(fontSize: 10, color: Colors.black87)),
    ]);
  }

  // UPDATED: now accepts severity string instead of bool
  Widget _buildAlertCard({
    required String title,
    required String subtitle,
    required String severity,
  }) {
    final isHigh = severity == 'High';
    final isMedium = severity == 'Medium';
    final bg = isHigh ? Colors.red[50]! : isMedium ? Colors.orange[50]! : Colors.yellow[50]!;
    final border = isHigh ? Colors.red[100]! : isMedium ? Colors.orange[100]! : Colors.yellow[100]!;
    final color = isHigh ? Colors.red : isMedium ? Colors.orange : Colors.amber;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isHigh ? Colors.red[100] : Colors.orange[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(severity,
                style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard({required String title, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[100]!),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black87)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // NEW: real sales card
  Widget _buildSalesSummaryCard(DashboardProvider dashboard) {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => const DailySalesReportScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Today Sales',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 8),
            dashboard.isLoadingSales
                ? const SizedBox(height: 28, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    // REAL value from API
                    dashboard.todayRevenueFormatted,
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(
                dashboard.revenueIsUp ? Icons.arrow_upward : Icons.arrow_downward,
                color: dashboard.revenueIsUp ? Colors.green : Colors.red,
                size: 14,
              ),
              const SizedBox(width: 4),
              // ✅ REAL change % vs yesterday
              Text(dashboard.revenueChangeLabel,
                  style: TextStyle(
                      fontSize: 12,
                      color: dashboard.revenueIsUp ? Colors.green : Colors.red)),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Text(message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 13)),
    );
  }

  Widget _buildActionButton({required IconData icon, required String title, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[100]!),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.black87, size: 20),
            const SizedBox(width: 8),
            Text(title, textAlign: TextAlign.start, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

// ── Header Widget ─────────────────────────────────────────────
// CHANGE 2: Accepts real values as parameters instead of hardcoding them

class _DashboardHeader extends StatelessWidget {
  final String businessName;
  final String wasteReduction; // ✅ was hardcoded '35%'
  final int highRisk;          // ✅ was hardcoded '1'
  final int mediumRisk;        // ✅ was hardcoded '0'
  final int lowRisk;           // ✅ was hardcoded '3'
  final Uint8List? profileImageBytes;
  final VoidCallback onMenuTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onBusinessDetailsTap;
  final VoidCallback onDeleteAccountTap;
  final VoidCallback onLogoutTap;

  const _DashboardHeader({
    required this.businessName,
    required this.wasteReduction,
    required this.highRisk,
    required this.mediumRisk,
    required this.lowRisk,
    required this.profileImageBytes,
    required this.onMenuTap,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onBusinessDetailsTap,
    required this.onDeleteAccountTap,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(0xFFD32F2F),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: onMenuTap,
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text('Welcome',
                        style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    // ✅ REAL business name from BusinessProvider
                    Text(businessName,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(_formattedDate(),
                        style: const TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                GestureDetector(
                  onTap: onProfileTap,
                  child: CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white,
                    backgroundImage: profileImageBytes != null
                        ? MemoryImage(profileImageBytes!)
                        : null,
                    child: profileImageBytes == null
                        ? const Icon(Icons.person, color: Color(0xFFD32F2F))
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.settings, color: Colors.white),
                  onSelected: (value) {
                    if (value == 'settings') {
                      onSettingsTap();
                    }
                    if (value == 'business_details') {
                      onBusinessDetailsTap();
                    }
                    if (value == 'delete_account') {
                      onDeleteAccountTap();
                    }
                    if (value == 'logout') {
                      onLogoutTap();
                    }
                  },
                  itemBuilder: (BuildContext context) => const [
                    PopupMenuItem<String>(
                      value: 'settings',
                      child: Row(children: [
                        Icon(Icons.tune),
                        SizedBox(width: 8),
                        Text('Settings'),
                      ]),
                    ),
                    PopupMenuItem<String>(
                      value: 'business_details',
                      child: Row(children: [
                        Icon(Icons.business_outlined),
                        SizedBox(width: 8),
                        Text('Business details'),
                      ]),
                    ),
                    PopupMenuItem<String>(
                      value: 'logout',
                      child: Row(children: [
                        Icon(Icons.logout, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Logout'),
                      ]),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete_account',
                      child: Row(children: [
                        Icon(Icons.delete_forever_outlined, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Delete account'),
                      ]),
                    ),
                  ],
                ),
              ]),
            ],
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.trending_down, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'Waste Reduction',
                            style: const TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      // ✅ REAL VALUE — was hardcoded '35%'
                      Text(wasteReduction,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const Text('from last week', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      const SizedBox(height: 4),
                      const Row(children: [
                        Icon(Icons.info_outline, color: Colors.white70, size: 10),
                        SizedBox(width: 2),
                        Text('more info', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ]),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(Icons.warning_amber, color: Colors.white, size: 16),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Waste Risk levels',
                            style: TextStyle(color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          // ✅ REAL VALUES — were hardcoded '1', '0', '3'
                          _buildRiskPill('High', '$highRisk', Colors.red[100]!, Colors.red),
                          _buildRiskPill('Medium', '$mediumRisk', Colors.orange[100]!, Colors.orange),
                          _buildRiskPill('Low', '$lowRisk', Colors.green[100]!, Colors.green),
                        ],
                      ),
                      const SizedBox(height: 4),
                      const Text('for this week', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      const Row(children: [
                        Icon(Icons.info_outline, color: Colors.white70, size: 10),
                        SizedBox(width: 2),
                        Text('more info', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ]),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _buildRiskPill(String label, String value, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(4)),
      child: Column(children: [
        Text(label, style: TextStyle(color: textColor, fontSize: 9, fontWeight: FontWeight.bold)),
        Text(value, style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}, ${now.year}';
  }
}

// ── Stats Row (unchanged) ─────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final InventoryProvider inventory;
  const _StatsRow({required this.inventory});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      _StatCard(label: 'Total Products', value: '${inventory.totalProducts}',
          icon: Icons.inventory_2, color: const Color(0xFFD32F2F)),
      const SizedBox(width: 12),
      _StatCard(label: 'Low Stock', value: '${inventory.lowStockProducts.length}',
          icon: Icons.warning_amber, color: Colors.orange),
      const SizedBox(width: 12),
      _StatCard(label: 'Expiring Soon', value: '${inventory.expiringSoonProducts.length}',
          icon: Icons.schedule, color: Colors.red),
    ]);
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ),
    );
  }
}

// ── Chart Painter (unchanged) ─────────────────────────────────

class _LineChartPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paintLine1 = Paint()..color = const Color(0xFFD32F2F)..strokeWidth = 2..style = PaintingStyle.stroke;
    final paintLine2 = Paint()..color = const Color(0xFFFFC107)..strokeWidth = 2..style = PaintingStyle.stroke;
    final paintDots1 = Paint()..color = const Color(0xFFD32F2F)..style = PaintingStyle.fill;
    final paintDots2 = Paint()..color = const Color(0xFFFFC107)..style = PaintingStyle.fill;

    final path1 = Path();
    final path2 = Path();

    final points1 = [
      Offset(0, size.height * 0.8),
      Offset(size.width * 0.25, size.height * 0.3),
      Offset(size.width * 0.5, size.height * 0.1),
      Offset(size.width * 0.75, size.height * 0.6),
      Offset(size.width, size.height * 0.85),
    ];
    final points2 = [
      Offset(0, size.height * 0.95),
      Offset(size.width * 0.25, size.height * 0.5),
      Offset(size.width * 0.5, size.height * 0.3),
      Offset(size.width * 0.75, size.height * 0.8),
      Offset(size.width, size.height * 0.9),
    ];

    path1.moveTo(points1[0].dx, points1[0].dy);
    for (int i = 1; i < points1.length; i++) {
      final p0 = points1[i - 1]; final p1 = points1[i];
      path1.cubicTo(p0.dx + (p1.dx - p0.dx) / 2, p0.dy, p0.dx + (p1.dx - p0.dx) / 2, p1.dy, p1.dx, p1.dy);
    }
    path2.moveTo(points2[0].dx, points2[0].dy);
    for (int i = 1; i < points2.length; i++) {
      final p0 = points2[i - 1]; final p1 = points2[i];
      path2.cubicTo(p0.dx + (p1.dx - p0.dx) / 2, p0.dy, p0.dx + (p1.dx - p0.dx) / 2, p1.dy, p1.dx, p1.dy);
    }

    canvas.drawPath(path1, paintLine1);
    canvas.drawPath(path2, paintLine2);
    for (var p in points1) { if (p.dx > 0) canvas.drawCircle(p, 3, paintDots1); }
    for (var p in points2) { if (p.dx > 0) canvas.drawCircle(p, 3, paintDots2); }

    final axisPaint = Paint()..color = Colors.black..strokeWidth = 1;
    canvas.drawLine(const Offset(0, 0), Offset(0, size.height), axisPaint);
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
