import 'package:flutter/material.dart';
import '../models/monthly_data.dart';
import '../theme/app_theme.dart';

class MonthlyCalendar extends StatelessWidget {
  final List<MonthlyData> monthlyData;
  final int? currentDay;

  const MonthlyCalendar({
    super.key,
    required this.monthlyData,
    this.currentDay,
  });

  int _getFirstWeekday(int year, int month) {
    final firstDay = DateTime(year, month, 1);
    return firstDay.weekday % 7; // 0 = Sunday
  }

  int _getMonthNumber(String monthName) {
    const months = {
      'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4,
      'May': 5, 'Jun': 6, 'Jul': 7, 'Aug': 8,
      'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12,
    };
    return months[monthName] ?? 1;
  }

  @override
  Widget build(BuildContext context) {
    final monthData = monthlyData.first;
    final daysInMonth = monthData.dailyData.length;
    final monthNum = _getMonthNumber(monthData.monthName);
    final firstWeekday = _getFirstWeekday(monthData.year, monthNum);
    final now = DateTime.now();
    final isCurrentMonth =
        monthData.year == now.year && monthNum == now.month;

    return Column(
      children: [
        // Weekday headers
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['S', 'M', 'T', 'W', 'T', 'F', 'S'].map((d) {
            return SizedBox(
              width: 40,
              child: Center(
                child: Text(
                  d,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppTheme.textSecondary,
                      ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        // Calendar grid
        _buildGrid(context, monthData, firstWeekday, daysInMonth, isCurrentMonth),
      ],
    );
  }

  Widget _buildGrid(
    BuildContext context,
    MonthlyData monthData,
    int firstWeekday,
    int daysInMonth,
    bool isCurrentMonth,
  ) {
    final totalCells = firstWeekday + daysInMonth;
    final totalWeeks = (totalCells / 7).ceil();
    final List<Widget> rows = [];
    int day = 1;

    for (int week = 0; week < totalWeeks; week++) {
      final List<Widget> cells = [];

      for (int weekday = 0; weekday < 7; weekday++) {
        final cellIndex = week * 7 + weekday;

        if (cellIndex < firstWeekday || day > daysInMonth) {
          cells.add(const SizedBox(width: 40, height: 48));
        } else {
          final dayData = monthData.dailyData[day - 1];
          final isToday = isCurrentMonth && day == currentDay;
          cells.add(_buildDayCell(context, day, dayData.isWorkoutDay, isToday));
          day++;
        }
      }

      rows.add(
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: cells,
        ),
      );
    }

    return Column(children: rows);
  }

  Widget _buildDayCell(BuildContext context, int day, bool hasWorkout, bool isToday) {
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: isToday
                ? BoxDecoration(
                    color: AppTheme.textPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Center(
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.w400,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ),
          if (hasWorkout)
            Positioned(
              bottom: 1,
              child: Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(
                  color: AppTheme.recoveryGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
