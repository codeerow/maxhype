import 'package:flutter/material.dart';
import '../models/monthly_data.dart';
import '../theme/app_theme.dart';

class MonthlyCalendar extends StatefulWidget {
  final List<MonthlyData> monthlyData;
  final int? currentDay;

  const MonthlyCalendar({
    super.key,
    required this.monthlyData,
    this.currentDay,
  });

  @override
  State<MonthlyCalendar> createState() => _MonthlyCalendarState();
}

class _MonthlyCalendarState extends State<MonthlyCalendar> {
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

  int _getFirstWeekday(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    return firstDay.weekday % 7; // Convert to 0 = Sunday
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 400,
          child: PageView.builder(
            controller: _pageController,
            reverse: true,
            onPageChanged: (index) {
              setState(() {
                _currentPage = widget.monthlyData.length - 1 - index;
              });
            },
            itemCount: widget.monthlyData.length,
            itemBuilder: (context, index) {
              final monthData = widget.monthlyData[index];
              final daysInMonth = monthData.dailyData.length;
              final firstWeekday = _getFirstWeekday(monthData.year, _getMonthNumber(monthData.monthName));
              final completionPercent = (monthData.completionPercentage).toInt();

              return _buildCalendarCard(
                context,
                monthData,
                daysInMonth,
                firstWeekday,
                completionPercent,
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

  Widget _buildCalendarCard(
    BuildContext context,
    MonthlyData monthData,
    int daysInMonth,
    int firstWeekday,
    int completionPercent,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // Header with stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COMPLETION',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 10,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$completionPercent%',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: completionPercent > 0
                          ? AppTheme.recoveryRed
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              Text(
                '${monthData.monthName} ${monthData.year}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 20,
                    ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'TOTAL KCAL BURNT',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 10,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${monthData.totalKcal.toInt()} kcal',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Weekday headers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((day) {
              return SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    day,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Calendar grid
          _buildCalendarGrid(monthData, firstWeekday, daysInMonth),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(MonthlyData monthData, int firstWeekday, int daysInMonth) {
    final List<Widget> rows = [];
    int currentDay = 1;

    // Calculate total weeks needed
    final totalCells = firstWeekday + daysInMonth;
    final totalWeeks = (totalCells / 7).ceil();

    // Check if this month is the current month
    final now = DateTime.now();
    final isCurrentMonth = monthData.year == now.year &&
                          _getMonthNumber(monthData.monthName) == now.month;

    for (int week = 0; week < totalWeeks; week++) {
      final List<Widget> dayCells = [];

      for (int weekday = 0; weekday < 7; weekday++) {
        final cellIndex = week * 7 + weekday;

        if (cellIndex < firstWeekday || currentDay > daysInMonth) {
          // Empty cell
          dayCells.add(const SizedBox(width: 40, height: 40));
        } else {
          // Day cell
          final dayData = monthData.dailyData[currentDay - 1];
          final isToday = isCurrentMonth && currentDay == widget.currentDay;

          dayCells.add(_buildDayCell(currentDay, dayData.isWorkoutDay, isToday));
          currentDay++;
        }
      }

      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: dayCells,
          ),
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildDayCell(int day, bool hasWorkout, bool isToday) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isToday
            ? AppTheme.textPrimary.withOpacity(0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          '$day',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
            color: hasWorkout
                ? AppTheme.recoveryGreen
                : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }

  int _getMonthNumber(String monthName) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
      'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
      'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    return months[monthName] ?? 1;
  }
}
