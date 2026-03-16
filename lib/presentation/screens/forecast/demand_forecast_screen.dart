import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:prepal2/presentation/providers/forecast_provider.dart';

const kForecastPrimary = Color(0xFF0F7A6B);
const kForecastSurface = Color(0xFFE8F5E9);
const kForecastSurfaceBorder = Color(0xFFC8E6C9);

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

class DemandForecastScreen extends StatefulWidget {
  const DemandForecastScreen({super.key});

  @override
  State<DemandForecastScreen> createState() => _DemandForecastScreenState();
}

class _DemandForecastScreenState extends State<DemandForecastScreen> {
  @override
  void initState() {
    super.initState();
    // Load forecast data when screen initializes
    Future.microtask(() {
      context.read<ForecastProvider>().loadForecastData();
    });
  }

  int _totalTomorrowUnits(List<Map<String, dynamic>> products) {
    return products.fold<int>(0, (sum, product) {
      final tomorrow = _asInt(product['tomorrow']);
      return sum + tomorrow;
    });
  }

  double _averageConfidence(List<Map<String, dynamic>> products) {
    if (products.isEmpty) return 0;
    final total = products.fold<int>(0, (sum, product) {
      return sum + _asInt(product['confidence']);
    });
    return total / products.length;
  }

  double _averageDemandChange(List<Map<String, dynamic>> products) {
    if (products.isEmpty) return 0;
    double totalPercent = 0;
    for (final product in products) {
      final today = _asDouble(product['today']);
      final tomorrow = _asDouble(product['tomorrow']);
      if (today <= 0) continue;
      totalPercent += ((tomorrow - today) / today) * 100;
    }
    return totalPercent / products.length;
  }

  Map<String, dynamic>? _highestDemandItem(
    List<Map<String, dynamic>> products,
  ) {
    if (products.isEmpty) return null;
    return products.reduce((a, b) {
      final aTomorrow = _asDouble(a['tomorrow']);
      final bTomorrow = _asDouble(b['tomorrow']);
      return aTomorrow >= bTomorrow ? a : b;
    });
  }

