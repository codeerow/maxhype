import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/workout.dart';
import '../../../models/workout_completion.dart';
import '../../../repositories/workout_completion_repository.dart';
import '../../../repositories/workout_repository.dart';
import 'workout_detail_event.dart';
import 'workout_detail_state.dart';

class WorkoutDetailBloc extends Bloc<WorkoutDetailEvent, WorkoutDetailState> {
  final WorkoutRepository workoutRepository;
  final WorkoutCompletionRepository? completionRepository;

  WorkoutDetailBloc({
    required this.workoutRepository,
    this.completionRepository,
  }) : super(WorkoutDetailLoading()) {
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
      final workouts = await workoutRepository.getWorkouts();
      final workout = workouts.firstWhere(
        (w) => w.id == event.workoutId,
        orElse: () => throw Exception('Workout not found'),
      );
      final completion = await _loadCompletionFor(event.workoutId);
      emit(WorkoutDetailSuccess(
        workout: workout,
        completionThisWeek: completion,
      ));
    } catch (e) {
      emit(WorkoutDetailError(message: e.toString()));
    }
  }

  /// Latest completion for [workoutId], scoped to the current ISO week.
  /// Returns null when no completion exists, the workout was finished
  /// in a previous week, or the repository isn't wired in.
  Future<WorkoutCompletion?> _loadCompletionFor(String workoutId) async {
    final repo = completionRepository;
    if (repo == null) return null;
    final all = await repo.loadAll();
    final record = all[workoutId];
    if (record == null) return null;
    if (!isInSameWeek(record.completedAt, DateTime.now())) return null;
    return record;
  }

  Future<void> _onReplaceExercise(
    ReplaceExercise event,
    Emitter<WorkoutDetailState> emit,
  ) async {
    if (state is! WorkoutDetailSuccess) return;
    final completion = (state as WorkoutDetailSuccess).completionThisWeek;

    try {
      if (event.persistToTemplate) {
        // Detail-screen three-dot menu: write through to the workout
        // repository so the next getWorkouts() call returns the
        // updated template.
        await workoutRepository.replaceExercise(
          workoutId: event.workoutId,
          oldExerciseId: event.oldExerciseId,
          newExercise: event.newExercise,
        );
        final workouts = await workoutRepository.getWorkouts();
        final updatedWorkout = workouts.firstWhere(
          (w) => w.id == event.workoutId,
          orElse: () => throw Exception('Workout not found'),
        );
        emit(WorkoutDetailSuccess(
          workout: updatedWorkout,
          completionThisWeek: completion,
        ));
      } else {
        // Preview-screen replace: keep the swap local to this bloc's
        // state. The change carries into the live session via
        // `Start Workout` (which reads `state.workout`) but never
        // touches the shared workout repository, so it can't leak
        // into future workout generations or other open detail
        // screens. Backing out of the detail route disposes this
        // bloc and the swap is gone.
        final current = (state as WorkoutDetailSuccess).workout;
        final updatedExercises = current.exercises
            .map((e) => e.id == event.oldExerciseId ? event.newExercise : e)
            .toList();
        final updatedWorkout = Workout(
          id: current.id,
          title: current.title,
          subtitle: current.subtitle,
          duration: current.duration,
          exerciseCount: current.exerciseCount,
          exercises: updatedExercises,
          targetMuscles: current.targetMuscles,
          recoveryInfo: current.recoveryInfo,
        );
        emit(WorkoutDetailSuccess(
          workout: updatedWorkout,
          completionThisWeek: completion,
        ));
      }
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

      emit(WorkoutDetailSuccess(
        workout: updatedWorkout,
        completionThisWeek: currentState.completionThisWeek,
      ));
    } catch (e) {
      emit(WorkoutDetailError(message: e.toString()));
    }
  }
}
