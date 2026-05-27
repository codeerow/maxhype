import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/session/workout_session.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

/// DeleteSet never marks the exercise complete on its own. When the
/// user trims off the last unlogged effective set, the surviving sets
/// are all logged → `isAwaitingDoneConfirmation` flips true and the
/// bottom button shows "Done". The user finishes by tapping Done,
/// not by deleting their way to completion. Auto-completing here
/// would also pop the logging screen out from under them via the
/// completed-flag listener.
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

  Future<void> restoreWith(WorkoutSession session) async {
    when(() => repo.loadActive()).thenAnswer((_) async => session);
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);
    await Future<void>.delayed(Duration.zero);
  }

  /// Fetch the (possibly updated) exercise snapshot from the bloc's
  /// current state.
  dynamic currentExercise(String exerciseId) {
    final s = bloc.state;
    if (s is! SessionActive) return null;
    return s.session.exercises.firstWhere((e) => e.exerciseId == exerciseId);
  }

  Future<void> logSet(String exerciseId, String setId,
      {double weight = 100, int reps = 5}) async {
    bloc.add(LogSet(
      exerciseId: exerciseId,
      setId: setId,
      weight: weight,
      reps: reps,
    ));
    // Two microtask drains: _onLogSet handler + the follow-up
    // PrCacheLoaded dispatched by _maybeEmitPr.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
  }

  test(
    'deleting the last unlogged set leaves the exercise active in the '
    'awaiting-Done state — no auto-complete, screen stays open',
    () async {
      await restoreWith(
        makeSession(
          exercises: [
            makeExercise(
              exerciseId: 'ex1',
              setIds: ['set_a', 'set_b', 'set_c'],
            ),
          ],
        ),
      );

      await logSet('ex1', 'set_a');
      await logSet('ex1', 'set_b');

      expect(currentExercise('ex1').completed, isFalse);

      // Delete the only remaining unlogged set.
      bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_c'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final ex = currentExercise('ex1');
      expect(ex.completed, isFalse,
          reason: 'DeleteSet no longer auto-completes the exercise');
      expect(ex.isAwaitingDoneConfirmation, isTrue,
          reason:
              'all surviving sets are logged and warmup is satisfied — '
              'the bottom button should switch to "Done" so the user can '
              'finish manually');
      expect(ex.sets.length, 2);
      expect(ex.targetSets, 2,
          reason: 'targetSets decrements alongside the removed set');
    },
  );

  test(
    'a running rest timer survives DeleteSet — only Done/Cancel clear it',
    () async {
      await restoreWith(
        makeSession(
          exercises: [
            makeExercise(
              exerciseId: 'ex1',
              setIds: ['set_a', 'set_b'],
            ),
          ],
        ),
      );

      await logSet('ex1', 'set_a');
      bloc.add(const StartRestTimer(duration: Duration(seconds: 60)));
      await Future<void>.delayed(Duration.zero);
      final sActive = bloc.state as SessionActive;
      expect(sActive.session.activeRestEndsAt, isNotNull);
      expect(sActive.session.activeExerciseId, 'ex1');

      bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_b'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final s = bloc.state as SessionActive;
      expect(currentExercise('ex1').completed, isFalse);
      expect(s.session.activeRestEndsAt, isNotNull,
          reason:
              'rest timer keeps ticking — the user might still want to log '
              'another set before tapping Done');
      expect(s.session.activeExerciseId, 'ex1',
          reason: 'active-exercise pointer also survives the delete');
    },
  );

  test(
    'pending warmup keeps isAwaitingDoneConfirmation false after delete',
    () async {
      await restoreWith(
        makeSession(
          exercises: [
            makeExercise(
              exerciseId: 'ex1',
              setIds: ['set_a', 'set_b'],
              withWarmup: true,
            ),
          ],
        ),
      );

      await logSet('ex1', 'set_a');
      // set_b stays unlogged; warmup_a stays unlogged.

      bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_b'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final ex = currentExercise('ex1');
      expect(ex.completed, isFalse);
      expect(ex.isAwaitingDoneConfirmation, isFalse,
          reason:
              'warmup is still pending — the bottom button must keep '
              'pointing at the warmup, not flip to Done');
    },
  );

  test(
    'deleting one of several unlogged sets leaves isAwaitingDoneConfirmation '
    'false (still more sets to log)',
    () async {
      await restoreWith(
        makeSession(
          exercises: [
            makeExercise(
              exerciseId: 'ex1',
              setIds: ['set_a', 'set_b', 'set_c'],
            ),
          ],
        ),
      );

      await logSet('ex1', 'set_a');
      // set_b and set_c both unlogged.

      bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_c'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final ex = currentExercise('ex1');
      expect(ex.completed, isFalse);
      expect(ex.isAwaitingDoneConfirmation, isFalse,
          reason: 'set_b is still unlogged — Log Set has a target');
    },
  );

  test(
    'deleting the only (logged) set leaves the exercise with zero sets — '
    'no auto-complete, isAwaitingDoneConfirmation is false (empty list)',
    () async {
      await restoreWith(
        makeSession(
          exercises: [
            makeExercise(exerciseId: 'ex1', setIds: ['set_a']),
          ],
        ),
      );

      await logSet('ex1', 'set_a');
      bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_a'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final ex = currentExercise('ex1');
      expect(ex.completed, isFalse);
      expect(ex.sets, isEmpty);
      expect(ex.isAwaitingDoneConfirmation, isFalse,
          reason:
              'isAllSetsLogged is false on empty lists — the Done state '
              'requires at least one effective set on the exercise');
    },
  );

  test(
    'deleting a non-final unlogged set when the rest are logged also lands '
    'in awaiting-Done (order of deletes does not matter)',
    () async {
      await restoreWith(
        makeSession(
          exercises: [
            makeExercise(
              exerciseId: 'ex1',
              setIds: ['set_a', 'set_b', 'set_c'],
            ),
          ],
        ),
      );

      await logSet('ex1', 'set_a');
      await logSet('ex1', 'set_c');
      // set_b stays unlogged in the middle.

      bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_b'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final ex = currentExercise('ex1');
      expect(ex.completed, isFalse);
      expect(ex.isAwaitingDoneConfirmation, isTrue);
    },
  );
}
