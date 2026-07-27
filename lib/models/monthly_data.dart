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

  /// Unit label for every [DailyData.volume] in this month ('lb' / 'kg'). The
  /// repository converts volume to the user's chosen unit at the data boundary
  /// and stamps the matching label here, so chart views render the number and
  /// label as-is without doing any conversion themselves.
  final String weightUnitLabel;

  MonthlyData({
    required this.monthName,
    required this.year,
    required this.dailyData,
    required this.completionPercentage,
    required this.totalKcal,
    this.weightUnitLabel = 'lb',
  });

  String get displayName => '$monthName $year';
}
