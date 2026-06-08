import '../models/exercise.dart';
import '../models/workout.dart';
import '../models/monthly_data.dart';
import '../models/all_time_stats.dart';
import '../data/mock_data.dart';
import 'workout_repository.dart';

/// Mock implementation of WorkoutRepository
/// In production, this would be replaced with API calls.
///
/// Holds workouts in memory so mutations (e.g., ReplaceExercise from
/// the preview screen, clarification 6.17) persist across subsequent
/// reads within the same app session.
class MockWorkoutRepository implements WorkoutRepository {
  List<Workout>? _workouts;

  List<Workout> _ensureSeeded() {
    return _workouts ??= MockData.getWorkouts();
  }

  @override
  Future<List<Workout>> getWorkouts() async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));
    // Return a defensive copy so callers can't mutate our state by
    // sorting / inserting into the list they received.
    return List<Workout>.unmodifiable(_ensureSeeded());
  }

  @override
  Future<List<MonthlyData>> getMonthlyData() async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 500));
    return MockData.getMonthlyData();
  }

  @override
  Future<AllTimeStats> getAllTimeStats() async {
    // Simulate network delay
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return MockData.getAllTimeStats();
  }

  @override
  Future<void> replaceExercise({
    required String workoutId,
    required String oldExerciseId,
    required Exercise newExercise,
  }) async {
    final workouts = _ensureSeeded();
    final idx = workouts.indexWhere((w) => w.id == workoutId);
    if (idx < 0) return;
    final w = workouts[idx];
    final exIdx = w.exercises.indexWhere((e) => e.id == oldExerciseId);
    if (exIdx < 0) return;

    final newExercises = List<Exercise>.of(w.exercises);
    newExercises[exIdx] = newExercise;
    workouts[idx] = Workout(
      id: w.id,
      title: w.title,
      subtitle: w.subtitle,
      duration: w.duration,
      exerciseCount: newExercises.length,
      exercises: newExercises,
      targetMuscles: w.targetMuscles,
      recoveryInfo: w.recoveryInfo,
    );
  }
}
