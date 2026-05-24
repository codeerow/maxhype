import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/session/workout_session.dart';
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
    // Default: no PR history. Individual tests override per exercise.
    when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);
    bloc = WorkoutSessionBloc(repository: repo, prRepository: prRepo);
  });

  tearDown(() async {
    await bloc.close();
  });

  /// Enter SessionActive via RestoreSession so we never trigger the
  /// platform-touching code paths in StartSession (notification permission
  /// prompt). We wait for `_loadPrsFor` to settle by pumping the event
  /// queue — the bloc fires PrCacheLoaded back into itself on completion.
  Future<void> restoreWith(WorkoutSession session) async {
    when(() => repo.loadActive()).thenAnswer((_) async => session);
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);
    await Future<void>.delayed(Duration.zero);
  }

  group('PR baseline (no prior history)', () {
    test('first logged set becomes silent baseline, no PrAchievedSignal',
        () async {
      await restoreWith(makeSession());

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      bloc.add(const LogSet(
        exerciseId: 'ex1',
        setId: 'set_a',
        weight: 100,
        reps: 5,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(signals, isEmpty);
      expect(bloc.prFor('ex1')?.weight, 100);
      expect(bloc.prFor('ex1')?.reps, 5);
      // Baseline-from-first-set has setId set, so hasFreshPr is true —
      // that's how delete-of-this-set cleanly revokes the baseline.
      expect(bloc.hasFreshPr('ex1'), isTrue);
      // No previous best — chain has only the session baseline (setId != null).
      expect(bloc.previousBestFor('ex1'), isNull);

      await sub.cancel();
    });

    test(
      'silent baseline triggers a second SessionActive re-emit '
      '(so PrHeader rebuilds with the just-installed head)',
      () async {
        // Regression: without the re-emit, the very first LogSet of the
        // session leaves the UI rendered against state-before-baseline,
        // so PrHeader (gated on `currentPr != null`) stays hidden until
        // some unrelated event (e.g. cancelling the rest timer) triggers
        // another emit.
        await restoreWith(makeSession());

        final emits = <WorkoutSessionState>[];
        final sub = bloc.stream.listen(emits.add);

        bloc.add(const LogSet(
          exerciseId: 'ex1',
          setId: 'set_a',
          weight: 100,
          reps: 5,
        ));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final active = emits.whereType<SessionActive>().toList();
        expect(
          active.length,
          greaterThanOrEqualTo(2),
          reason:
              '_mutate emits once (head still null), then _maybeEmitPr '
              'must dispatch PrCacheLoaded so the builder reruns and '
              'PrHeader can finally render',
        );
        // And the head must be set by the time the last emit reaches
        // listeners — otherwise the rebuild would still see currentPr=null.
        expect(bloc.prFor('ex1')?.weight, 100);

        await sub.cancel();
      },
    );

    test('second set worse than baseline emits no signal and keeps head',
        () async {
      await restoreWith(makeSession());
      bloc.add(const LogSet(
        exerciseId: 'ex1',
        setId: 'set_a',
        weight: 100,
        reps: 5,
      ));
      await Future<void>.delayed(Duration.zero);

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      bloc.add(const LogSet(
        exerciseId: 'ex1',
        setId: 'set_b',
        weight: 90,
        reps: 5,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(signals, isEmpty);
      expect(bloc.prFor('ex1')?.weight, 100);
      await sub.cancel();
    });

    test('second set beating baseline emits PrAchievedSignal and updates head',
        () async {
      await restoreWith(makeSession());
      bloc.add(const LogSet(
        exerciseId: 'ex1',
        setId: 'set_a',
        weight: 100,
        reps: 5,
      ));
      await Future<void>.delayed(Duration.zero);

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      bloc.add(const LogSet(
        exerciseId: 'ex1',
        setId: 'set_b',
        weight: 105,
        reps: 5,
      ));
      await Future<void>.delayed(Duration.zero);

      // Head moved from set_a to set_b → UI needs both signals: drop the
      // PR pill from set_a, paint it on set_b.
      expect(signals, hasLength(2));
      final revoked =
          signals.whereType<PrRevokedSignal>().single;
      expect(revoked.exerciseId, 'ex1');
      expect(revoked.setId, 'set_a');
      final achieved =
          signals.whereType<PrAchievedSignal>().single;
      expect(achieved.exerciseId, 'ex1');
      expect(achieved.setId, 'set_b');
      expect(achieved.weight, 105);

      expect(bloc.prFor('ex1')?.weight, 105);
      // Previous best = runner-up of [set_a(100), set_b(105)] → set_a(100).
      // Variant C semantics: "what the new head just beat" instead of
      // "what we came in with from history".
      expect(bloc.previousBestFor('ex1')?.weight, 100);

      await sub.cancel();
    });
  });

  group('PR with historical baseline', () {
    test('first set beating historical baseline fires signal', () async {
      when(() => prRepo.bestFor('ex1'))
          .thenAnswer((_) async => pr(weight: 100, reps: 5));
      await restoreWith(makeSession());

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      bloc.add(const LogSet(
        exerciseId: 'ex1',
        setId: 'set_a',
        weight: 110,
        reps: 5,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(signals, hasLength(1));
      expect(signals.single, isA<PrAchievedSignal>());
      expect(bloc.prFor('ex1')?.weight, 110);
      // Historical baseline still reachable as "previous best".
      expect(bloc.previousBestFor('ex1')?.weight, 100);

      await sub.cancel();
    });

    test('first set worse than historical baseline fires no signal', () async {
      when(() => prRepo.bestFor('ex1'))
          .thenAnswer((_) async => pr(weight: 100, reps: 5));
      await restoreWith(makeSession());

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      bloc.add(const LogSet(
        exerciseId: 'ex1',
        setId: 'set_a',
        weight: 90,
        reps: 5,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(signals, isEmpty);
      // Head still pointing at historical baseline (setId == null →
      // hasFreshPr false).
      expect(bloc.prFor('ex1')?.weight, 100);
      expect(bloc.hasFreshPr('ex1'), isFalse);

      await sub.cancel();
    });
  });

  group('Warmup sets', () {
    test('warmup set never produces PR even if it beats the head', () async {
      await restoreWith(
        makeSession(
          exercises: [
            makeExercise(
              exerciseId: 'ex1',
              setIds: ['set_a'],
              withWarmup: true,
            ),
          ],
        ),
      );

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      bloc.add(const LogSet(
        exerciseId: 'ex1',
        setId: 'warmup_a',
        weight: 200,
        reps: 20,
        isWarmup: true,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(signals, isEmpty);
      expect(bloc.prFor('ex1'), isNull,
          reason: 'warmup must not seed a baseline either');

      await sub.cancel();
    });
  });
}
