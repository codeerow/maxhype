import '../../../models/monthly_data.dart';
import '../../../models/workout.dart';

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

  const HomeSuccess({
    required this.workouts,
    required this.monthlyData,
  });
}

/// Error state
class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);
}
