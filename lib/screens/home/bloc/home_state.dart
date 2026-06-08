import '../../../models/monthly_data.dart';
import '../../../models/workout.dart';
import '../../../models/all_time_stats.dart';
import '../../../models/workout_completion.dart';

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

  /// Per-workout completion records loaded from
  /// `workout_completion.json`. Keyed by [Workout.id]. Used by
  /// [WorkoutCard] to render the "Completed · N mins" state on cards
  /// whose completion falls inside the current ISO week (brief §1,
  /// clarification 1.2).
  final Map<String, WorkoutCompletion> completions;

  const HomeSuccess({
    required this.workouts,
    required this.monthlyData,
    required this.allTimeStats,
    this.completions = const {},
  });
}

/// Error state
class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);
}
