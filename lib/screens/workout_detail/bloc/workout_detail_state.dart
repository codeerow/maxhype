import '../../../models/workout.dart';
import '../../../models/workout_completion.dart';

sealed class WorkoutDetailState {}

class WorkoutDetailLoading extends WorkoutDetailState {}

class WorkoutDetailSuccess extends WorkoutDetailState {
  final Workout workout;

  /// Most recent completion record for this workout, if it lies within
  /// the current ISO week. null when the workout hasn't been finished
  /// this week — in that case the detail screen renders the normal
  /// Start Workout flow. When non-null, the screen locks the bottom
  /// button (read-only review state) so a user can't accidentally fire
  /// a duplicate session from an already-finished workout.
  final WorkoutCompletion? completionThisWeek;

  WorkoutDetailSuccess({
    required this.workout,
    this.completionThisWeek,
  });
}

class WorkoutDetailError extends WorkoutDetailState {
  final String message;

  WorkoutDetailError({required this.message});
}
