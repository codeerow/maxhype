import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../repositories/workout_repository.dart';
import 'workout_detail_event.dart';
import 'workout_detail_state.dart';

class WorkoutDetailBloc extends Bloc<WorkoutDetailEvent, WorkoutDetailState> {
  final WorkoutRepository workoutRepository;

  WorkoutDetailBloc({required this.workoutRepository})
      : super(WorkoutDetailLoading()) {
    on<LoadWorkoutDetail>(_onLoadWorkoutDetail);
    on<ReplaceExercise>(_onReplaceExercise);
    on<AddExercise>(_onAddExercise);
  }

  Future<void> _onLoadWorkoutDetail(
    LoadWorkoutDetail event,
    Emitter<WorkoutDetailState> emit,
  ) async {
    emit(WorkoutDetailLoading());
    try {
      final workouts = workoutRepository.getWorkouts();
      final workout = workouts.firstWhere(
        (w) => w.id == event.workoutId,
        orElse: () => throw Exception('Workout not found'),
      );
      emit(WorkoutDetailSuccess(workout: workout));
    } catch (e) {
      emit(WorkoutDetailError(message: e.toString()));
    }
  }

  Future<void> _onReplaceExercise(
    ReplaceExercise event,
    Emitter<WorkoutDetailState> emit,
  ) async {
    if (state is! WorkoutDetailSuccess) return;

    try {
      final currentState = state as WorkoutDetailSuccess;
      final workout = currentState.workout;

      // Find the index of the exercise to replace
      final exerciseIndex = workout.exercises.indexWhere(
        (ex) => ex.id == event.oldExerciseId,
      );

      if (exerciseIndex == -1) {
        throw Exception('Exercise not found');
      }

      // Create new exercises list with replacement
      final newExercises = List.of(workout.exercises);
      newExercises[exerciseIndex] = event.newExercise;

      // Create updated workout
      final updatedWorkout = Workout(
        id: workout.id,
        title: workout.title,
        subtitle: workout.subtitle,
        duration: workout.duration,
        exerciseCount: newExercises.length,
        exercises: newExercises,
        targetMuscles: workout.targetMuscles,
        recoveryInfo: workout.recoveryInfo,
      );

      emit(WorkoutDetailSuccess(workout: updatedWorkout));
    } catch (e) {
      emit(WorkoutDetailError(message: e.toString()));
    }
  }

  Future<void> _onAddExercise(
    AddExercise event,
    Emitter<WorkoutDetailState> emit,
  ) async {
    if (state is! WorkoutDetailSuccess) return;

    try {
      final currentState = state as WorkoutDetailSuccess;
      final workout = currentState.workout;

      // Add exercise to the end of the list
      final newExercises = List.of(workout.exercises)..add(event.exercise);

      // Create updated workout
      final updatedWorkout = Workout(
        id: workout.id,
        title: workout.title,
        subtitle: workout.subtitle,
        duration: workout.duration,
        exerciseCount: newExercises.length,
        exercises: newExercises,
        targetMuscles: workout.targetMuscles,
        recoveryInfo: workout.recoveryInfo,
      );

      emit(WorkoutDetailSuccess(workout: updatedWorkout));
    } catch (e) {
      emit(WorkoutDetailError(message: e.toString()));
    }
  }
}
