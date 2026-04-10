import 'dart:math';
import '../models/workout.dart';
import '../models/monthly_data.dart';

class MockData {
  static List<Workout> getWorkouts() {
    return [
      Workout(
        title: 'Push',
        subtitle: 'Chest, Shoulders, Triceps',
        duration: '2 hrs',
        exerciseCount: 8,
        recoveryInfo: RecoveryInfo(
          status: RecoveryStatus.ready,
          percentage: 100,
          description: 'Recovered and ready to go',
        ),
      ),
      Workout(
        title: 'Pull',
        subtitle: 'Back, Biceps',
        duration: '2 hrs',
        exerciseCount: 8,
        recoveryInfo: RecoveryInfo(
          status: RecoveryStatus.almostReady,
          percentage: 83,
          description: 'Almost recovered',
        ),
      ),
      Workout(
        title: 'Legs + Core',
        subtitle: 'Quads, Hamstrings, Glutes, Abs',
        duration: '2.5 hrs',
        exerciseCount: 10,
        recoveryInfo: RecoveryInfo(
          status: RecoveryStatus.notReady,
          percentage: 45,
          description: 'Still recovering',
        ),
      ),
    ];
  }

  static List<MonthlyData> getMonthlyData() {
    final now = DateTime.now(); // Use current date
    final random = Random(42); // Fixed seed for consistent data

    return List.generate(3, (monthIndex) {
      final monthDate = DateTime(now.year, now.month - monthIndex, 1);
      final daysInMonth = DateTime(monthDate.year, monthDate.month + 1, 0).day;

      // For current month, only consider days up to today
      final maxDay = monthIndex == 0
          ? now.day
          : daysInMonth;

      // Calculate expected workouts (3 per week)
      final expectedWorkouts = (maxDay / 7 * 3).round();

      // Generate 80-95% of expected workouts
      final targetCompletion = 0.80 + random.nextDouble() * 0.15;
      final totalWorkoutDays = (expectedWorkouts * targetCompletion).round();

      // Generate workout days only up to maxDay
      final workoutDays = <int>{};
      while (workoutDays.length < totalWorkoutDays) {
        final day = random.nextInt(maxDay) + 1;
        workoutDays.add(day);
      }

      // Base values that increase over time (older months have lower values)
      final baseKcal = 300.0 - (monthIndex * 50.0);
      final baseVolume = 8000.0 - (monthIndex * 1500.0);

      final dailyData = List.generate(daysInMonth, (dayIndex) {
        final day = dayIndex + 1;
        final isWorkoutDay = workoutDays.contains(day);

        if (isWorkoutDay) {
          // Add realistic variation to workout data
          final kcalVariation = random.nextDouble() * 100 - 50;
          final volumeVariation = random.nextDouble() * 2000 - 1000;

          return DailyData(
            day: day,
            kcal: baseKcal + kcalVariation,
            volume: baseVolume + volumeVariation,
            isWorkoutDay: true,
          );
        } else {
          return DailyData(
            day: day,
            kcal: 0,
            volume: 0,
            isWorkoutDay: false,
          );
        }
      });

      final totalKcal = dailyData
          .where((d) => d.isWorkoutDay)
          .fold(0.0, (sum, d) => sum + d.kcal);

      // Calculate completion percentage
      final completionPercent = expectedWorkouts > 0
          ? (workoutDays.length / expectedWorkouts * 100).clamp(0, 100).toDouble()
          : 0.0;

      return MonthlyData(
        monthName: _getMonthName(monthDate.month),
        year: monthDate.year,
        dailyData: dailyData,
        completionPercentage: completionPercent,
        totalKcal: totalKcal,
      );
    });
  }

  static String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }
}