  Map<String, dynamic>? _lowestDemandItem(List<Map<String, dynamic>> products) {
    if (products.isEmpty) return null;
    return products.reduce((a, b) {
      final aTomorrow = _asDouble(a['tomorrow']);
      final bTomorrow = _asDouble(b['tomorrow']);
      return aTomorrow <= bTomorrow ? a : b;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ForecastProvider>(
      builder: (context, forecastProvider, _) {
        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F5),
          appBar: AppBar(
            backgroundColor: kForecastPrimary,
            elevation: 0,
            title: const Text(
              'Demand Forecast',
              style: TextStyle(color: Colors.white),
            ),
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
            ],
          ),
          body: forecastProvider.isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(kForecastPrimary),
                  ),
                )
              : forecastProvider.forecastData == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: Colors.red,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load forecast',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        forecastProvider.errorMessage ?? 'Unknown error',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Header section with subtitle
                      Container(
                        color: kForecastPrimary,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '7-days Demand Forecast',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Bar Chart with real data
                            Container(
                              height: 220,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 20,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Expanded(
                                    child: LayoutBuilder(
                                      builder: (context, constraints) {
                                        return CustomPaint(
                                          size: Size(
                                            constraints.maxWidth,
                                            constraints.maxHeight,
                                          ),
                                          painter: _LineChartPainter(
                                            data: forecastProvider
                                                .sevenDayForecast,
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  // X Axis labels
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: List.generate(
                                      forecastProvider.sevenDayForecast.length,
                                      (index) => Text(
                                        forecastProvider
                                                .sevenDayForecast[index]['day'] ??
                                            'Day ${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),
                            // Legend
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: kForecastPrimary,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Actual Demand',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 24),
                                Row(
                                  children: [
                                    Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFC107),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Predicted Demand',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Forecast Accuracy Card
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: kForecastSurface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: kForecastSurfaceBorder,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Forecast Accuracy',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Last 30 days',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '${(forecastProvider.forecastAccuracy * 100).toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                            const Icon(
                              Icons.trending_up,
                              color: kForecastPrimary,
                              size: 48,
                            ),
                          ],
                        ),
                      ),

                      // AI Insight
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: kForecastSurface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: kForecastSurfaceBorder,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.lightbulb_outline,
                              color: kForecastPrimary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                forecastProvider.aiInsight,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Extra summary details requested in design
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ForecastMetricCard(
                                title: 'Total Tomorrow',
                                value:
                                    '${_totalTomorrowUnits(forecastProvider.productForecasts)} units',
                                subtitle: 'Across all items',
                                icon: Icons.inventory_2_outlined,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ForecastMetricCard(
                                title: 'Avg Confidence',
                                value:
                                    '${_averageConfidence(forecastProvider.productForecasts).toStringAsFixed(1)}%',
                                subtitle: 'Model confidence',
                                icon: Icons.verified_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Expanded(
                              child: _ForecastMetricCard(
                                title: 'Avg Demand Change',
                                value:
                                    '${_averageDemandChange(forecastProvider.productForecasts).toStringAsFixed(1)}%',
                                subtitle: 'Tomorrow vs today',
                                icon: Icons.timeline,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _ForecastMetricCard(
                                title: 'Top Demand Item',
                                value:
                                    '${(_highestDemandItem(forecastProvider.productForecasts)?['name'] ?? 'N/A')}',
                                subtitle:
                                    '${_asInt(_highestDemandItem(forecastProvider.productForecasts)?['tomorrow'])} units tomorrow',
                                icon: Icons.local_fire_department_outlined,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFECECEC)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.arrow_downward,
                                size: 18,
                                color: Color(0xFF5E5E5E),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Lowest expected demand: ${(_lowestDemandItem(forecastProvider.productForecasts)?['name'] ?? 'N/A')} (${_asInt(_lowestDemandItem(forecastProvider.productForecasts)?['tomorrow'])} units)',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF5E5E5E),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Per-item forecasts
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Demand forecast per item',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            forecastProvider.productForecasts.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 24,
                                      ),
                                      child: Text(
                                        'No product forecasts available',
                                        style: Theme.of(
                                          context,
                                        ).textTheme.bodySmall,
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: forecastProvider
                                        .productForecasts
                                        .length,
                                    itemBuilder: (context, index) {
                                      final product = forecastProvider
                                          .productForecasts[index];
                                      return _ProductForecastCard(
                                        product: product,
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _ForecastMetricCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;

  const _ForecastMetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFECECEC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: kForecastPrimary),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

class _ProductForecastCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ProductForecastCard({required this.product});

  @override
  Widget build(BuildContext context) {
    // Extract data from API response with safe defaults
    final String name =
        (product['name'] ?? product['item_name'] ?? 'Unknown Product')
            .toString();
    final int confidence = _asInt(product['confidence']);
    final int today = _asInt(product['today']);
    final int tomorrow = _asInt(product['tomorrow']);

    // Calculate percentage change
    final double changePercent = today > 0
        ? ((tomorrow - today) / today * 100)
        : 0;
    final bool isIncreasing = changePercent >= 0;

    double todayPercent = (today / 100).clamp(0.0, 1.0);
    double tomorrowPercent = (tomorrow / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with name and confidence
          Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Confidence ${confidence}%',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF4CAF50),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isIncreasing
                      ? const Color(0xFFC8E6C9)
                      : const Color(0xFFFFCDD2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${isIncreasing ? '+' : ''}${changePercent.toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isIncreasing
                        ? const Color(0xFF2E7D32)
                        : const Color(0xFFC62828),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Today forecast
          Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: todayPercent,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          kForecastPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$today units',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Tomorrow forecast
          Row(
            children: [
              SizedBox(
                width: 70,
                child: Text(
                  'Tomorrow',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: tomorrowPercent,
                        minHeight: 6,
                        backgroundColor: Colors.grey[200],
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFF4CAF50),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$tomorrow units',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;

  _LineChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) {
      // Draw empty state
      final textPainter = TextPainter(
        text: const TextSpan(
          text: 'No data available',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset((size.width - textPainter.width) / 2, size.height / 2),
      );
      return;
    }

    final paintLine1 = Paint()
      ..color = kForecastPrimary
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintLine2 = Paint()
      ..color = const Color(0xFFFFC107)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final paintDots1 = Paint()
      ..color = kForecastPrimary
      ..style = PaintingStyle.fill;

    final paintDots2 = Paint()
      ..color = const Color(0xFFFFC107)
      ..style = PaintingStyle.fill;

    final path1 = Path();
    final path2 = Path();

    // Find max values for scaling
    double maxActual = 100;
    double maxPredicted = 100;

    for (var point in data) {
      final actual = _asDouble(point['actual']);
      final predicted = _asDouble(point['predicted']);
      if (actual > maxActual) maxActual = actual;
      if (predicted > maxPredicted) maxPredicted = predicted;
    }

    // Add padding to max values
    maxActual = maxActual * 1.1;
    maxPredicted = maxPredicted * 1.1;

    // Generate points for both lines
    final List<Offset> points1 = [];
    final List<Offset> points2 = [];

    for (int i = 0; i < data.length; i++) {
      final actual = _asDouble(data[i]['actual']);
      final predicted = _asDouble(data[i]['predicted']);

      final x = (i / (data.length - 1)) * size.width;
      final y1 = size.height - (actual / maxActual) * size.height;
      final y2 = size.height - (predicted / maxPredicted) * size.height;

      points1.add(Offset(x, y1));
      points2.add(Offset(x, y2));
    }

    // Draw smooth curves
    if (points1.isNotEmpty) {
      path1.moveTo(points1[0].dx, points1[0].dy);
      for (int i = 1; i < points1.length; i++) {
        final p0 = points1[i - 1];
        final p1 = points1[i];
        path1.quadraticBezierTo(
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
          p1.dx,
          p1.dy,
        );
      }
    }

    if (points2.isNotEmpty) {
      path2.moveTo(points2[0].dx, points2[0].dy);
      for (int i = 1; i < points2.length; i++) {
        final p0 = points2[i - 1];
        final p1 = points2[i];
        path2.quadraticBezierTo(
          (p0.dx + p1.dx) / 2,
          (p0.dy + p1.dy) / 2,
          p1.dx,
          p1.dy,
        );
      }
    }

    canvas.drawPath(path1, paintLine1);
    canvas.drawPath(path2, paintLine2);

    // Draw dots for actual demand
    for (var point in points1) {
      canvas.drawCircle(point, 4, paintDots1);
      canvas.drawCircle(point, 2, Paint()..color = Colors.white);
    }

    // Draw dots for predicted demand
    for (var point in points2) {
      canvas.drawCircle(point, 4, paintDots2);
      canvas.drawCircle(point, 2, Paint()..color = Colors.white);
    }

    // Grid lines (horizontal)
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    final int hLines = 4;
    for (int i = 0; i <= hLines; i++) {
      final y = size.height * (i / hLines);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) => oldDelegate.data != data;
}
