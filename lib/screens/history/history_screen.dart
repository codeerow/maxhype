import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/monthly_data.dart';
import '../../data/mock_data.dart';
import '../../widgets/monthly_calendar.dart';
import '../../widgets/monthly_chart.dart' show MonthlyChart, ChartData;

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
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Completion percentage
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Completion',
                                  style: Theme.of(context).textTheme.bodyLarge,
                                ),
                                Text(
                                  '${monthData.completionPercentage.toStringAsFixed(0)}%',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Monthly Calendar
                          MonthlyCalendar(
                            monthlyData: [monthData],
                            currentDay: index == 0 ? DateTime.now().day : null,
                          ),
                          const SizedBox(height: 16),
                          // Stats
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.cardBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildStatRow(
                                  'Total KCAL',
                                  monthData.totalKcal.toStringAsFixed(0),
                                ),
                                const SizedBox(height: 12),
                                _buildStatRow(
                                  'Workout Days',
                                  monthData.dailyData
                                      .where((d) => d.isWorkoutDay)
                                      .length
                                      .toString(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Monthly Chart
                          MonthlyChart(
                            chartData: ChartData(
                              monthName: monthData.monthName,
                              year: monthData.year,
                              values: monthData.dailyData.map((d) => d.kcal).toList(),
                              legendText: 'KCAL burned per day',
                            ),
                            title: 'KCAL BURNED',
                            lineColor: AppTheme.primaryOrange,
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
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

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
