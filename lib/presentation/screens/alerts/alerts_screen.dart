import 'package:flutter/material.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({Key? key}) : super(key: key);

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  // Mock alerts data
  final List<Map<String, dynamic>> alerts = [
    {
      'type': 'critical',
      'icon': Icons.warning_amber_rounded,
      'title': 'Mega meat pie',
      'message': '8 PCS over Optimal',
      'time': '2 hours ago',
      'icon_emoji': '🥧',
    },
    {
      'type': 'critical',
      'icon': Icons.warning_amber_rounded,
      'title': 'Spaghetti',
      'message': 'Prepare 24KG more',
      'time': '1 hour ago',
      'icon_emoji': '🍝',
    },
    {
      'type': 'warning',
      'icon': Icons.info_outline_rounded,
      'title': 'Jollof rice',
      'message': 'Stock below optimal level',
      'time': '30 min ago',
      'icon_emoji': '🍚',
    },
    {
      'type': 'info',
      'icon': Icons.check_circle_outline_rounded,
      'title': 'Chicken',
      'message': 'Stock at optimal level',
      'time': '15 min ago',
      'icon_emoji': '🍗',
    },
    {
      'type': 'critical',
      'icon': Icons.warning_amber_rounded,
      'title': 'Jollof rice (Brown)',
      'message': 'Expired product detected',
      'time': '5 min ago',
      'icon_emoji': '🍚',
    },
  ];

  String selectedFilter = 'All';

  List<Map<String, dynamic>> get filteredAlerts {
    if (selectedFilter == 'All') return alerts;
    return alerts.where((alert) => alert['type'] == selectedFilter).toList();
  }

  Color _getAlertColor(String type) {
    switch (type) {
      case 'critical':
        return const Color(0xFFD32F2F);
      case 'warning':
        return const Color(0xFFFFC107);
      case 'info':
        return const Color(0xFF4CAF50);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    int criticalCount = alerts.where((a) => a['type'] == 'critical').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD35A2A),
        elevation: 0,
        title: const Text('Alerts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Critical alert banner
          if (criticalCount > 0)
            Container(
              color: const Color(0xFFD35A2A),
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
                          '$criticalCount item(s) need immediate attention',
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
                    label: 'Critical',
                    isSelected: selectedFilter == 'critical',
                    onTap: () {
                      setState(() => selectedFilter = 'critical');
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Warning',
                    isSelected: selectedFilter == 'warning',
                    onTap: () {
                      setState(() => selectedFilter = 'warning');
                    },
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Info',
                    isSelected: selectedFilter == 'info',
                    onTap: () {
                      setState(() => selectedFilter = 'info');
                    },
                  ),
                ],
              ),
            ),
          ),

          // Alerts list
          Expanded(
            child: filteredAlerts.isEmpty
                ? Center(
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
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredAlerts.length,
                    itemBuilder: (context, index) {
                      final alert = filteredAlerts[index];
                      return _AlertCard(
                        alert: alert,
                        alertColor: _getAlertColor(alert['type']),
                      );
                    },
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
          color: isSelected ? const Color(0xFFD35A2A) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFD35A2A) : Colors.grey[300]!,
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
  final Map<String, dynamic> alert;
  final Color alertColor;

  const _AlertCard({
    required this.alert,
    required this.alertColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: alertColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: alertColor.withOpacity(0.1),
            blurRadius: 4,
          ),
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
            child: Icon(
              alert['icon'],
              color: alertColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert['title'],
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['message'],
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  alert['time'],
                  style: const TextStyle(
                    fontSize: 11,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),

          // Product emoji
          Text(
            alert['icon_emoji'],
            style: const TextStyle(fontSize: 24),
          ),
        ],
      ),
    );
  }
}
