import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/monthly_data.dart';
import '../../data/mock_data.dart';
import '../../widgets/monthly_calendar.dart';
import '../../widgets/monthly_chart.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  late PageController _pageController;
  late List<MonthlyData> _monthlyData;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _monthlyData = MockData.getMonthlyData();
    _pageController = PageController(initialPage: _currentPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _navigateToMonth(int delta) {
    final newPage = (_currentPage + delta).clamp(0, _monthlyData.length - 1);
    _pageController.animateToPage(
      newPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'History',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 24),
            // Month navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left arrow - go to past (older months)
                  IconButton(
                    onPressed: _currentPage < _monthlyData.length - 1
                        ? () => _navigateToMonth(1)
                        : null,
                    icon: const Icon(Icons.chevron_left),
                    color: AppTheme.textPrimary,
                    disabledColor: AppTheme.textSecondary.withOpacity(0.3),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_monthlyData[_currentPage].monthName} ${_monthlyData[_currentPage].year}',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ),
                  // Right arrow - go to future (newer months)
                  IconButton(
                    onPressed: _currentPage > 0 ? () => _navigateToMonth(-1) : null,
                    icon: const Icon(Icons.chevron_right),
                    color: AppTheme.textPrimary,
                    disabledColor: AppTheme.textSecondary.withOpacity(0.3),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // PageView for month data
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                reverse: true, // Swipe left = go to past
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: _monthlyData.length,
                itemBuilder: (context, index) {
                  final monthData = _monthlyData[index];
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Monthly Calendar
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: MonthlyCalendar(
                            monthlyData: [monthData],
                            currentDay: index == 0 ? DateTime.now().day : null,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Monthly Charts (margins built into MonthlyChart)
                        Builder(builder: (context) {
                          final workoutDays = monthData.dailyData
                              .where((d) => d.isWorkoutDay)
                              .toList();
                          final days = workoutDays.map((d) => d.day).toList();
                          return Column(
                            children: [
                              MonthlyChart(
                                chartData: ChartData(
                                  monthName: monthData.monthName,
                                  year: monthData.year,
                                  values: workoutDays.map((d) => d.kcal).toList(),
                                  days: days,
                                  legendText: 'Calories burned per workout, kcal',
                                  totalLabel: 'Total',
                                  totalValue: '${monthData.totalKcal.toInt()} kcal',
                                ),
                                title: 'MONTHLY KCAL BURNT',
                                lineColor: AppTheme.chartOrange,
                              ),
                              MonthlyChart(
                                chartData: ChartData(
                                  monthName: monthData.monthName,
                                  year: monthData.year,
                                  values: workoutDays.map((d) => d.volume).toList(),
                                  days: days,
                                  legendText: 'Total weight lifted per workout, lbs',
                                  totalLabel: 'Total',
                                  totalValue: '${workoutDays.fold<double>(0, (s, d) => s + d.volume).toInt()} lbs',
                                ),
                                title: 'MONTHLY VOLUME',
                                lineColor: AppTheme.chartGreen,
                              ),
                            ],
                          );
                        }),
                        const SizedBox(height: 24),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}
