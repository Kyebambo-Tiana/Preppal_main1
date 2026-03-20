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
import 'package:prepal2/presentation/providers/forecast_provider.dart';
import 'package:prepal2/presentation/screens/sales/daily_sales_report_screen.dart';
import 'package:prepal2/presentation/screens/alerts/alerts_screen.dart';
import 'package:prepal2/presentation/screens/auth/business_details_screen.dart';
import 'package:prepal2/presentation/screens/auth/login_screen.dart';
import 'package:prepal2/presentation/screens/splash/splash_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const kDashboardPrimary = Color(0xFF0F7A6B);

// Changed to StatefulWidget so we can call loadSales() on init
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _authUserPrefsKey = 'auth_user';
  static const _profileImagePrefsKey = 'dashboard_profile_image_base64';
  static const _inventoryOnboardingCompletedKey =
      'inventory_onboarding_completed';
  static const _inventoryDraftNameKey = 'inventory_draft_name';
  static const _inventoryDraftQuantityKey = 'inventory_draft_quantity';
  static const _inventoryDraftTypeKey = 'inventory_draft_type';
  static const _inventoryDraftUnitKey = 'inventory_draft_unit';
  static const _inventoryDraftDateKey = 'inventory_draft_date';
  Uint8List? _profileImageBytes;
  bool _notificationsEnabled = true;
  bool _compactMode = false;

  String _scopedPrefsKey(String baseKey, SharedPreferences prefs) {
    final rawUser = prefs.getString(_authUserPrefsKey);
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

  Future<void> _clearOnboardingPrefs(SharedPreferences prefs) async {
    final keys = [
      _inventoryOnboardingCompletedKey,
      _inventoryDraftNameKey,
      _inventoryDraftQuantityKey,
      _inventoryDraftTypeKey,
      _inventoryDraftUnitKey,
      _inventoryDraftDateKey,
    ];

    for (final key in keys) {
      await prefs.remove(key);
      await prefs.remove(_scopedPrefsKey(key, prefs));
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSavedHeaderPreferences();
    // Load real sales data from API when dashboard first opens
    Future.microtask(() async {
      if (!mounted) return;
      final business = context.read<BusinessProvider>().currentBusiness;
      final dashboard = context.read<DashboardProvider>();
      final forecast = context.read<ForecastProvider>();
      // Sync inventory products for alert/recommendation computations
      dashboard.syncInventory(context.read<InventoryProvider>().allProducts);
      // Fetch today's sales from API if business exists
      if (business != null && business.id.isNotEmpty) {
        await dashboard.loadSales(business.id);
        await forecast.loadForecastData();
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
      _notificationsEnabled =
          prefs.getBool('dashboard_notifications_enabled') ?? true;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile picture updated')));
  }

  Future<void> _persistSetting(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _logout() async {
    await context.read<BusinessProvider>().reset();
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
    await _clearOnboardingPrefs(prefs);

    await context.read<DashboardProvider>().clearPersistedCache();
    await context.read<BusinessProvider>().reset(clearCache: true);
    await context.read<InventoryProvider>().clearPersistedCache();
    context.read<InventoryProvider>().reset();
    await context.read<DailySalesProvider>().clearPersistedCache();
    context.read<DailySalesProvider>().reset();
    await context.read<AuthProvider>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  }

  Future<void> _goToLogin() async {
    await context.read<BusinessProvider>().reset();
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
                leading: const Icon(
                  Icons.delete_forever_outlined,
                  color: Colors.red,
                ),
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
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
                      ...dashboard.dailyAlerts.map(
                        (alert) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildAlertCard(
                            title: alert.productName,
                            subtitle: alert.message,
                            severity: alert.severity,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ── Smart Recommendation Section
                    _buildSectionHeader(
                      title: 'Smart Recommendation',
                      actionText:
                          'View all (${dashboard.smartRecommendations.length})',
                    ),
                    const SizedBox(height: 8),
                    if (dashboard.smartRecommendations.isEmpty)
                      _buildEmptyCard('✅ All stock levels look good!')
                    else
                      ...dashboard.smartRecommendations.map(
                        (rec) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildRecommendationCard(
                            title: rec.productName,
                            subtitle: rec.message,
                          ),
                        ),
                      ),

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
                                  builder: (_) =>
                                      const DailySalesReportScreen(),
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
                                  builder: (_) =>
                                      const DailySalesReportScreen(),
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
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            actionText,
            style: TextStyle(
              fontSize: 10,
              color: kDashboardPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // UPDATED: now accepts severity string instead of bool
  Widget _buildAlertCard({
    required String title,
    required String subtitle,
    required String severity,
  }) {
    final isHigh = severity == 'High';
    final isMedium = severity == 'Medium';
    final bg = const Color(0xFFFFF8DC);
    final color = isHigh
        ? const Color(0xFFD32F2F)
        : isMedium
        ? const Color(0xFFF57C00)
        : const Color(0xFFFBC02D);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              severity,
              style: TextStyle(
                color: color,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationCard({
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F9F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Color(0xFF66BB6A),
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
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
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const DailySalesReportScreen()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Today Sales',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            dashboard.isLoadingSales
                ? const SizedBox(
                    height: 28,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    // REAL value from API
                    dashboard.todayRevenueFormatted,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  dashboard.revenueIsUp
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: dashboard.revenueIsUp ? Colors.green : Colors.red,
                  size: 14,
                ),
                const SizedBox(width: 4),
                // ✅ REAL change % vs yesterday
                Text(
                  dashboard.revenueChangeLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: dashboard.revenueIsUp ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8),
        ],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Color(0xFF6B7280),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: kDashboardPrimary,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: kDashboardPrimary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Header Widget ─────────────────────────────────────────────

class _DashboardHeader extends StatelessWidget {
  final String businessName;
  final String wasteReduction;
  final int highRisk;
  final int mediumRisk;
  final int lowRisk;
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
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      decoration: const BoxDecoration(
        color: kDashboardPrimary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              IconButton(
                onPressed: onMenuTap,
                icon: const Icon(Icons.menu, color: Colors.white, size: 24),
                padding: EdgeInsets.zero,
              ),
              Expanded(
                child: Column(
                  children: [
                    const Text(
                      'Welcome',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      businessName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formattedDate(),
                      style: const TextStyle(
                        color: Color(0xFFD9F5EF),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: onProfileTap,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withValues(alpha: 0.9),
                      backgroundImage: profileImageBytes != null
                          ? MemoryImage(profileImageBytes!)
                          : null,
                      child: profileImageBytes == null
                          ? const Icon(
                              Icons.person,
                              color: kDashboardPrimary,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 22,
                    ),
                    padding: EdgeInsets.zero,
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
                        child: Row(
                          children: [
                            Icon(Icons.tune),
                            SizedBox(width: 8),
                            Text('Settings'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'business_details',
                        child: Row(
                          children: [
                            Icon(Icons.business_outlined),
                            SizedBox(width: 8),
                            Text('Business details'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'logout',
                        child: Row(
                          children: [
                            Icon(Icons.logout, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Logout'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'delete_account',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_forever_outlined,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text('Delete account'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.17),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.trending_down_outlined,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Waste Reduction',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        wasteReduction,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'from last week',
                        style: TextStyle(
                          color: Color(0xFFB8ECE5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outlined,
                            color: Color(0xFFB8ECE5),
                            size: 12,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'more info',
                            style: TextStyle(
                              color: Color(0xFFB8ECE5),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.17),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          const Expanded(
                            child: Text(
                              'Waste Risk levels',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildRiskPill(
                            'High',
                            '$highRisk',
                            Colors.red[100]!,
                            Colors.red,
                          ),
                          _buildRiskPill(
                            'Medium',
                            '$mediumRisk',
                            Colors.orange[100]!,
                            Colors.orange,
                          ),
                          _buildRiskPill(
                            'Low',
                            '$lowRisk',
                            Colors.green[100]!,
                            Colors.green,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'for this week',
                        style: TextStyle(
                          color: Color(0xFFB8ECE5),
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outlined,
                            color: Color(0xFFB8ECE5),
                            size: 12,
                          ),
                          SizedBox(width: 3),
                          Text(
                            'more info',
                            style: TextStyle(
                              color: Color(0xFFB8ECE5),
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
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

  static Widget _buildRiskPill(
    String label,
    String value,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: textColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _formattedDate() {
    final now = DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
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
    return Row(
      children: [
        _StatCard(
          label: 'Total Products',
          value: '${inventory.totalProducts}',
          icon: Icons.inventory_2,
          color: kDashboardPrimary,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Low Stock',
          value: '${inventory.lowStockProducts.length}',
          icon: Icons.warning_amber,
          color: Colors.orange,
        ),
        const SizedBox(width: 12),
        _StatCard(
          label: 'Expiring Soon',
          value: '${inventory.expiringSoonProducts.length}',
          icon: Icons.schedule,
          color: Colors.red,
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
