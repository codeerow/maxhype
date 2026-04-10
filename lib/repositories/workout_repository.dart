import '../models/workout.dart';
import '../models/monthly_data.dart';

/// Abstract interface for workout data operations
abstract class WorkoutRepository {
  /// Fetches the list of workouts
  Future<List<Workout>> getWorkouts();

  /// Fetches monthly workout data
  Future<List<MonthlyData>> getMonthlyData();
}
