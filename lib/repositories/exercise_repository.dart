import '../models/exercise.dart';
import '../models/muscle_group.dart';

abstract class ExerciseRepository {
  /// Get all exercises
  List<Exercise> getAllExercises();

  /// Get exercises filtered by muscle group
  List<Exercise> getExercisesByMuscleGroup(MuscleGroup muscleGroup);

  /// Get top N exercises by rating for a specific muscle group
  List<Exercise> getTopExercisesByMuscleGroup(
    MuscleGroup muscleGroup, {
    int limit = 8,
  });

  /// Get exercise by ID
  Exercise? getExerciseById(String id);
}
