import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/presentation/providers/forecast_provider.dart';
import 'package:prepal2/presentation/screens/alerts/alerts_screen.dart';
import 'package:prepal2/core/utills/food_visuals.dart';

const kForecastPrimary = Color(0xFF0F7A6B);
const kForecastActual = Color(0xFF1F9D84);
const kForecastPredicted = Color(0xFFE59B08);
const kForecastSurface = Color(0xFFE8F5E9);
const kForecastSurfaceBorder = Color(0xFFC8E6C9);
const kForecastTextPrimary = Color(0xFF111827);
const kForecastTextSecondary = Color(0xFF6B7280);

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  if (value is String) {
    final trimmed = value.trim();
    final parsed = double.tryParse(trimmed);
    if (parsed != null) return parsed;

    switch (trimmed.toLowerCase()) {
      case 'high':
        return 90;
      case 'medium':
        return 60;
      case 'low':
        return 30;
      default:
        return fallback;
    }
  }
  return fallback;
}

int _asInt(dynamic value, {int fallback = 0}) {
  return _asDouble(value, fallback: fallback.toDouble()).round();
}

String _dayLabelFromRaw(dynamic raw, int index) {
  final value = (raw ?? '').toString().trim();
  if (value.isEmpty) {
    const defaults = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return defaults[index % defaults.length];
  }

  if (value.length <= 3) return value;
  return value.substring(0, 3);
}

double _roundUpChartMax(double value) {
  if (value <= 0) return 100;
  const step = 50.0;
  return (value / step).ceil() * step;
}

String _resolveImageUrl(Map<String, dynamic> product) {
  const keys = [
    'imageUrl',
    'image_url',
    'image',
    'photo',
    'photoUrl',
    'thumbnail',
  ];

  for (final key in keys) {
    final raw = product[key];
    if (raw is String && raw.trim().isNotEmpty) {
      return raw.trim();
    }
  }
  return '';
}

class DemandForecastScreen extends StatefulWidget {
  final VoidCallback? onClose;
  final VoidCallback? onOpenAlerts;

  const DemandForecastScreen({super.key, this.onClose, this.onOpenAlerts});

  @override
  State<DemandForecastScreen> createState() => _DemandForecastScreenState();
}

class _DemandForecastScreenState extends State<DemandForecastScreen> {
  Future<void> _refreshForecast() async {
    await context.read<ForecastProvider>().loadForecastData();
  }

  void _handleClose() {
    if (widget.onClose != null) {
      widget.onClose!();
      return;
    }

    Navigator.maybePop(context);
  }

