import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/screens/workout_session/bloc/pr_signal.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSessionFallback);

  late MockWorkoutSessionRepository repo;
  late MockPersonalRecordRepository prRepo;
  late WorkoutSessionBloc bloc;

  setUp(() {
    repo = MockWorkoutSessionRepository();
    prRepo = MockPersonalRecordRepository();
    when(() => repo.save(any())).thenAnswer((_) async {});
    when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);
    bloc = WorkoutSessionBloc(repository: repo, prRepository: prRepo);
  });

  tearDown(() async {
    await bloc.close();
  });

  /// Sessions used here have 3+ effective sets so deleting a single
  /// logged one never trips the auto-complete branch in `_onDeleteSet`
  /// (which requires every remaining set to be logged).
  Future<void> restoreThreeSetSession() async {
    when(() => repo.loadActive()).thenAnswer(
      (_) async => makeSession(
        exercises: [
          makeExercise(
            exerciseId: 'ex1',
            setIds: ['set_a', 'set_b', 'set_c'],
          ),
        ],
      ),
    );
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);
    await Future<void>.delayed(Duration.zero);
  }

  test('deleting the set that produced head PR rolls head back to previous',
      () async {
    await restoreThreeSetSession();

    // set_a establishes silent baseline. set_b beats it → fresh PR head.
    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'set_a',
      weight: 100,
      reps: 5,
    ));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'set_b',
      weight: 110,
      reps: 5,
    ));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.prFor('ex1')?.weight, 110);

    final signals = <PrSignal>[];
    final sub = bloc.prSignals.listen(signals.add);

    bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_b'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.prFor('ex1')?.weight, 100,
        reason: 'head rolls back to set_a baseline');
    expect(signals.whereType<PrRevokedSignal>(), hasLength(1));
    expect(
      (signals.single as PrRevokedSignal).setId,
      'set_b',
    );

    await sub.cancel();
  });

  test('deleting a non-PR set leaves head intact and emits no revoke',
      () async {
    await restoreThreeSetSession();

    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'set_a',
      weight: 100,
      reps: 5,
    ));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'set_b',
      weight: 110,
      reps: 5,
    ));
    await Future<void>.delayed(Duration.zero);
    // set_c is unlogged.

    final signals = <PrSignal>[];
    final sub = bloc.prSignals.listen(signals.add);

    bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_c'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.prFor('ex1')?.weight, 110, reason: 'head untouched');
    expect(signals.whereType<PrRevokedSignal>(), isEmpty);

    await sub.cancel();
  });

  test('deleting head with multiple predecessors falls back to next-best live',
      () async {
    await restoreThreeSetSession();

    // Sets: set_a(100), set_b(110), set_c(120). Head is set_c.
    bloc.add(const LogSet(
        exerciseId: 'ex1', setId: 'set_a', weight: 100, reps: 5));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const LogSet(
        exerciseId: 'ex1', setId: 'set_b', weight: 110, reps: 5));
    await Future<void>.delayed(Duration.zero);
    bloc.add(const LogSet(
        exerciseId: 'ex1', setId: 'set_c', weight: 120, reps: 5));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.prFor('ex1')?.weight, 120);

    final signals = <PrSignal>[];
    final sub = bloc.prSignals.listen(signals.add);

    // Delete set_b (NOT the head; head stays at set_c).
    bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_b'));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.prFor('ex1')?.weight, 120,
        reason: 'deleting non-head does not roll back head');
    expect(signals.whereType<PrRevokedSignal>(), isEmpty);

    // Now delete set_c (head). Ranking recomputes from live sets;
    // set_b is gone, so head falls to set_a(100).
    bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_c'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.prFor('ex1')?.weight, 100,
        reason: 'next-best live set takes over');
    // Each recompute emits at most one revoke (the old head's setId).
    // Variant B semantics: we don't "walk" a chain — we just diff old
    // head vs. new head per mutation.
    expect(signals.whereType<PrRevokedSignal>().length, 1);
    expect(signals.whereType<PrRevokedSignal>().single.setId, 'set_c');

    await sub.cancel();
  });

  test('historical baseline survives delete-all-session-sets', () async {
    when(() => prRepo.bestFor('ex1'))
        .thenAnswer((_) async => pr(weight: 80, reps: 5));
    when(() => repo.loadActive()).thenAnswer(
      (_) async => makeSession(
        exercises: [
          makeExercise(
            exerciseId: 'ex1',
            setIds: ['set_a', 'set_b', 'set_c'],
          ),
        ],
      ),
    );
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);
    await Future<void>.delayed(Duration.zero);

    bloc.add(const LogSet(
        exerciseId: 'ex1', setId: 'set_a', weight: 90, reps: 5));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.prFor('ex1')?.weight, 90);

    bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_a'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.prFor('ex1')?.weight, 80,
        reason: 'historical baseline (setId == null) always survives');
    expect(bloc.hasFreshPr('ex1'), isFalse);
  });

  test('warmup delete does not trigger PR rollback', () async {
    when(() => repo.loadActive()).thenAnswer(
      (_) async => makeSession(
        exercises: [
          makeExercise(
            exerciseId: 'ex1',
            setIds: ['set_a', 'set_b'],
            withWarmup: true,
          ),
        ],
      ),
    );
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);
    await Future<void>.delayed(Duration.zero);

    bloc.add(const LogSet(
        exerciseId: 'ex1', setId: 'set_a', weight: 100, reps: 5));
    await Future<void>.delayed(Duration.zero);

    final signals = <PrSignal>[];
    final sub = bloc.prSignals.listen(signals.add);

    bloc.add(const DeleteSet(
        exerciseId: 'ex1', setId: 'warmup_a', isWarmup: true));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.prFor('ex1')?.weight, 100, reason: 'PR head untouched');
    expect(signals, isEmpty);

    await sub.cancel();
  });

  test('DeleteExercise drops head pointer', () async {
    await restoreThreeSetSession();
    bloc.add(const LogSet(
        exerciseId: 'ex1', setId: 'set_a', weight: 100, reps: 5));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.prFor('ex1')?.weight, 100);

    bloc.add(const DeleteExercise('ex1'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.prFor('ex1'), isNull);
    expect(bloc.hasFreshPr('ex1'), isFalse);
  });
}
