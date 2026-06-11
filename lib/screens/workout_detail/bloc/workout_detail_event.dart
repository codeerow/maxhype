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

  /// When true (default), the swap is persisted via the workout
  /// repository so the next `getWorkouts()` call returns the updated
  /// template — this is the right behaviour for the detail-screen
  /// three-dot menu, where the user is explicitly editing the plan.
  ///
  /// When false, the swap stays local to this `WorkoutDetailBloc`'s
  /// state — used by the preview screen so a pre-start replace
  /// doesn't mutate the shared template or leak into future workout
  /// generations. The change still carries into the live session
  /// because `Start Workout` reads `state.workout` to build it.
  final bool persistToTemplate;

  ReplaceExercise({
    required this.workoutId,
    required this.oldExerciseId,
    required this.newExercise,
    this.persistToTemplate = true,
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
