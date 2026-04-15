import '../models/workout.dart';
import '../models/monthly_data.dart';
import '../models/all_time_stats.dart';
import '../data/mock_data.dart';
import 'workout_repository.dart';

/// Mock implementation of WorkoutRepository
/// In production, this would be replaced with API calls
class MockWorkoutRepository implements WorkoutRepository {
  @override
  Future<List<Workout>> getWorkouts() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return MockData.getWorkouts();
  }

  @override
  Future<List<MonthlyData>> getMonthlyData() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));
    return MockData.getMonthlyData();
  }

  @override
  Future<AllTimeStats> getAllTimeStats() async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 300));
    return MockData.getAllTimeStats();
  }
}
