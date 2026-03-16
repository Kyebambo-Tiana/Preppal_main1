import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/presentation/providers/alerts_provider.dart';
import 'package:prepal2/presentation/providers/business_provider.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({Key? key}) : super(key: key);

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const _brandPrimary = Color(0xFF0F7A6B);
  static const _brandPrimaryDark = Color(0xFF0B5D52);

  String selectedFilter = 'All';
  bool _showCriticalBanner = true;
  bool _highPriorityFirst = true;

  Future<void> _refreshAlerts() async {
    final businessProvider = context.read<BusinessProvider>();
    if (!businessProvider.hasBusiness) {
      await businessProvider.loadBusinesses();
    }

    final business = businessProvider.currentBusiness;
    if (business != null && business.id.isNotEmpty) {
      await context.read<AlertsProvider>().loadAlerts(business.id);
    }
  }

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
      final business = businessProvider.currentBusiness;
      if (business != null && business.id.isNotEmpty) {
        await context.read<AlertsProvider>().loadAlerts(business.id);
      }
    });
  }

  int _severityRank(String severity) {
    switch (severity) {
      case 'High':
        return 0;
      case 'Medium':
        return 1;
      case 'Low':
        return 2;
      default:
        return 3;
    }
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
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
                      'Alert Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Show critical alert banner'),
                      value: _showCriticalBanner,
                      onChanged: (v) {
                        setState(() => _showCriticalBanner = v);
                        setModalState(() {});
                      },
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Sort high priority first'),
                      value: _highPriorityFirst,
                      onChanged: (v) {
                        setState(() => _highPriorityFirst = v);
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() {
                            selectedFilter = 'All';
                            _showCriticalBanner = true;
                            _highPriorityFirst = true;
                          });
                          Navigator.pop(ctx);
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset alert settings'),
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

  Color _getAlertColor(String severity) {
    switch (severity) {
      case 'High':
        return _brandPrimaryDark;
      case 'Medium':
        return const Color(0xFFFFA726);
      case 'Low':
        return const Color(0xFF66BB6A);
      default:
        return Colors.grey;
    }
  }

  IconData _getAlertIcon(String severity) {
    switch (severity) {
      case 'High':
        return Icons.warning_amber_rounded;
      case 'Medium':
        return Icons.info_outline_rounded;
      case 'Low':
        return Icons.check_circle_outline_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  Future<void> _handleMarkRead(AppAlert alert) async {
    if (alert.id.isEmpty) return;

    final ok = await context.read<AlertsProvider>().markAsRead(alert.id);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<AlertsProvider>().errorMessage ??
                'Failed to mark alert as read',
          ),
          backgroundColor: _brandPrimary,
        ),
      );
    }
  }

  Future<void> _handleDelete(AppAlert alert) async {
    if (alert.id.isEmpty) return;

    final ok = await context.read<AlertsProvider>().deleteAlert(alert.id);
    if (!mounted) return;

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.read<AlertsProvider>().errorMessage ??
                'Failed to delete alert',
          ),
          backgroundColor: _brandPrimary,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessProvider = context.watch<BusinessProvider>();
    final alertsProvider = context.watch<AlertsProvider>();
    final alerts = alertsProvider.alerts;

    final filteredAlerts = selectedFilter == 'All'
        ? alerts
        : alerts.where((alert) => alert.severity == selectedFilter).toList();

    if (_highPriorityFirst) {
      filteredAlerts.sort(
        (a, b) =>
            _severityRank(a.severity).compareTo(_severityRank(b.severity)),
      );
    }

    final highCount = alerts.where((a) => a.severity == 'High').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: _brandPrimary,
        elevation: 0,
        title: const Text('Alerts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: businessProvider.currentBusiness == null
                ? null
                : () {
                    final businessId = businessProvider.currentBusiness!.id;
                    context.read<AlertsProvider>().loadAlerts(businessId);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettingsSheet,
          ),
        ],
      ),
      body: alertsProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : alertsProvider.status == AlertsStatus.error
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Colors.grey,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      alertsProvider.errorMessage ?? 'Failed to load alerts',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: businessProvider.currentBusiness == null
                          ? null
                          : () {
                              final businessId =
                                  businessProvider.currentBusiness!.id;
                              context.read<AlertsProvider>().loadAlerts(
                                businessId,
                              );
                            },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                // Critical alert banner
                if (_showCriticalBanner && highCount > 0)
                  Container(
                    color: _brandPrimary,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline,
                          color: Colors.white,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'You have critical alerts',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$highCount item(s) need immediate attention',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Filter chips
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All',
                          isSelected: selectedFilter == 'All',
                          onTap: () {
                            setState(() => selectedFilter = 'All');
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'High',
                          isSelected: selectedFilter == 'High',
                          onTap: () {
                            setState(() => selectedFilter = 'High');
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Medium',
                          isSelected: selectedFilter == 'Medium',
                          onTap: () {
                            setState(() => selectedFilter = 'Medium');
                          },
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Low',
                          isSelected: selectedFilter == 'Low',
                          onTap: () {
                            setState(() => selectedFilter = 'Low');
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Alerts list
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refreshAlerts,
                    child: filteredAlerts.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height:
                                    MediaQuery.of(context).size.height * 0.45,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 64,
                                        color: Colors.grey[300],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No alerts',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: filteredAlerts.length,
                            itemBuilder: (context, index) {
                              final alert = filteredAlerts[index];
                              return _AlertCard(
                                alert: alert,
                                alertColor: _getAlertColor(alert.severity),
                                icon: _getAlertIcon(alert.severity),
                                onMarkRead: () => _handleMarkRead(alert),
                                onDelete: () => _handleDelete(alert),
                              );
                            },
                          ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _AlertsScreenState._brandPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? _AlertsScreenState._brandPrimary
                : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isSelected ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final AppAlert alert;
  final Color alertColor;
  final IconData icon;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  const _AlertCard({
    required this.alert,
    required this.alertColor,
    required this.icon,
    required this.onMarkRead,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: alertColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(color: alertColor.withOpacity(0.1), blurRadius: 4),
        ],
      ),
      child: Row(
        children: [
          // Icon circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: alertColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: alertColor, size: 24),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.productName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert.message,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Live inventory alert',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Severity badge
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: alertColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  alert.severity,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: alertColor,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[700], size: 20),
                onSelected: (value) {
                  if (value == 'read') {
                    onMarkRead();
                  }
                  if (value == 'delete') {
                    onDelete();
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    value: 'read',
                    enabled: !alert.isRead,
                    child: const Text('Mark as read'),
                  ),
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Text('Delete alert'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