  Future<void> _handleOpenAlerts() async {
    if (widget.onOpenAlerts != null) {
      widget.onOpenAlerts!();
      return;
    }

    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const AlertsScreen()));
  }

  Future<void> _copyForecastSummary(ForecastProvider provider) async {
    final lines = <String>[
      'Demand Forecast',
      'Accuracy: ${(provider.forecastAccuracy * 100).toStringAsFixed(1)}%',
      'Insight: ${provider.aiInsight}',
    ];

    for (final product in provider.productForecasts.take(5)) {
      final name =
          (product['name'] ?? product['item_name'] ?? 'Unknown product')
              .toString();
      final today = _asInt(product['today']);
      final tomorrow = _asInt(product['tomorrow']);
      lines.add('$name: today $today, tomorrow $tomorrow');
    }

    await Clipboard.setData(ClipboardData(text: lines.join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Forecast summary copied')));
  }

  Future<void> _openMoreActions(ForecastProvider provider) async {
    final action = await showModalBottomSheet<_ForecastAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                _ForecastActionTile(
                  icon: Icons.refresh,
                  label: 'Refresh forecast',
                  onTap: () =>
                      Navigator.pop(sheetContext, _ForecastAction.refresh),
                ),
                _ForecastActionTile(
                  icon: Icons.notifications_none,
                  label: 'Open alerts',
                  onTap: () =>
                      Navigator.pop(sheetContext, _ForecastAction.alerts),
                ),
                _ForecastActionTile(
                  icon: Icons.content_copy_outlined,
                  label: 'Copy summary',
                  onTap: () =>
                      Navigator.pop(sheetContext, _ForecastAction.copy),
                ),
                _ForecastActionTile(
                  icon: Icons.close,
                  label: 'Close forecast',
                  onTap: () =>
                      Navigator.pop(sheetContext, _ForecastAction.close),
                ),
              ],
            ),
          ),
        );
      },
    );

    switch (action) {
      case _ForecastAction.refresh:
        await _refreshForecast();
      case _ForecastAction.alerts:
        await _handleOpenAlerts();
      case _ForecastAction.copy:
        await _copyForecastSummary(provider);
      case _ForecastAction.close:
        _handleClose();
      case null:
        return;
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<ForecastProvider>().loadForecastData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ForecastProvider>(
      builder: (context, forecastProvider, _) {
        final isLoading = forecastProvider.isLoading;
        final hasData = forecastProvider.forecastData != null;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            leading: IconButton(
              onPressed: _handleClose,
              icon: const Icon(Icons.close, color: Colors.black87),
            ),
            titleSpacing: 0,
            title: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Prepal',
                  style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Demand Forecast',
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                onPressed: _handleOpenAlerts,
                icon: const Icon(
                  Icons.notifications_none,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                onPressed: () => _copyForecastSummary(forecastProvider),
                icon: const Icon(
                  Icons.content_copy_outlined,
                  color: Colors.black87,
                ),
              ),
              IconButton(
                onPressed: () => _openMoreActions(forecastProvider),
                icon: const Icon(Icons.more_vert, color: Colors.black87),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(2),
              child: Container(height: 2, color: const Color(0xFFA7DED2)),
            ),
          ),
          body: isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kForecastPrimary),
                  ),
                )
              : !hasData
              ? _ForecastErrorState(message: forecastProvider.errorMessage)
              : RefreshIndicator(
                  onRefresh: _refreshForecast,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                    children: [
                      _ForecastOverviewCard(
                        sevenDayForecast: forecastProvider.sevenDayForecast,
                      ),
                      const SizedBox(height: 12),
                      _InsightCard(text: forecastProvider.aiInsight),
                      const SizedBox(height: 12),
                      _AccuracyCard(
                        accuracyRatio: forecastProvider.forecastAccuracy,
                      ),
                      const SizedBox(height: 22),
                      const Center(
                        child: Text(
                          'Demand forecast per item',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: kForecastTextPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (forecastProvider.productForecasts.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No product forecasts available yet',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...forecastProvider.productForecasts.map(
                          (product) => _ProductForecastTile(product: product),
                        ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _ForecastErrorState extends StatelessWidget {
  final String? message;

  const _ForecastErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            const Text(
              'Failed to load forecast',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              message ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _ForecastOverviewCard extends StatelessWidget {
  final List<Map<String, dynamic>> sevenDayForecast;

  const _ForecastOverviewCard({required this.sevenDayForecast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '7-days Demand Forecast',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD7F4DE),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'This week',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2F855A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _WeeklyForecastChart(data: sevenDayForecast),
          const SizedBox(height: 12),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: kForecastActual, label: 'Actual Demand'),
              SizedBox(width: 22),
              _LegendDot(color: kForecastPredicted, label: 'Predicted Demand'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
        ),
      ],
    );
  }
}

class _WeeklyForecastChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;

  const _WeeklyForecastChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = data.isEmpty;
    final displayData = isPlaceholder ? _buildPlaceholderForecastData() : data;
    double maxValue = 1;
    for (final point in displayData) {
      final actual = _asDouble(point['actual']);
      final predicted = _asDouble(point['predicted']);
      if (actual > maxValue) maxValue = actual;
      if (predicted > maxValue) maxValue = predicted;
    }

    final chartMax = isPlaceholder ? 250.0 : _roundUpChartMax(maxValue);
    final yAxisValues = List<double>.generate(6, (index) {
      return chartMax - (index * (chartMax / 5));
    });

    return Container(
      height: 210,
      padding: const EdgeInsets.fromLTRB(8, 10, 10, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 32,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: yAxisValues
                  .map(
                    (value) => Text(
                      value.round().toString(),
                      style: const TextStyle(
                        fontSize: 10,
                        color: kForecastTextSecondary,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                const chartHeight = 152.0;

                return Column(
                  children: [
                    SizedBox(
                      height: chartHeight,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _ForecastGridPainter(
                                horizontalDivisions: 5,
                                verticalDivisions: displayData.length,
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: List.generate(displayData.length, (
                                index,
                              ) {
                                final point = displayData[index];
                                final actual = _asDouble(point['actual']);
                                final predicted = _asDouble(point['predicted']);
                                final actualHeight = actual <= 0
                                    ? 0.0
                                    : (actual / chartMax) * 136;
                                final predictedHeight = predicted <= 0
                                    ? 0.0
                                    : (predicted / chartMax) * 136;

                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 2,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        _ChartBar(
                                          height: actualHeight,
                                          color: isPlaceholder
                                              ? kForecastActual.withValues(
                                                  alpha: 0.35,
                                                )
                                              : kForecastActual,
                                        ),
                                        const SizedBox(width: 4),
                                        _ChartBar(
                                          height: predictedHeight,
                                          color: isPlaceholder
                                              ? kForecastPredicted.withValues(
                                                  alpha: 0.35,
                                                )
                                              : kForecastPredicted,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          if (isPlaceholder)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 12,
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    borderRadius: BorderRadius.circular(99),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: const Text(
                                    'Awaiting backend forecast data',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                      color: kForecastTextSecondary,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: List.generate(displayData.length, (index) {
                        final point = displayData[index];
                        final day = _dayLabelFromRaw(point['day'], index);
                        return Expanded(
                          child: Text(
                            day,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4B5563),
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

List<Map<String, dynamic>> _buildPlaceholderForecastData() {
  const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  return days
      .map(
        (day) => <String, dynamic>{'day': day, 'actual': 40, 'predicted': 40},
      )
      .toList(growable: false);
}

class _ForecastGridPainter extends CustomPainter {
  final int horizontalDivisions;
  final int verticalDivisions;

  const _ForecastGridPainter({
    required this.horizontalDivisions,
    required this.verticalDivisions,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final horizontalPaint = Paint()
      ..color = const Color(0xFFE5E7EB)
      ..strokeWidth = 1;
    final verticalPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1;

    for (var i = 0; i <= horizontalDivisions; i++) {
      final y = size.height * (i / horizontalDivisions);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), horizontalPaint);
    }

    for (var i = 0; i <= verticalDivisions; i++) {
      final x = size.width * (i / verticalDivisions);
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), verticalPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ForecastGridPainter oldDelegate) {
    return horizontalDivisions != oldDelegate.horizontalDivisions ||
        verticalDivisions != oldDelegate.verticalDivisions;
  }
}

class _ChartBar extends StatelessWidget {
  final double height;
  final Color color;

  const _ChartBar({required this.height, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: height.clamp(0.0, 136.0),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

enum _ForecastAction { refresh, alerts, copy, close }

class _ForecastActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ForecastActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: kForecastPrimary),
      title: Text(
        label,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: kForecastTextPrimary,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _InsightCard extends StatelessWidget {
  final String text;

  const _InsightCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF0FBEF), Color(0xFFE3F6D8)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kForecastSurfaceBorder),
      ),
      child: Text(
        'AI insight: $text',
        style: const TextStyle(
          fontSize: 12,
          height: 1.3,
          fontWeight: FontWeight.w500,
          color: Color(0xFF334155),
        ),
      ),
    );
  }
}

class _AccuracyCard extends StatelessWidget {
  final double accuracyRatio;

  const _AccuracyCard({required this.accuracyRatio});

  @override
  Widget build(BuildContext context) {
    final safeRatio = accuracyRatio.clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF2FBEC), Color(0xFFDBF4C8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kForecastSurfaceBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Forecast Accuracy',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kForecastTextPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${(safeRatio * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: kForecastTextPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Last 30 days',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.trending_up,
              size: 24,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductForecastTile extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ProductForecastTile({required this.product});

  @override
  Widget build(BuildContext context) {
    final String name =
        (product['name'] ?? product['item_name'] ?? 'Unknown product')
            .toString();
    final int confidence = _asInt(product['confidence']);
    final int today = _asInt(product['today']);
    final int tomorrow = _asInt(product['tomorrow']);
    final double changePercent = today > 0
        ? ((tomorrow - today) / today) * 100
        : 0;
    final bool isUp = changePercent >= 0;
    final String imageUrl = _resolveImageUrl(product);

    final trendColor = isUp ? const Color(0xFF166534) : const Color(0xFFB91C1C);
    final barValue = today <= 0 ? 0.0 : (tomorrow / today).clamp(0.0, 1.0);
    final barColor = isUp ? const Color(0xFF166534) : const Color(0xFFB91C1C);

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FoodThumb(name: name, imageUrl: imageUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1,
                          fontWeight: FontWeight.w600,
                          color: kForecastTextPrimary,
                        ),
                      ),
                    ),
                    Icon(
                      isUp ? Icons.trending_up : Icons.trending_down,
                      size: 16,
                      color: trendColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isUp ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1,
                        fontWeight: FontWeight.w600,
                        color: trendColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Confidence-$confidence',
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1,
                    fontWeight: FontWeight.w400,
                    color: kForecastTextSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      '$today',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        color: isUp ? kForecastTextSecondary : trendColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: barValue,
                          minHeight: 4,
                          backgroundColor: const Color(0xFFE5E7EB),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$tomorrow',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1,
                        fontWeight: FontWeight.w500,
                        color: isUp ? trendColor : kForecastTextSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Row(
                  children: [
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 11,
                        color: kForecastTextSecondary,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Tomorrow',
                      style: TextStyle(
                        fontSize: 11,
                        color: kForecastTextSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FoodThumb extends StatelessWidget {
  final String name;
  final String imageUrl;

  const _FoodThumb({required this.name, required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    if (imageUrl.isNotEmpty) {
      return CircleAvatar(
        radius: 19,
        backgroundColor: const Color(0xFFFFF4D6),
        onBackgroundImageError: (_, __) {},
        backgroundImage: NetworkImage(imageUrl),
      );
    }

    final colors = FoodVisuals.colorsFor(name);
    return CircleAvatar(
      radius: 19,
      backgroundColor: Color(colors.bg),
      child: Text(
        FoodVisuals.emojiFor(name),
        style: const TextStyle(fontSize: 18),
      ),
    );
  }
}
