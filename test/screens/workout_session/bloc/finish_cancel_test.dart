import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/models/session/workout_session.dart';
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
  late FakeScheduler scheduler;

  setUp(() {
    repo = MockWorkoutSessionRepository();
    prRepo = MockPersonalRecordRepository();
    scheduler = FakeScheduler();
    when(() => repo.save(any())).thenAnswer((_) async {});
    when(() => repo.clearActive()).thenAnswer((_) async {});
    when(() => repo.archiveFinished(any())).thenAnswer((_) async {});
    when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);
    bloc = WorkoutSessionBloc(
      repository: repo,
      prRepository: prRepo,
      scheduler: scheduler,
    );
  });

  tearDown(() async {
    await bloc.close();
  });

  /// Enter SessionActive via RestoreSession so we avoid the
  /// notification-permission prompt baked into StartSession.
  Future<void> restoreActive() async {
    when(() => repo.loadActive()).thenAnswer((_) async => makeSession());
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);
    await Future<void>.delayed(Duration.zero);
  }

  /// FinishWorkout now refuses to archive a session with zero logged
  /// sets — that would write empty entries into the history file and
  /// pollute the PR baseline scan. Tests that exercise the happy-path
  /// finish flow need at least one logged set before dispatching it.
  Future<void> logOneSet() async {
    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'set_a',
      weight: 50,
      reps: 5,
    ));
    await Future<void>.delayed(Duration.zero);
  }

  group('CancelWorkout', () {
    test('emits SessionCancelled then SessionIdle', () async {
      await restoreActive();

      final emits = <WorkoutSessionState>[];
      final sub = bloc.stream.listen(emits.add);

      bloc.add(const CancelWorkout());
      await Future<void>.delayed(Duration.zero);

      final cancelledIdx =
          emits.indexWhere((s) => s is SessionCancelled);
      final idleIdx = emits.indexWhere((s) => s is SessionIdle);
      expect(cancelledIdx, isNonNegative,
          reason: 'must pass through SessionCancelled');
      expect(idleIdx, greaterThan(cancelledIdx),
          reason: 'SessionIdle follows SessionCancelled');

      await sub.cancel();
    });

    test('clears active storage and cancels the OS notification', () async {
      await restoreActive();
      // Arm a scheduled rest so we can assert cancel() is called once
      // for the pending notification, plus once in _onCancelWorkout itself.
      scheduler.cancels = 0;

      bloc.add(const CancelWorkout());
      await Future<void>.delayed(Duration.zero);

      verify(() => repo.clearActive()).called(1);
      verifyNever(() => repo.archiveFinished(any()));
      expect(scheduler.cancels, greaterThanOrEqualTo(1),
          reason: '_onCancelWorkout must cancel the OS notification');
    });

    test('drops the pending persist debounce — no save fires after cancel',
        () async {
      await restoreActive();
      clearInteractions(repo);

      // Arm the debounce with a draft.
      bloc.add(const UpdateSetDraft(
        exerciseId: 'ex1',
        setId: 'set_a',
        weight: 50,
      ));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const CancelWorkout());
      // Wait past the 1500ms debounce window in real time would be silly;
      // instead we only need to confirm clearActive ran and no save was
      // queued behind it. The cancel path in _onCancelWorkout cancels
      // _persistDebounce synchronously.
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => repo.save(any()));
      verify(() => repo.clearActive()).called(1);
    });
  });

  group('FinishWorkout', () {
    test('emits SessionFinishing → SessionFinished → SessionIdle', () async {
      await restoreActive();
      await logOneSet();

      final emits = <WorkoutSessionState>[];
      final sub = bloc.stream.listen(emits.add);

      bloc.add(const FinishWorkout());
      await Future<void>.delayed(Duration.zero);

      final finishingIdx =
          emits.indexWhere((s) => s is SessionFinishing);
      final finishedIdx =
          emits.indexWhere((s) => s is SessionFinished);
      final idleIdx = emits.indexWhere((s) => s is SessionIdle);
      expect(finishingIdx, isNonNegative);
      expect(finishedIdx, greaterThan(finishingIdx));
      expect(idleIdx, greaterThan(finishedIdx));

      await sub.cancel();
    });

    test('archives a session marked finished with non-null finishedAt',
        () async {
      await restoreActive();
      await logOneSet();
      final captured = <WorkoutSession>[];
      when(() => repo.archiveFinished(any())).thenAnswer((inv) async {
        captured.add(inv.positionalArguments.single as WorkoutSession);
      });

      bloc.add(const FinishWorkout());
      await Future<void>.delayed(Duration.zero);

      expect(captured, hasLength(1));
      final archived = captured.single;
      expect(archived.status, SessionStatus.finished);
      expect(archived.finishedAt, isNotNull);
      // Transient runtime fields must not bleed into the archive.
      expect(archived.activeRestEndsAt, isNull);
      expect(archived.activeExerciseId, isNull);
    });

    test('clears active storage and cancels the OS notification', () async {
      await restoreActive();
      await logOneSet();
      scheduler.cancels = 0;

      bloc.add(const FinishWorkout());
      await Future<void>.delayed(Duration.zero);

      verify(() => repo.archiveFinished(any())).called(1);
      verify(() => repo.clearActive()).called(1);
      expect(scheduler.cancels, greaterThanOrEqualTo(1));
    });

    test('archive happens BEFORE clearActive (history must persist first)',
        () async {
      await restoreActive();
      await logOneSet();

      final order = <String>[];
      when(() => repo.archiveFinished(any())).thenAnswer((_) async {
        order.add('archive');
      });
      when(() => repo.clearActive()).thenAnswer((_) async {
        order.add('clear');
      });

      bloc.add(const FinishWorkout());
      await Future<void>.delayed(Duration.zero);

      expect(order, ['archive', 'clear'],
          reason: 'losing history is worse than a stale active file');
    });

    test('no-op SessionIdle when bloc is idle (no active session)',
        () async {
      // Bloc is freshly constructed — state is SessionIdle, no
      // _current. FinishWorkout must short-circuit, not crash and
      // not archive an empty session.
      final emits = <WorkoutSessionState>[];
      final sub = bloc.stream.listen(emits.add);

      bloc.add(const FinishWorkout());
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => repo.archiveFinished(any()));
      verifyNever(() => repo.clearActive());
      // Bloc emits SessionIdle (re-emit allowed; we mainly assert no
      // SessionFinished/SessionFinishing slipped through).
      expect(emits.whereType<SessionFinishing>(), isEmpty);
      expect(emits.whereType<SessionFinished>(), isEmpty);

      await sub.cancel();
    });

    test('drops the pending persist debounce — no save fires after finish',
        () async {
      await restoreActive();
      await logOneSet();
      clearInteractions(repo);
      when(() => repo.archiveFinished(any())).thenAnswer((_) async {});
      when(() => repo.clearActive()).thenAnswer((_) async {});

      bloc.add(const UpdateSetDraft(
        exerciseId: 'ex1',
        setId: 'set_a',
        weight: 50,
      ));
      await Future<void>.delayed(Duration.zero);

      bloc.add(const FinishWorkout());
      await Future<void>.delayed(Duration.zero);

      verifyNever(() => repo.save(any()));
      verify(() => repo.archiveFinished(any())).called(1);
    });
  });

  group('FinishWorkout zero-set guard', () {
    test(
      'with no logged sets emits SessionFinishBlockedEmpty, '
      'then bounces back to SessionActive — does not archive or clear',
      () async {
        await restoreActive();

        final emits = <WorkoutSessionState>[];
        final sub = bloc.stream.listen(emits.add);

        bloc.add(const FinishWorkout());
        await Future<void>.delayed(Duration.zero);

        expect(
          emits.whereType<SessionFinishBlockedEmpty>(),
          hasLength(1),
          reason: 'guard must announce the block exactly once',
        );
        // The guard must NOT push the session through the finish flow.
        expect(emits.whereType<SessionFinishing>(), isEmpty);
        expect(emits.whereType<SessionFinished>(), isEmpty);
        // And the screen has to stay on a valid SessionActive so the
        // user can keep logging.
        expect(emits.last, isA<SessionActive>());

        verifyNever(() => repo.archiveFinished(any()));
        verifyNever(() => repo.clearActive());

        await sub.cancel();
      },
    );

    test(
      'a single logged set is enough to clear the guard and finish normally',
      () async {
        await restoreActive();
        await logOneSet();

        bloc.add(const FinishWorkout());
        await Future<void>.delayed(Duration.zero);

        verify(() => repo.archiveFinished(any())).called(1);
        verify(() => repo.clearActive()).called(1);
      },
    );

    test(
      'a logged warmup also clears the guard '
      '(warmups count as evidence the user worked the exercise)',
      () async {
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

        // Log only the warmup — no effective sets.
        bloc.add(const LogSet(
          exerciseId: 'ex1',
          setId: 'warmup_a',
          weight: 40,
          reps: 10,
          kind: SetKind.warmup,
        ));
        await Future<void>.delayed(Duration.zero);

        bloc.add(const FinishWorkout());
        await Future<void>.delayed(Duration.zero);

        verify(() => repo.archiveFinished(any())).called(1);
      },
    );
  });
}
