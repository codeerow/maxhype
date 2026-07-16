import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _AxisRange {
  const _AxisRange({required this.maxY, required this.interval});

  final double maxY;
  final double interval;

  factory _AxisRange.forMax(double dataMax, {int targetTicks = 5}) {
    if (dataMax <= 0) return const _AxisRange(maxY: 1, interval: 1);

    final rawStep = dataMax / targetTicks;
    final magnitude = math
        .pow(10, (math.log(rawStep) / math.ln10).floor())
        .toDouble();
    final normalized = rawStep / magnitude; // in [1, 10)

    final double niceMultiplier;
    if (normalized <= 1) {
      niceMultiplier = 1;
    } else if (normalized <= 2) {
      niceMultiplier = 2;
    } else if (normalized <= 2.5) {
      niceMultiplier = 2.5;
    } else if (normalized <= 5) {
      niceMultiplier = 5;
    } else {
      niceMultiplier = 10;
    }

    final step = niceMultiplier * magnitude;
    final maxY = (dataMax / step).ceil() * step;
    return _AxisRange(maxY: maxY, interval: step);
  }
}

class ChartData {
  final String monthName;
  final int year;
  final List<double> values;
  final List<int>? days;
  final String legendText;
  final String? totalLabel;
  final String? totalValue;

  ChartData({
    required this.monthName,
    required this.year,
    required this.values,
    this.days,
    required this.legendText,
    this.totalLabel,
    this.totalValue,
  });
}

class MonthlyChart extends StatefulWidget {
  final ChartData chartData;
  final String title;
  final Color lineColor;

  const MonthlyChart({
    super.key,
    required this.chartData,
    required this.title,
    required this.lineColor,
  });

  @override
  State<MonthlyChart> createState() => _MonthlyChartState();
}

class _MonthlyChartState extends State<MonthlyChart> {
  ChartData get chartData => widget.chartData;
  String get title => widget.title;
  Color get lineColor => widget.lineColor;

  @override
  Widget build(BuildContext context) {
    if (chartData.values.isEmpty) {
      return _buildEmptyChart(context);
    }

    final spots = chartData.values.asMap().entries.map((entry) {
      final x = chartData.days != null
          ? chartData.days![entry.key].toDouble()
          : entry.key.toDouble();
      return FlSpot(x, entry.value);
    }).toList();

    final dataMax = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final axis = _AxisRange.forMax(dataMax);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (chartData.totalValue != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (chartData.totalLabel != null)
                  Text(
                    '${chartData.totalLabel}: ',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                    ),
                  ),
                Text(
                  chartData.totalValue!,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: lineColor,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  getDrawingVerticalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.015),
                    strokeWidth: 1,
                  ),
                  horizontalInterval: axis.interval,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Colors.white.withValues(alpha: 0.015),
                    strokeWidth: 1,
                  ),
                ),
                lineTouchData: const LineTouchData(enabled: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      interval: axis.interval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          _formatAxisLabel(value),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 10,
                              ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final day = value.toInt();
                        if (day == value && day % 5 == 0 && day > 0) {
                          return Text(
                            day.toString(),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontSize: 10,
                                ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: axis.maxY,
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: lineColor,
                    barWidth: 3,
                    isStrokeCapRound: true,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          lineColor.withValues(alpha: 0.3),
                          lineColor.withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    shadow: Shadow(
                      color: lineColor.withValues(alpha: 0.5),
                      blurRadius: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            chartData.legendText,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _formatAxisLabel(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  Widget _buildEmptyChart(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 80),
          Center(
            child: Text(
              'No workout data',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}
