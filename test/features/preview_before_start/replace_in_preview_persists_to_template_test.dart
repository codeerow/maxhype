// Fixes clarification 6.17:
//   "Replace exercise from preview — that mutation should persist into
//    the workout template (so next time the workout is opened the
//    replacement sticks)"
//
// The preview screen's three-dot menu reuses the same options sheet
// the workout-detail screen uses; both flows dispatch
// WorkoutDetailBloc.ReplaceExercise, which mutates the workout
// template via the workout repository. This test pins that contract:
// after the event, the repository's getWorkouts() output reflects the
// replacement.

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/muscle_group.dart';
import 'package:maxhype/repositories/mock_workout_repository.dart';
import 'package:maxhype/screens/workout_detail/bloc/workout_detail_bloc.dart';
import 'package:maxhype/screens/workout_detail/bloc/workout_detail_event.dart';
import 'package:maxhype/screens/workout_detail/bloc/workout_detail_state.dart';

void main() {
  test(
      'replacing an exercise from the preview flow updates the workout '
      'template so subsequent opens show the new exercise', () async {
    final repo = MockWorkoutRepository();
    final workouts = await repo.getWorkouts();
    if (workouts.isEmpty) {
      fail('Mock repository must seed at least one workout');
    }
    final workout = workouts.first;
    final originalExercise = workout.exercises.first;

    final newExercise = Exercise(
      id: 'replacement_ex',
      name: 'Replacement Lift',
      sets: 3,
      reps: 5,
      weight: 0,
      muscleGroups: const [MuscleGroup.chest],
      equipmentType: EquipmentType.barbell,
      rating: 0,
    );

    final bloc = WorkoutDetailBloc(workoutRepository: repo);
    bloc.add(LoadWorkoutDetail(workout.id));
    await bloc.stream.firstWhere((s) => s is WorkoutDetailSuccess);
    bloc.add(ReplaceExercise(
      workoutId: workout.id,
      oldExerciseId: originalExercise.id,
      newExercise: newExercise,
    ));
    // Wait for the bloc to re-emit success with the updated workout.
    final updated = await bloc.stream
        .firstWhere((s) => s is WorkoutDetailSuccess) as WorkoutDetailSuccess;

    expect(
      updated.workout.exercises.any((e) => e.id == newExercise.id),
      isTrue,
      reason: 'replacement lands on the workout the detail screen renders',
    );
    expect(
      updated.workout.exercises.any((e) => e.id == originalExercise.id),
      isFalse,
      reason: 'old exercise no longer appears in the template',
    );

    // Re-fetch from the repository directly — the persistence
    // contract is "next time the workout is opened the replacement
    // sticks", so a fresh getWorkouts() must reflect the change.
    final reloaded = await repo.getWorkouts();
    final reloadedWorkout =
        reloaded.firstWhere((w) => w.id == workout.id);
    expect(
      reloadedWorkout.exercises.any((e) => e.id == newExercise.id),
      isTrue,
    );

    await bloc.close();
  });
}
