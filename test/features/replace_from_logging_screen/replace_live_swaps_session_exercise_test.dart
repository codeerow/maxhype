// Pins the bug we just fixed: replacing an exercise from the
// three-dot menu on the live logging screen must update the active
// session model so the screen continues rendering against the new
// exercise. Before the fix the bloc was updated, but the screen still
// referenced the old exerciseId.
//
// Brief Phase 3 Part 3 §7 — "Replace exercise" on the logging screen.
// Clarification 7.20 — replacement must preserve logged sets / notes
// without resetting the rest timer.

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/muscle_group.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/models/session/workout_session.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../screens/workout_session/bloc/helpers.dart';

Exercise _replacement() => Exercise(
      id: 'ex_swap',
      name: 'Swap In',
      sets: 3,
      reps: 5,
      weight: 100,
      muscleGroups: const [MuscleGroup.chest],
      equipmentType: EquipmentType.barbell,
      rating: 0,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerSessionFallback);

  late MockWorkoutSessionRepository repo;
  late MockPersonalRecordRepository prRepo;
  late WorkoutSessionBloc bloc;

  setUp(() {
    repo = MockWorkoutSessionRepository();
    prRepo = MockPersonalRecordRepository();
    when(() => repo.loadActive()).thenAnswer((_) async => makeSession());
    when(() => repo.save(any())).thenAnswer((_) async {});
    when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);
    bloc = WorkoutSessionBloc(
      repository: repo,
      prRepository: prRepo,
      bell: FakeBell(),
      scheduler: FakeScheduler(),
    );
  });

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    await bloc.close();
  });

  Future<WorkoutSession> _restored() async {
    bloc.add(const RestoreSession());
    final state = await bloc.stream.firstWhere((s) => s is SessionActive)
        as SessionActive;
    return state.session;
  }

  test(
      'replace dispatched from the live logging screen swaps the exercise '
      'id in the active session', () async {
    await _restored();
    bloc.add(ReplaceExercise(
      oldExerciseId: 'ex1',
      newExercise: _replacement(),
    ));
    await Future<void>.delayed(Duration.zero);

    final s = bloc.state as SessionActive;
    expect(s.session.exercises.single.exerciseId, 'ex_swap',
        reason: 'old id replaced verbatim');
    expect(s.session.exercises.single.name, 'Swap In');
  });

  test(
      'replace preserves the carried sets so the user does not lose work '
      '(clarification 7.20)', () async {
    await _restored();
    // Log a working set on ex1 before the replace.
    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'set_a',
      weight: 120,
      reps: 5,
    ));
    await Future<void>.delayed(Duration.zero);

    bloc.add(ReplaceExercise(
      oldExerciseId: 'ex1',
      newExercise: _replacement(),
    ));
    await Future<void>.delayed(Duration.zero);

    final ex = (bloc.state as SessionActive).session.exercises.single;
    // The carried-over set retains its id and logged values.
    final carried =
        ex.sets.firstWhere((s) => s.id == 'set_a', orElse: () => throw 'gone');
    expect(carried.weight, 120);
    expect(carried.reps, 5);
    expect(carried.isLogged, isTrue);
  });

  test(
      'replace does not reset the rest timer (clarification 7.20 — timer '
      'state survives the swap)', () async {
    await _restored();
    bloc.add(const StartRestTimer(duration: Duration(seconds: 90)));
    await Future<void>.delayed(Duration.zero);
    final beforeEndsAt =
        (bloc.state as SessionActive).session.activeRestEndsAt;
    expect(beforeEndsAt, isNotNull);

    bloc.add(ReplaceExercise(
      oldExerciseId: 'ex1',
      newExercise: _replacement(),
    ));
    await Future<void>.delayed(Duration.zero);

    final afterEndsAt =
        (bloc.state as SessionActive).session.activeRestEndsAt;
    expect(afterEndsAt, beforeEndsAt,
        reason: 'rest timer must keep counting through the swap');
  });

  test(
      'replace does not create a duplicate exercise — the carried sets '
      'live on the new exerciseId, not both', () async {
    await _restored();
    bloc.add(ReplaceExercise(
      oldExerciseId: 'ex1',
      newExercise: _replacement(),
    ));
    await Future<void>.delayed(Duration.zero);

    final exercises = (bloc.state as SessionActive).session.exercises;
    expect(exercises.length, 1);
    expect(exercises.every((e) => e.exerciseId != 'ex1'), isTrue);
  });
}
