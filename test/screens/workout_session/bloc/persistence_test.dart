import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/session/workout_session.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSessionFallback);

  /// Each test builds its own bloc inside `fakeAsync` so the debounce
  /// Timer is owned by the fake clock. We can't share a `setUp`-built
  /// bloc with `fakeAsync` because the bloc would be created on the
  /// real zone.
  void runWithBloc(
    void Function(
      FakeAsync async,
      WorkoutSessionBloc bloc,
      MockWorkoutSessionRepository repo,
      MockPersonalRecordRepository prRepo,
    ) body,
  ) {
    fakeAsync((async) {
      final repo = MockWorkoutSessionRepository();
      final prRepo = MockPersonalRecordRepository();
      when(() => repo.save(any())).thenAnswer((_) async {});
      when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);
      when(() => repo.loadActive()).thenAnswer((_) async => makeSession());

      final bloc = WorkoutSessionBloc(repository: repo, prRepository: prRepo);
      bloc.add(const RestoreSession());
      async.flushMicrotasks();
      // Drain any pending RestoreSession-related async work.
      async.elapse(const Duration(milliseconds: 1));

      body(async, bloc, repo, prRepo);

      bloc.close();
      async.flushMicrotasks();
    });
  }

  group('Persistence debounce vs flush', () {
    test('UpdateSetDraft does not save before 1500ms', () {
      runWithBloc((async, bloc, repo, _) {
        clearInteractions(repo);

        bloc.add(const UpdateSetDraft(
          exerciseId: 'ex1',
          setId: 'set_a',
          weight: 50,
        ));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1499));

        verifyNever(() => repo.save(any()));

        async.elapse(const Duration(milliseconds: 1));
        verify(() => repo.save(any())).called(1);
      });
    });

    test('multiple drafts within 1500ms collapse into a single save', () {
      runWithBloc((async, bloc, repo, _) {
        clearInteractions(repo);

        bloc.add(const UpdateSetDraft(
            exerciseId: 'ex1', setId: 'set_a', weight: 50));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));
        bloc.add(const UpdateSetDraft(
            exerciseId: 'ex1', setId: 'set_a', weight: 60));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 500));
        bloc.add(const UpdateSetDraft(
            exerciseId: 'ex1', setId: 'set_a', weight: 70));
        async.flushMicrotasks();
        // 500+500=1000ms since first, 0ms since last — debounce armed
        // for the latest draft.
        async.elapse(const Duration(milliseconds: 1499));
        verifyNever(() => repo.save(any()));

        async.elapse(const Duration(milliseconds: 1));
        verify(() => repo.save(any())).called(1);
      });
    });

    test('LogSet flushes immediately and cancels a pending debounce', () {
      runWithBloc((async, bloc, repo, _) {
        clearInteractions(repo);

        // Arm debounce.
        bloc.add(const UpdateSetDraft(
            exerciseId: 'ex1', setId: 'set_a', weight: 50));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 100));

        // LogSet flushes.
        bloc.add(const LogSet(
          exerciseId: 'ex1',
          setId: 'set_a',
          weight: 100,
          reps: 5,
        ));
        async.flushMicrotasks();
        // The flush itself is awaited inside the handler — give it a microtask.
        async.elapse(Duration.zero);

        verify(() => repo.save(any())).called(1);

        // Advance past the original debounce deadline — no second save
        // should occur (debounce timer was cancelled).
        async.elapse(const Duration(milliseconds: 1500));
        verifyNoMoreInteractions(repo);
      });
    });

    test('close() cancels pending debounce without writing', () {
      fakeAsync((async) {
        final repo = MockWorkoutSessionRepository();
        final prRepo = MockPersonalRecordRepository();
        when(() => repo.save(any())).thenAnswer((_) async {});
        when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);
        when(() => repo.loadActive()).thenAnswer((_) async => makeSession());

        final bloc = WorkoutSessionBloc(repository: repo, prRepository: prRepo);
        bloc.add(const RestoreSession());
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1));

        clearInteractions(repo);

        bloc.add(const UpdateSetDraft(
            exerciseId: 'ex1', setId: 'set_a', weight: 50));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 100));

        bloc.close();
        async.flushMicrotasks();

        // Past the original debounce — but the timer was cancelled.
        async.elapse(const Duration(milliseconds: 1500));
        verifyNever(() => repo.save(any()));
      });
    });
  });

  group('RestoreSession', () {
    test('returns SessionIdle when repository.loadActive() is null', () async {
      final repo = MockWorkoutSessionRepository();
      final prRepo = MockPersonalRecordRepository();
      when(() => repo.loadActive()).thenAnswer((_) async => null);
      final bloc = WorkoutSessionBloc(repository: repo, prRepository: prRepo);

      bloc.add(const RestoreSession());
      final states = <WorkoutSessionState>[];
      final sub = bloc.stream.listen(states.add);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(states.first, isA<SessionLoading>());
      expect(states.last, isA<SessionIdle>());

      await bloc.close();
    });

    test('drops expired activeRestEndsAt on restore', () async {
      final repo = MockWorkoutSessionRepository();
      final prRepo = MockPersonalRecordRepository();
      when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);
      when(() => repo.loadActive()).thenAnswer((_) async {
        final base = makeSession();
        return base.copyWith(
          activeRestEndsAt: DateTime.now().subtract(const Duration(minutes: 1)),
        );
      });

      final bloc = WorkoutSessionBloc(repository: repo, prRepository: prRepo);
      bloc.add(const RestoreSession());
      final state = await bloc.stream.firstWhere((s) => s is SessionActive);
      await Future<void>.delayed(Duration.zero);

      final session = (state as SessionActive).session;
      expect(session.activeRestEndsAt, isNull);

      await bloc.close();
    });

    test('keeps future activeRestEndsAt on restore', () async {
      final repo = MockWorkoutSessionRepository();
      final prRepo = MockPersonalRecordRepository();
      when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);
      final future = DateTime.now().add(const Duration(minutes: 5));
      when(() => repo.loadActive()).thenAnswer((_) async {
        return makeSession().copyWith(activeRestEndsAt: future);
      });

      final bloc = WorkoutSessionBloc(repository: repo, prRepository: prRepo);
      bloc.add(const RestoreSession());
      final state = await bloc.stream.firstWhere((s) => s is SessionActive);
      await Future<void>.delayed(Duration.zero);

      // NOTE: this test only checks state — the bloc DOES call
      // RestTimerNotifications.instance.schedule() / SessionAudio
      // via _syncRestNotification when the rest-end value changes from
      // null (initial state) to a future time. With a future deadline,
      // _armForegroundBell schedules a real Timer. We immediately close
      // the bloc to cancel it.
      final session = (state as SessionActive).session;
      expect(session.activeRestEndsAt, future);

      await bloc.close();
    });
  });
}
