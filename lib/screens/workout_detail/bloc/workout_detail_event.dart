import '../../../models/exercise.dart';

sealed class WorkoutDetailEvent {}

class LoadWorkoutDetail extends WorkoutDetailEvent {
  final String workoutId;

  LoadWorkoutDetail(this.workoutId);
}

class ReplaceExercise extends WorkoutDetailEvent {
  final String workoutId;
  final String oldExerciseId;
  final Exercise newExercise;

  ReplaceExercise({
    required this.workoutId,
    required this.oldExerciseId,
    required this.newExercise,
  });
}

class AddExercise extends WorkoutDetailEvent {
  final String workoutId;
  final Exercise exercise;

  AddExercise({
    required this.workoutId,
    required this.exercise,
  });
}
