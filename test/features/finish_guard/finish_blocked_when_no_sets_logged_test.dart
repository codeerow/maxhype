// Fixes the brief requirements for Item 9 — Finish workout zero-set guard:
//   - "If user taps Finish with zero logged sets: Do not save workout.
//      Do not mark workout completed. Do not return Home." (brief §9)
//   - "Once at least one set is logged: Finish works normally." (brief §9)
//   - "Deleted all logged sets → Finish should be blocked again if zero
//      logged sets remain" (brief §11)
//
// The existing finish_cancel_test.dart already covers the empty-finish
// guard at construction; this file pins the post-delete invariant so
// the user can't slip through by deleting their last set.

import 'package:flutter_test/flutter_test.dart';
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

  tearDown(() async {
    await Future<void>.delayed(Duration.zero);
    await bloc.close();
  });

  test('Finish on a zero-logged session is blocked and the session survives',
      () async {
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);

    final blockedFuture =
        bloc.stream.firstWhere((s) => s is SessionFinishBlockedEmpty);
    bloc.add(const FinishWorkout());
    await blockedFuture;

    // After the blocker fires, the session must be put back so the
    // user keeps editing the same workout — brief §9.
    expect(bloc.state, isA<SessionActive>());
    verifyNever(() => repo.archiveFinished(any()));
  });

  test('Finish succeeds once at least one set is logged', () async {
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);

    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'set_a',
      weight: 100,
      reps: 5,
    ));
    await Future<void>.delayed(Duration.zero);

    bloc.add(const FinishWorkout());
    await bloc.stream.firstWhere((s) => s is SessionFinished);
    verify(() => repo.archiveFinished(any())).called(1);
  });

  test('Finish becomes blocked again after the user deletes their last log',
      () async {
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);

    // Log one set, then delete it — the session has zero logged sets
    // again, so a Finish attempt must hit the same guard (brief §11).
    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'set_a',
      weight: 100,
      reps: 5,
    ));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_a'));
    await Future<void>.delayed(Duration.zero);

    final blockedFuture =
        bloc.stream.firstWhere((s) => s is SessionFinishBlockedEmpty);
    bloc.add(const FinishWorkout());
    await blockedFuture;

    expect(bloc.state, isA<SessionActive>());
    verifyNever(() => repo.archiveFinished(any()));
  });
}
