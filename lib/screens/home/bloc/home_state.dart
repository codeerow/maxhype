import '../../../models/monthly_data.dart';
import '../../../models/workout.dart';
import '../../../models/all_time_stats.dart';

sealed class HomeState {
  const HomeState();
}

/// Loading state
class HomeLoading extends HomeState {
  const HomeLoading();
}

/// Success state with data
class HomeSuccess extends HomeState {
  final List<Workout> workouts;
  final List<MonthlyData> monthlyData;
  final AllTimeStats allTimeStats;

  const HomeSuccess({
    required this.workouts,
    required this.monthlyData,
    required this.allTimeStats,
  });
}

/// Error state
class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);
}
