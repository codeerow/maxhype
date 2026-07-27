import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/monthly_data.dart';

class AllTimeCharts extends StatelessWidget {
  final List<MonthlyData> monthlyData;

  const AllTimeCharts({super.key, required this.monthlyData});

  @override
  Widget build(BuildContext context) {
    // Sort oldest to newest
    final sorted = [...monthlyData].reversed.toList();

    // Volume is already in the user's unit — the repository converted it at the
    // data boundary and stamped the label. This view stays unit-agnostic.
    final unitLabel =
        monthlyData.isNotEmpty ? monthlyData.first.weightUnitLabel : 'lb';

    // One point per calendar day across all history (including rest days).
    // Cumulative value stays flat on rest days and jumps up on workout days
    // — the same "stair-stepping" silhouette as the History chart.
    final kcalSpots = <FlSpot>[];
    final volumeSpots = <FlSpot>[];
    double cumKcal = 0;
    double cumVolume = 0;
    int i = 0;

    for (final month in sorted) {
      for (final day in month.dailyData) {
        cumKcal += day.kcal;
        cumVolume += day.volume;
        kcalSpots.add(FlSpot(i.toDouble(), cumKcal));
        volumeSpots.add(FlSpot(i.toDouble(), cumVolume));
        i++;
      }
    }

    if (kcalSpots.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        _buildChart(
          context,
          title: 'ALL-TIME KCAL',
          spots: kcalSpots,
          lineColor: AppTheme.chartOrange,
          totalValue: '${cumKcal.toInt()} kcal',
          legendText: 'Cumulative calories burned',
        ),
        _buildChart(
          context,
          title: 'ALL-TIME VOLUME',
          spots: volumeSpots,
          lineColor: AppTheme.chartGreen,
          totalValue: '${(cumVolume / 1000).toStringAsFixed(1)}k $unitLabel',
          legendText: 'Cumulative volume lifted, $unitLabel',
        ),
      ],
    );
  }

  Widget _buildChart(
    BuildContext context, {
    required String title,
    required List<FlSpot> spots,
    required Color lineColor,
    required String totalValue,
    required String legendText,
  }) {
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

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
          const SizedBox(height: 8),
          Text(
            totalValue,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: lineColor,
            ),
          ),
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
                  horizontalInterval: null,
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
                      getTitlesWidget: (value, meta) => Text(
                        _format(value),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
                      ),
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minY: 0,
                maxY: maxY * 1.2,
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
            legendText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 10),
          ),
        ],
      ),
    );
  }

  String _format(double value) {
    if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
    if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
    return value.toStringAsFixed(0);
  }
}
