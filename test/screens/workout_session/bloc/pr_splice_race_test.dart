import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/screens/workout_session/bloc/pr_signal.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

/// Race covered:
///
///   1. `RestoreSession` kicks off `_loadPrsFor`, which awaits
///      `prRepo.bestFor(...)` per exercise (unawaited from the handler).
///   2. The user logs a set BEFORE that future resolves — the bloc
///      installs a session baseline as the head.
///   3. `prRepo.bestFor` finally returns a historical baseline.
///   4. Expected: instead of overwriting the session baseline as the head
///      (which would lose the user's logged set as the PR), the bloc
///      splices the historical baseline at the *tail* of the chain, so
///      `previousBestFor` keeps reporting what the user came in with.
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
    bloc = WorkoutSessionBloc(repository: repo, prRepository: prRepo);
  });

  tearDown(() async {
    await bloc.close();
  });

  test(
    'LogSet before history load installs session baseline; '
    'late history splices at chain tail and preserves previousBestFor',
    () async {
      // Gate the prRepo response so we can interleave LogSet with the
      // pending _loadPrsFor future.
      final gate = Completer<void>();
      when(() => prRepo.bestFor('ex1')).thenAnswer((_) async {
        await gate.future;
        return pr(weight: 80, reps: 5); // historical baseline
      });
      when(() => repo.loadActive()).thenAnswer((_) async => makeSession());

      // Start session — _loadPrsFor is now awaiting the gate.
      bloc.add(const RestoreSession());
      await bloc.stream.firstWhere((s) => s is SessionActive);

      // User logs a set while history is still loading — this seeds
      // the session baseline (setId != null) as the head.
      bloc.add(const LogSet(
        exerciseId: 'ex1',
        setId: 'set_a',
        weight: 100,
        reps: 5,
      ));
      await Future<void>.delayed(Duration.zero);

      // Sanity: head is the session-seeded entry (hasFreshPr true),
      // and previousBestFor walks to a baseline-with-setId==null — none
      // exists yet, so null.
      expect(bloc.hasFreshPr('ex1'), isTrue);
      expect(bloc.prFor('ex1')?.weight, 100);
      expect(bloc.previousBestFor('ex1'), isNull,
          reason: 'no historical baseline spliced yet');

      // Resolve the gate; _loadPrsFor finishes and splices the
      // historical baseline at the tail.
      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(
        bloc.prFor('ex1')?.weight,
        100,
        reason: 'head must remain the user-logged set, not be overwritten',
      );
      expect(
        bloc.previousBestFor('ex1')?.weight,
        80,
        reason: 'historical baseline must be reachable after splice',
      );
      expect(bloc.hasFreshPr('ex1'), isTrue);
    },
  );

  test(
    'history finishes before any LogSet — historical baseline is head, '
    'next set beating it fires PrAchievedSignal',
    () async {
      when(() => prRepo.bestFor('ex1'))
          .thenAnswer((_) async => pr(weight: 80, reps: 5));
      when(() => repo.loadActive()).thenAnswer((_) async => makeSession());

      bloc.add(const RestoreSession());
      await bloc.stream.firstWhere((s) => s is SessionActive);
      // Let _loadPrsFor settle.
      await Future<void>.delayed(Duration.zero);

      expect(bloc.prFor('ex1')?.weight, 80);
      expect(bloc.hasFreshPr('ex1'), isFalse,
          reason: 'baseline-from-history has setId == null');

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      bloc.add(const LogSet(
        exerciseId: 'ex1',
        setId: 'set_a',
        weight: 90,
        reps: 5,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(signals, hasLength(1));
      expect(signals.single, isA<PrAchievedSignal>());
      expect(bloc.previousBestFor('ex1')?.weight, 80);

      await sub.cancel();
    },
  );

  test(
    'second LogSet during the race chains correctly after late splice',
    () async {
      // Two LogSets land before history; the second beats the first.
      // After late splice, chain must be: historical(80) → set_a(100) → set_b(110).
      final gate = Completer<void>();
      when(() => prRepo.bestFor('ex1')).thenAnswer((_) async {
        await gate.future;
        return pr(weight: 80, reps: 5);
      });
      when(() => repo.loadActive()).thenAnswer(
        (_) async => makeSession(
          exercises: [makeExercise(exerciseId: 'ex1', setIds: ['set_a', 'set_b'])],
        ),
      );

      bloc.add(const RestoreSession());
      await bloc.stream.firstWhere((s) => s is SessionActive);

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

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

      // set_b beat set_a — one PR signal expected so far.
      expect(signals.whereType<PrAchievedSignal>(), hasLength(1));
      expect(bloc.prFor('ex1')?.weight, 110);

      gate.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.prFor('ex1')?.weight, 110);
      // Variant C: previousBest = runner-up among [historical(80),
      // set_a(100), set_b(110)] → set_a(100). The historical baseline
      // is in the ranking but is no longer the runner-up.
      expect(
        bloc.previousBestFor('ex1')?.weight,
        100,
        reason: 'runner-up is set_a; historical 80 sits below it',
      );

      await sub.cancel();
    },
  );
}
