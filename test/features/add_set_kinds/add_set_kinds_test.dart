// Fixes the brief requirements for "Item 8 — Add Set menu (Set / Warm-Up /
// Drop Set)":
//   - "Add Set behavior to support the same set-type pattern... Set /
//      Warm-Up / Drop Set" (brief §8)
//   - "allow multiple warm-ups" (clarification 8.21)
//   - "Should be loggable/deletable" (brief §8)
//
// These tests pin behaviour, not implementation detail — they describe
// what the user sees / what state ends up in the session, not which
// methods got called.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/models/session/workout_session.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../screens/workout_session/bloc/helpers.dart';

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
    when(() => repo.archiveFinished(any())).thenAnswer((_) async {});
    when(() => repo.clearActive()).thenAnswer((_) async {});
    when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);
    bloc = WorkoutSessionBloc(
      repository: repo,
      prRepository: prRepo,
      bell: FakeBell(),
      scheduler: FakeScheduler(),
    );
  });

  tearDown(() => bloc.close());

  Future<WorkoutSession> _activeSession() async {
    bloc.add(const RestoreSession());
    final state = await bloc.stream.firstWhere((s) => s is SessionActive);
    return (state as SessionActive).session;
  }

  group('Add Set supports three set kinds', () {
    blocTest<WorkoutSessionBloc, WorkoutSessionState>(
      'Set adds a working set row to the effective list',
      build: () => bloc,
      act: (b) async {
        await _activeSession();
        b.add(const AddSet('ex1'));
      },
      verify: (b) {
        final ex = (b.state as SessionActive).session.exercises.single;
        // Started with 2 working sets — Add Set > Set bumps to 3.
        expect(ex.sets.length, 3);
        expect(ex.warmups, isEmpty);
        expect(ex.dropSets, isEmpty);
        expect(ex.targetSets, 3,
            reason: 'a new working set bumps targetSets');
      },
    );

    blocTest<WorkoutSessionBloc, WorkoutSessionState>(
      'Warm-Up adds a warmup row and multiple warm-ups can coexist',
      build: () => bloc,
      act: (b) async {
        await _activeSession();
        b.add(const AddSet('ex1', kind: SetKind.warmup));
        b.add(const AddSet('ex1', kind: SetKind.warmup));
      },
      verify: (b) {
        final ex = (b.state as SessionActive).session.exercises.single;
        expect(ex.warmups.length, 2,
            reason: 'brief §8.21 — multiple warm-ups must be allowed');
        expect(ex.warmups.every((w) => w.kind == SetKind.warmup), isTrue);
        expect(ex.sets.length, 2, reason: 'effective sets unaffected');
        expect(ex.targetSets, 2,
            reason: 'warmups do not contribute to working-set target');
      },
    );

    blocTest<WorkoutSessionBloc, WorkoutSessionState>(
      'Drop Set adds a drop-set row in a section separate from working sets',
      build: () => bloc,
      act: (b) async {
        await _activeSession();
        b.add(const AddSet('ex1', kind: SetKind.dropSet));
      },
      verify: (b) {
        final ex = (b.state as SessionActive).session.exercises.single;
        expect(ex.dropSets.length, 1);
        expect(ex.dropSets.single.kind, SetKind.dropSet);
        expect(ex.sets.length, 2,
            reason: 'drop sets must not be mixed into the working sets list');
        expect(ex.warmups, isEmpty);
      },
    );
  });

  group('Deleting one set kind does not touch the others', () {
    test('deleting a warmup leaves working sets and drop sets untouched',
        () async {
      await _activeSession();
      bloc.add(const AddSet('ex1', kind: SetKind.warmup));
      bloc.add(const AddSet('ex1', kind: SetKind.dropSet));
      await Future<void>.delayed(Duration.zero);

      final w =
          (bloc.state as SessionActive).session.exercises.single.warmups.single;
      bloc.add(DeleteSet(
        exerciseId: 'ex1',
        setId: w.id,
        kind: SetKind.warmup,
      ));
      await Future<void>.delayed(Duration.zero);

      final ex = (bloc.state as SessionActive).session.exercises.single;
      expect(ex.warmups, isEmpty);
      expect(ex.dropSets.length, 1);
      expect(ex.sets.length, 2);
    });

    test('deleting a drop set leaves working sets and warmups untouched',
        () async {
      await _activeSession();
      bloc.add(const AddSet('ex1', kind: SetKind.warmup));
      bloc.add(const AddSet('ex1', kind: SetKind.dropSet));
      await Future<void>.delayed(Duration.zero);

      final d = (bloc.state as SessionActive)
          .session
          .exercises
          .single
          .dropSets
          .single;
      bloc.add(DeleteSet(
        exerciseId: 'ex1',
        setId: d.id,
        kind: SetKind.dropSet,
      ));
      await Future<void>.delayed(Duration.zero);

      final ex = (bloc.state as SessionActive).session.exercises.single;
      expect(ex.dropSets, isEmpty);
      expect(ex.warmups.length, 1);
      expect(ex.sets.length, 2);
    });
  });
}
