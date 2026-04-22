import 'dart:math';
import '../models/workout.dart';
import '../models/monthly_data.dart';
import '../models/muscle_group.dart';
import '../models/all_time_stats.dart';
import '../repositories/mock_exercise_repository.dart';

class MockData {
  static final _exerciseRepo = MockExerciseRepository();

  static List<Workout> getWorkouts() {
    // Get exercises for each workout
    final pushExercises = [
      _exerciseRepo.getExerciseById('ex_002')!, // Dumbbell Bench Press
      _exerciseRepo.getExerciseById('ex_004')!, // Decline Barbell Bench Press
      _exerciseRepo.getExerciseById('ex_009')!, // Standing Dumbbell Shoulder Press
      _exerciseRepo.getExerciseById('ex_011')!, // Lateral Dumbbell Raise
      _exerciseRepo.getExerciseById('ex_015')!, // Tricep Pushdown
      _exerciseRepo.getExerciseById('ex_016')!, // Dips
      _exerciseRepo.getExerciseById('ex_005')!, // Cable Chest Fly
      _exerciseRepo.getExerciseById('ex_017')!, // Overhead Dumbbell Tricep Extension
    ];

    final pullExercises = [
      _exerciseRepo.getExerciseById('ex_020')!, // Pull-ups
      _exerciseRepo.getExerciseById('ex_021')!, // Barbell Row
      _exerciseRepo.getExerciseById('ex_022')!, // Lat Pulldown
      _exerciseRepo.getExerciseById('ex_023')!, // Dumbbell Row
      _exerciseRepo.getExerciseById('ex_024')!, // Seated Cable Row
      _exerciseRepo.getExerciseById('ex_027')!, // Barbell Curl
      _exerciseRepo.getExerciseById('ex_028')!, // Dumbbell Curl
      _exerciseRepo.getExerciseById('ex_025')!, // Face Pulls
    ];

    final legsExercises = [
      _exerciseRepo.getExerciseById('ex_032')!, // Barbell Squat
      _exerciseRepo.getExerciseById('ex_033')!, // Leg Press
      _exerciseRepo.getExerciseById('ex_037')!, // Romanian Deadlift
      _exerciseRepo.getExerciseById('ex_038')!, // Leg Curl
      _exerciseRepo.getExerciseById('ex_040')!, // Hip Thrust
      _exerciseRepo.getExerciseById('ex_034')!, // Bulgarian Split Squat
      _exerciseRepo.getExerciseById('ex_042')!, // Standing Calf Raise
      _exerciseRepo.getExerciseById('ex_044')!, // Cable Crunch
      _exerciseRepo.getExerciseById('ex_045')!, // Hanging Leg Raise
      _exerciseRepo.getExerciseById('ex_046')!, // Plank
    ];

    return [
      Workout(
        id: 'workout_001',
        title: 'Push',
        subtitle: 'Chest, Shoulders, Triceps',
        duration: '2 hrs',
        exerciseCount: pushExercises.length,
        exercises: pushExercises,
        targetMuscles: [
          MuscleGroup.chest,
          MuscleGroup.shoulders,
          MuscleGroup.triceps,
        ],
        recoveryInfo: RecoveryInfo(
          status: RecoveryStatus.ready,
          percentage: 100,
          description: 'Recovered and ready to go',
        ),
      ),
      Workout(
        id: 'workout_002',
        title: 'Pull',
        subtitle: 'Back, Biceps',
        duration: '2 hrs',
        exerciseCount: pullExercises.length,
        exercises: pullExercises,
        targetMuscles: [
          MuscleGroup.back,
          MuscleGroup.biceps,
        ],
        recoveryInfo: RecoveryInfo(
          status: RecoveryStatus.almostReady,
          percentage: 83,
          description: 'Almost recovered',
        ),
      ),
      Workout(
        id: 'workout_003',
        title: 'Legs + Core',
        subtitle: 'Quads, Hamstrings, Glutes, Abs',
        duration: '2.5 hrs',
        exerciseCount: legsExercises.length,
        exercises: legsExercises,
        targetMuscles: [
          MuscleGroup.quads,
          MuscleGroup.hamstrings,
          MuscleGroup.glutes,
          MuscleGroup.abs,
        ],
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

      // ~40% completion: ~12 workout days per 30-day month, scaled to maxDay
      final targetWorkoutDays = (maxDay * 0.40).round().clamp(1, maxDay);

      // Natural spacing: 1 workout day, then 1-2 rest days, repeat
      // This gives ~33-50% completion and keeps rest days evenly spread
      final workoutDays = <int>{};
      int day = 1 + random.nextInt(2); // start on day 1 or 2

      while (workoutDays.length < targetWorkoutDays && day <= maxDay) {
        workoutDays.add(day);
        // After each workout: rest 1-2 days before next
        day += 2 + random.nextInt(2);
      }

      final expectedWorkouts = targetWorkoutDays;

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

  static AllTimeStats getAllTimeStats() {
    final monthlyData = getMonthlyData();

    // Calculate totals from monthly data
    final totalWorkouts = monthlyData.fold<int>(
      0,
      (sum, month) => sum + month.dailyData.where((d) => d.isWorkoutDay).length,
    );

    final totalKcal = monthlyData.fold<double>(
      0,
      (sum, month) => sum + month.totalKcal,
    );

    final totalVolume = monthlyData.fold<double>(
      0,
      (sum, month) => sum + month.dailyData
          .where((d) => d.isWorkoutDay)
          .fold<double>(0, (s, d) => s + d.volume),
    );

    // Calculate current streak (simplified - count consecutive workout days from today)
    final now = DateTime.now();
    int currentStreak = 0;
    final latestMonth = monthlyData.first;

    for (int day = now.day; day >= 1; day--) {
      final dayData = latestMonth.dailyData[day - 1];
      if (dayData.isWorkoutDay) {
        currentStreak++;
      } else {
        break;
      }
    }

    // Mock longest streak
    final longestStreak = currentStreak + 3;

    return AllTimeStats(
      totalWorkouts: totalWorkouts,
      totalKcal: totalKcal,
      totalVolume: totalVolume,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    );
  }
}
