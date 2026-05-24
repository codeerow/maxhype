import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/session/workout_session.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

/// Auto-complete invariant in `_onDeleteSet`: when the user trims the
/// last unlogged effective set off an exercise whose remaining sets are
/// all logged (and whose warmup is satisfied), the exercise flips to
/// `completed = true` and the rest timer is cleared. Without this, the
/// "Log Set" button would have no target and the user would be stuck
/// unable to finish the exercise.
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
    'deleting last unlogged set after others are logged completes the exercise',
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

      expect(currentExercise('ex1').completed, isFalse,
          reason: 'still one unlogged set left — not done yet');

      // Delete the only remaining unlogged set.
      bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_c'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final ex = currentExercise('ex1');
      expect(ex.completed, isTrue,
          reason:
              'no unlogged set remains and all survivors are logged — '
              'exercise auto-completes');
      expect(ex.sets.length, 2);
      expect(ex.targetSets, 2,
          reason: 'targetSets decrements alongside the removed set');
    },
  );

  test(
    'auto-complete clears activeExerciseId and activeRestEndsAt',
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
      // Start a rest timer so we can prove it gets cleared.
      bloc.add(const StartRestTimer(duration: Duration(seconds: 60)));
      await Future<void>.delayed(Duration.zero);
      final sActive = bloc.state as SessionActive;
      expect(sActive.session.activeRestEndsAt, isNotNull);
      expect(sActive.session.activeExerciseId, 'ex1');

      bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_b'));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      final s = bloc.state as SessionActive;
      expect(currentExercise('ex1').completed, isTrue);
      expect(s.session.activeRestEndsAt, isNull,
          reason: 'auto-complete cancels the rest timer');
      expect(s.session.activeExerciseId, isNull,
          reason: 'auto-complete clears the active exercise pointer');
    },
  );

  test(
    'pending warmup blocks auto-complete even when all effective sets are logged',
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

      expect(currentExercise('ex1').completed, isFalse,
          reason: 'warmup is still pending — exercise must not auto-complete');
    },
  );

  test(
    'unlogged sets remaining block auto-complete',
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

      expect(currentExercise('ex1').completed, isFalse,
          reason:
              'set_b is still unlogged — survivors are not all-logged, '
              'no auto-complete');
    },
  );

  test(
    'deleting the only set (logged) does not auto-complete '
    '(no surviving sets)',
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
      expect(ex.completed, isFalse,
          reason:
              'shouldComplete requires newSets.isNotEmpty — deleting the '
              'last set leaves nothing to mark "done"');
      expect(ex.sets, isEmpty);
    },
  );

  test(
    'deleting a non-final unlogged set when others are logged still '
    'auto-completes (regression — sets every-logged after delete)',
    () async {
      // Edge case: order doesn't matter. If after delete every remaining
      // set is logged, we auto-complete regardless of which unlogged set
      // we removed.
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

      expect(currentExercise('ex1').completed, isTrue,
          reason: 'removing the only unlogged set finishes the exercise');
    },
  );
}
