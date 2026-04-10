class DailyData {
  final int day;
  final double kcal;
  final double volume;
  final bool isWorkoutDay;

  DailyData({
    required this.day,
    required this.kcal,
    required this.volume,
    required this.isWorkoutDay,
  });
}

class MonthlyData {
  final String monthName;
  final int year;
  final List<DailyData> dailyData;
  final double completionPercentage;
  final double totalKcal;

  MonthlyData({
    required this.monthName,
    required this.year,
    required this.dailyData,
    required this.completionPercentage,
    required this.totalKcal,
  });

  String get displayName => '$monthName $year';
}
