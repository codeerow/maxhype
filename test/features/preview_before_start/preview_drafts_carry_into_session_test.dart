// Fixes the brief requirements for Item 6:
//   - "In preview mode, the user should be able to type weight/reps
//      as a draft (saved to be picked up after Start)" (clarification 6.15)
//   - "sets added in preview are present in the session when Start is
//      pressed" (clarification 6.18)
//   - "sets deleted in preview are absent in the session when Start is
//      pressed" (clarification 6.18)
//
// We exercise the StartSession event end-to-end: feed it the same
// previewDrafts payload the UI passes in production, then read back
// the resulting SessionActive to confirm the user's pre-typed values
// landed in the live session.

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/muscle_group.dart';
import 'package:maxhype/models/session/preview_draft.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/models/workout.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../screens/workout_session/bloc/helpers.dart';

Workout _workout({int targetSets = 3}) {
  return Workout(
    id: 'workout_1',
    title: 'Push Day',
    subtitle: '',
    duration: '30 min',
    exerciseCount: 1,
    recoveryInfo: RecoveryInfo(
      status: RecoveryStatus.ready,
      percentage: 100,
      description: '',
    ),
    exercises: [
      Exercise(
        id: 'ex1',
        name: 'Bench',
        sets: targetSets,
        reps: 5,
        weight: 100,
        muscleGroups: const [MuscleGroup.chest],
        equipmentType: EquipmentType.barbell,
        rating: 0,
      ),
    ],
    targetMuscles: const [MuscleGroup.chest],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerSessionFallback);

  late MockWorkoutSessionRepository repo;
  late MockPersonalRecordRepository prRepo;
  late WorkoutSessionBloc bloc;

  setUp(() {
    repo = MockWorkoutSessionRepository();
    prRepo = MockPersonalRecordRepository();
    when(() => repo.loadActive()).thenAnswer((_) async => null);
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
    // Let any pending _loadPrsFor follow-ups (PrCacheLoaded re-emit)
    // drain before closing — otherwise the bloc closes mid-handler.
    await Future<void>.delayed(Duration.zero);
    await bloc.close();
  });

  test(
      'weight and reps typed in preview appear on the matching set in the '
      'live session', () async {
    final drafts = {
      'ex1': PreviewExerciseDraft(
        exerciseId: 'ex1',
        sets: const [
          SessionSet(id: 'pset_1', weight: 110, reps: 6),
          SessionSet(id: 'pset_2', weight: 115, reps: 5),
          SessionSet(id: 'pset_3'),
        ],
      ),
    };
    bloc.add(StartSession(_workout(), previewDrafts: drafts));
    final s = await bloc.stream.firstWhere((s) => s is SessionActive)
        as SessionActive;

    final ex = s.session.exercises.single;
    expect(ex.sets[0].weight, 110);
    expect(ex.sets[0].reps, 6);
    expect(ex.sets[1].weight, 115);
    expect(ex.sets[1].reps, 5);
    expect(ex.sets[2].weight, isNull,
        reason: 'untouched preview row stays empty in the session');
  });

  test(
      'warmups and drop sets added in preview are present in the live '
      'session after Start (clarification 6.18)', () async {
    final drafts = {
      'ex1': PreviewExerciseDraft(
        exerciseId: 'ex1',
        sets: const [SessionSet(id: 'pset_1')],
        warmups: const [
          SessionSet(id: 'pwset_1', kind: SetKind.warmup),
          SessionSet(id: 'pwset_2', kind: SetKind.warmup),
        ],
        dropSets: const [
          SessionSet(id: 'pdset_1', kind: SetKind.dropSet),
        ],
      ),
    };
    bloc.add(StartSession(_workout(), previewDrafts: drafts));
    final s = await bloc.stream.firstWhere((s) => s is SessionActive)
        as SessionActive;
    final ex = s.session.exercises.single;

    expect(ex.warmups.length, 2);
    expect(ex.warmups.every((w) => w.kind == SetKind.warmup), isTrue);
    expect(ex.dropSets.length, 1);
    expect(ex.dropSets.single.kind, SetKind.dropSet);
  });

  test(
      'deleting rows in preview makes them absent in the live session '
      '(targetSets follows the preview row count)', () async {
    // Workout template asks for 3 sets — preview drops to 1.
    final drafts = {
      'ex1': PreviewExerciseDraft(
        exerciseId: 'ex1',
        sets: const [SessionSet(id: 'pset_1')],
      ),
    };
    bloc.add(StartSession(_workout(targetSets: 3), previewDrafts: drafts));
    final s = await bloc.stream.firstWhere((s) => s is SessionActive)
        as SessionActive;
    final ex = s.session.exercises.single;

    expect(ex.sets.length, 1,
        reason: 'preview row count overrides the template');
    expect(ex.targetSets, 1);
  });

  test(
      'an exercise the user never previewed falls back to the template '
      'set count', () async {
    bloc.add(StartSession(_workout(targetSets: 3)));
    final s = await bloc.stream.firstWhere((s) => s is SessionActive)
        as SessionActive;
    final ex = s.session.exercises.single;
    expect(ex.sets.length, 3);
    expect(ex.warmups, isEmpty);
    expect(ex.dropSets, isEmpty);
  });
}
