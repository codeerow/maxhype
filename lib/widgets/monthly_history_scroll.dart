import 'package:flutter/material.dart';
import '../models/monthly_data.dart';
import '../theme/app_theme.dart';
import 'monthly_chart.dart';

class MonthlyHistoryScroll extends StatefulWidget {
  final List<MonthlyData> monthlyData;

  const MonthlyHistoryScroll({
    super.key,
    required this.monthlyData,
  });

  @override
  State<MonthlyHistoryScroll> createState() => _MonthlyHistoryScrollState();
}

class _MonthlyHistoryScrollState extends State<MonthlyHistoryScroll> {
  final PageController _pageController = PageController();
  late int _currentPage;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.monthlyData.length - 1;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  ChartData _mapToKcalChart(MonthlyData monthData) {
    final workoutDays = monthData.dailyData.where((d) => d.isWorkoutDay).toList();
    return ChartData(
      monthName: monthData.monthName,
      year: monthData.year,
      values: workoutDays.map((d) => d.kcal).toList(),
      legendText: 'Workout Progress This Month\nKCAL',
    );
  }

  ChartData _mapToVolumeChart(MonthlyData monthData) {
    final workoutDays = monthData.dailyData.where((d) => d.isWorkoutDay).toList();
    return ChartData(
      monthName: monthData.monthName,
      year: monthData.year,
      values: workoutDays.map((d) => d.volume).toList(),
      legendText: 'Combined Total Weight for Push, Pull, Legs\nLBS',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 720,
          child: PageView.builder(
            controller: _pageController,
            reverse: true,
            onPageChanged: (index) {
              setState(() {
                // Reverse the index for dots indicator
                _currentPage = widget.monthlyData.length - 1 - index;
              });
            },
            itemCount: widget.monthlyData.length,
            itemBuilder: (context, index) {
              final monthData = widget.monthlyData[index];
              return SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                child: Column(
                  children: [
                    MonthlyChart(
                      chartData: _mapToKcalChart(monthData),
                      title: 'MONTHLY KCAL BURNT',
                      lineColor: AppTheme.chartOrange,
                    ),
                    const SizedBox(height: 8),
                    MonthlyChart(
                      chartData: _mapToVolumeChart(monthData),
                      title: 'MONTHLY VOLUME',
                      lineColor: AppTheme.chartGreen,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            widget.monthlyData.length,
            (index) => Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == index ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? AppTheme.primaryOrange
                    : AppTheme.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
