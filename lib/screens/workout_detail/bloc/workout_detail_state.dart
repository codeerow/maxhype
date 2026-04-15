import '../../../models/workout.dart';

sealed class WorkoutDetailState {}

class WorkoutDetailLoading extends WorkoutDetailState {}

class WorkoutDetailSuccess extends WorkoutDetailState {
  final Workout workout;

  WorkoutDetailSuccess({required this.workout});
}

class WorkoutDetailError extends WorkoutDetailState {
  final String message;

  WorkoutDetailError({required this.message});
}
