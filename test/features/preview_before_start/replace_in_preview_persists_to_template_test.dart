// Customer follow-up to clarification 6.17:
//   "When you say preview replace 'persists to the template,' please
//    confirm this only updates the current planned workout/draft for
//    that workout card, not the global exercise template or future
//    generated workouts."
//
// Behaviour:
//   - Preview replace (`persistToTemplate: false`) → swap lives only in
//     the WorkoutDetailBloc's state. The change carries into Start
//     Workout (because StartSession reads `state.workout`) but does
//     NOT touch the shared WorkoutRepository — a fresh load returns
//     the original exercise.
//   - Detail-screen three-dot replace (`persistToTemplate: true`,
//     default) → repository is mutated; subsequent opens see the new
//     exercise. This preserves the original 6.17 contract for the
//     explicit edit path.

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/muscle_group.dart';
import 'package:maxhype/repositories/mock_workout_repository.dart';
import 'package:maxhype/screens/workout_detail/bloc/workout_detail_bloc.dart';
import 'package:maxhype/screens/workout_detail/bloc/workout_detail_event.dart';
import 'package:maxhype/screens/workout_detail/bloc/workout_detail_state.dart';

void main() {
  Exercise _newExercise({String id = 'replacement_ex'}) => Exercise(
        id: id,
        name: 'Replacement Lift',
        sets: 3,
        reps: 5,
        weight: 0,
        muscleGroups: const [MuscleGroup.chest],
        equipmentType: EquipmentType.barbell,
        rating: 0,
      );

  test(
      'preview replace (persistToTemplate: false) updates the bloc state '
      'but does NOT mutate the shared workout repository', () async {
    final repo = MockWorkoutRepository();
    final workouts = await repo.getWorkouts();
    final workout = workouts.first;
    final originalExercise = workout.exercises.first;
    final newExercise = _newExercise();

    final bloc = WorkoutDetailBloc(workoutRepository: repo);
    bloc.add(LoadWorkoutDetail(workout.id));
    await bloc.stream.firstWhere((s) => s is WorkoutDetailSuccess);
    bloc.add(ReplaceExercise(
      workoutId: workout.id,
      oldExerciseId: originalExercise.id,
      newExercise: newExercise,
      persistToTemplate: false,
    ));
    final updated = await bloc.stream
        .firstWhere((s) => s is WorkoutDetailSuccess) as WorkoutDetailSuccess;

    // 1. The bloc's view of the workout reflects the swap — so Start
    //    Workout carries the replacement into the live session.
    expect(
      updated.workout.exercises.any((e) => e.id == newExercise.id),
      isTrue,
      reason: 'preview replace is visible in this detail bloc state',
    );
    expect(
      updated.workout.exercises.any((e) => e.id == originalExercise.id),
      isFalse,
    );

    // 2. The shared repository is untouched — a fresh load (next
    //    open, future week, other detail screen) returns the
    //    original.
    final reloaded = await repo.getWorkouts();
    final reloadedWorkout =
        reloaded.firstWhere((w) => w.id == workout.id);
    expect(
      reloadedWorkout.exercises.any((e) => e.id == originalExercise.id),
      isTrue,
      reason:
          'preview replace must not mutate the workout template / mock cache',
    );
    expect(
      reloadedWorkout.exercises.any((e) => e.id == newExercise.id),
      isFalse,
    );

    await bloc.close();
  });

  test(
      'detail-screen replace (persistToTemplate: true, default) writes '
      'through to the workout repository', () async {
    final repo = MockWorkoutRepository();
    final workouts = await repo.getWorkouts();
    final workout = workouts.first;
    final originalExercise = workout.exercises.first;
    final newExercise = _newExercise(id: 'persisted_replacement');

    final bloc = WorkoutDetailBloc(workoutRepository: repo);
    bloc.add(LoadWorkoutDetail(workout.id));
    await bloc.stream.firstWhere((s) => s is WorkoutDetailSuccess);
    bloc.add(ReplaceExercise(
      workoutId: workout.id,
      oldExerciseId: originalExercise.id,
      newExercise: newExercise,
      // persistToTemplate defaults to true
    ));
    await bloc.stream.firstWhere((s) => s is WorkoutDetailSuccess);

    final reloaded = await repo.getWorkouts();
    final reloadedWorkout =
        reloaded.firstWhere((w) => w.id == workout.id);
    expect(
      reloadedWorkout.exercises.any((e) => e.id == newExercise.id),
      isTrue,
      reason: 'detail-screen replace persists across reloads',
    );

    await bloc.close();
  });
}
