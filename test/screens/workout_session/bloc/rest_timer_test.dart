import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

/// Rest-timer source switching is the most race-prone piece of the bloc:
/// exactly one bell must ring per deadline, owned by the Dart timer in
/// foreground or the OS notification in background, with the handoff
/// driven by `didChangeAppLifecycleState`.
///
/// The bloc depends on `RestBell` and `RestNotificationScheduler`
/// interfaces (injected via constructor), so these tests run with fakes
/// and never touch audioplayers / flutter_local_notifications.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSessionFallback);

  /// Bloc lives inside `fakeAsync` so the foreground bell `Timer` and
  /// persistence debounce are both driven by the fake clock.
  void runRestBlocTest(
    void Function(
      FakeAsync async,
      WorkoutSessionBloc bloc,
      FakeBell bell,
      FakeScheduler scheduler,
    ) body,
  ) {
    fakeAsync((async) {
      final repo = MockWorkoutSessionRepository();
      final prRepo = MockPersonalRecordRepository();
      final bell = FakeBell();
      final scheduler = FakeScheduler();
      when(() => repo.save(any())).thenAnswer((_) async {});
      when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);
      when(() => repo.loadActive()).thenAnswer((_) async => makeSession());

      final bloc = WorkoutSessionBloc(
        repository: repo,
        prRepository: prRepo,
        bell: bell,
        scheduler: scheduler,
      );
      bloc.add(const RestoreSession());
      async.flushMicrotasks();
      async.elapse(const Duration(milliseconds: 1));

      body(async, bloc, bell, scheduler);

      bloc.close();
      async.flushMicrotasks();
    });
  }

  group('StartRestTimer', () {
    test('in foreground arms Dart bell, does not schedule notification', () {
      runRestBlocTest((async, bloc, bell, scheduler) {
        bloc.add(const StartRestTimer(duration: Duration(seconds: 30)));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 1));

        expect(scheduler.scheduled, isEmpty,
            reason: 'foreground owns the bell — no OS notification');
        // Wait for the bell deadline.
        async.elapse(const Duration(seconds: 30));
        expect(bell.rings, 1);
      });
    });

    test('fires bell exactly once even if user lingers past the deadline', () {
      runRestBlocTest((async, bloc, bell, _) {
        bloc.add(const StartRestTimer(duration: Duration(seconds: 5)));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 60));
        expect(bell.rings, 1);
      });
    });

    test('uses session restDurationSeconds when event duration is null', () {
      runRestBlocTest((async, bloc, bell, _) {
        // Default restDurationSeconds on a fresh WorkoutSession is 120s.
        bloc.add(const StartRestTimer());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 119));
        expect(bell.rings, 0);
        async.elapse(const Duration(seconds: 1));
        expect(bell.rings, 1);
      });
    });
  });

  group('CancelRestTimer', () {
    test('cancels the foreground bell before it rings', () {
      runRestBlocTest((async, bloc, bell, scheduler) {
        bloc.add(const StartRestTimer(duration: Duration(seconds: 30)));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));

        bloc.add(const CancelRestTimer());
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 60));

        expect(bell.rings, 0, reason: 'cancel must silence the foreground bell');
        // _syncRestNotification's `ends == null` branch always cancels
        // the scheduler too — that's two cancels: one on Start (no prior
        // schedule, harmless) and one on Cancel.
        expect(scheduler.cancels, greaterThanOrEqualTo(1));
      });
    });
  });

  group('AdjustRestTimer', () {
    test('positive delta re-arms the Dart bell to the later deadline', () {
      runRestBlocTest((async, bloc, bell, _) {
        bloc.add(const StartRestTimer(duration: Duration(seconds: 30)));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 10));

        bloc.add(const AdjustRestTimer(Duration(seconds: 30)));
        async.flushMicrotasks();

        // Original deadline (20s remaining) — bell must not have fired.
        async.elapse(const Duration(seconds: 25));
        expect(bell.rings, 0, reason: 'adjust pushed deadline past original');

        // Final 25s to reach the new deadline (30s remaining after adjust).
        async.elapse(const Duration(seconds: 25));
        expect(bell.rings, 1);
      });
    });

    test('trimming past zero cancels the timer cleanly', () {
      runRestBlocTest((async, bloc, bell, _) {
        bloc.add(const StartRestTimer(duration: Duration(seconds: 30)));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        bloc.add(const AdjustRestTimer(Duration(seconds: -60)));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 60));
        expect(bell.rings, 0);
      });
    });
  });

  group('Lifecycle source swap', () {
    test('leaving foreground cancels Dart bell, schedules OS notification', () {
      runRestBlocTest((async, bloc, bell, scheduler) {
        bloc.add(const StartRestTimer(duration: Duration(seconds: 30)));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        bloc.didChangeAppLifecycleState(AppLifecycleState.paused);
        async.flushMicrotasks();
        async.elapse(Duration.zero);

        expect(scheduler.scheduled, hasLength(1),
            reason: 'background owns the bell');

        // Advance past the original deadline — Dart bell must NOT fire.
        async.elapse(const Duration(seconds: 60));
        expect(bell.rings, 0,
            reason: 'foreground bell must be cancelled on background switch');
      });
    });

    test('returning to foreground cancels notification, re-arms Dart bell',
        () {
      runRestBlocTest((async, bloc, bell, scheduler) {
        bloc.add(const StartRestTimer(duration: Duration(seconds: 60)));
        async.flushMicrotasks();
        async.elapse(const Duration(seconds: 5));

        bloc.didChangeAppLifecycleState(AppLifecycleState.paused);
        async.flushMicrotasks();
        expect(scheduler.scheduled, hasLength(1));

        // Spend 30s in background, then return.
        async.elapse(const Duration(seconds: 30));
        bloc.didChangeAppLifecycleState(AppLifecycleState.resumed);
        async.flushMicrotasks();

        // ~25s remain on the deadline; bell should ring at ~55s from Start.
        async.elapse(const Duration(seconds: 24));
        expect(bell.rings, 0);
        async.elapse(const Duration(seconds: 1));
        expect(bell.rings, 1);
      });
    });

    test(
      'returning to foreground after deadline elapsed does NOT ring a '
      'second bell (OS notification already played in background)',
      () {
        runRestBlocTest((async, bloc, bell, scheduler) {
          bloc.add(const StartRestTimer(duration: Duration(seconds: 10)));
          async.flushMicrotasks();

          bloc.didChangeAppLifecycleState(AppLifecycleState.paused);
          async.flushMicrotasks();
          expect(scheduler.scheduled, hasLength(1));

          // Stay backgrounded past the deadline.
          async.elapse(const Duration(seconds: 60));

          // Returning to foreground — _armForegroundBell sees negative
          // remaining and refuses to fire a second bell.
          bloc.didChangeAppLifecycleState(AppLifecycleState.resumed);
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 60));

          expect(bell.rings, 0,
              reason: 'OS notification already covered this deadline');
        });
      },
    );

    test('repeated lifecycle events with no active rest timer are no-ops', () {
      runRestBlocTest((async, bloc, bell, scheduler) {
        bloc.didChangeAppLifecycleState(AppLifecycleState.paused);
        bloc.didChangeAppLifecycleState(AppLifecycleState.resumed);
        bloc.didChangeAppLifecycleState(AppLifecycleState.paused);
        async.flushMicrotasks();

        expect(scheduler.scheduled, isEmpty);
        expect(scheduler.cancels, 0);
        expect(bell.rings, 0);
      });
    });
  });

  group('Bell-vs-CancelRestTimer race (regression)', () {
    test(
      'Dart timer firing self-emits CancelRestTimer and rings exactly once',
      () {
        runRestBlocTest((async, bloc, bell, scheduler) {
          bloc.add(const StartRestTimer(duration: Duration(seconds: 5)));
          async.flushMicrotasks();
          async.elapse(const Duration(seconds: 5));
          async.flushMicrotasks();
          async.elapse(Duration.zero);

          expect(bell.rings, 1);
          // After the self-dispatched CancelRestTimer is processed,
          // activeRestEndsAt should be null on the active session.
          final state = bloc.state;
          expect(state, isA<SessionActive>());
          expect(
            (state as SessionActive).session.activeRestEndsAt,
            isNull,
            reason:
                'bell handler self-dispatches CancelRestTimer to clear deadline',
          );
        });
      },
    );
  });
}
