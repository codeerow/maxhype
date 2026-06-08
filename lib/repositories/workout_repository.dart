import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/monthly_data.dart';
import '../models/all_time_stats.dart';

/// Abstract interface for workout data operations
abstract class WorkoutRepository {
  /// Fetches the list of workouts
  Future<List<Workout>> getWorkouts();

  /// Fetches monthly workout data
  Future<List<MonthlyData>> getMonthlyData();

  /// Fetches all-time statistics
  Future<AllTimeStats> getAllTimeStats();

  /// Swap an exercise inside an existing workout template. Used by the
  /// workout-detail / preview screens so the replacement persists —
  /// subsequent calls to [getWorkouts] return the updated layout
  /// (brief Phase 3 Part 3 §6, clarification 6.17).
  Future<void> replaceExercise({
    required String workoutId,
    required String oldExerciseId,
    required Exercise newExercise,
  });
}
