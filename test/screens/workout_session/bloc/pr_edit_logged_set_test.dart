import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/screens/workout_session/bloc/pr_signal.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

/// Regression for the bug surfaced manually: editing weight/reps on an
/// already-logged set used to leave the PR head pointing at the stale
/// value, so the next logged set could "beat" a phantom head.
///
/// Variant-B recompute: every UpdateSetDraft on a logged effective set
/// re-runs the per-exercise ranking and diffs the head, so the bug
/// can't reappear.
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

  Future<void> restoreThree() async {
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

  test(
    'editing an early logged set to a heavier value moves head onto it',
    () async {
      await restoreThree();

      // Log three sets ascending. head ends up on set_c (12).
      bloc.add(const LogSet(
          exerciseId: 'ex1', setId: 'set_a', weight: 10, reps: 10));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LogSet(
          exerciseId: 'ex1', setId: 'set_b', weight: 11, reps: 11));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LogSet(
          exerciseId: 'ex1', setId: 'set_c', weight: 12, reps: 12));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.prFor('ex1')?.weight, 12);

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      // Now bump set_a to 18-18 via two drafts (one for weight, one for reps).
      bloc.add(const UpdateSetDraft(
        exerciseId: 'ex1',
        setId: 'set_a',
        weight: 18,
      ));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UpdateSetDraft(
        exerciseId: 'ex1',
        setId: 'set_a',
        reps: 18,
      ));
      await Future<void>.delayed(Duration.zero);

      // Head must now be set_a(18, 18). The recompute should have moved
      // head off set_c and onto set_a, emitting both signals.
      expect(bloc.prFor('ex1')?.weight, 18);
      expect(bloc.prFor('ex1')?.reps, 18);
      expect(
        signals.whereType<PrRevokedSignal>().map((s) => s.setId),
        contains('set_c'),
      );
      expect(
        signals.whereType<PrAchievedSignal>().last.setId,
        'set_a',
      );

      await sub.cancel();
    },
  );

  test(
    'after edit, a new set that would have beaten the STALE head '
    'no longer fires PrAchievedSignal',
    () async {
      // The bug: with head stuck at set_c(12), a follow-up set_? at 13 would
      // wrongly celebrate as a new PR. After the fix, head is set_a(18),
      // so 13 should NOT beat it.
      await restoreThree();

      bloc.add(const LogSet(
          exerciseId: 'ex1', setId: 'set_a', weight: 10, reps: 10));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LogSet(
          exerciseId: 'ex1', setId: 'set_b', weight: 11, reps: 11));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LogSet(
          exerciseId: 'ex1', setId: 'set_c', weight: 12, reps: 12));
      await Future<void>.delayed(Duration.zero);

      // Edit set_a to 18-18.
      bloc.add(const UpdateSetDraft(
          exerciseId: 'ex1', setId: 'set_a', weight: 18));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UpdateSetDraft(
          exerciseId: 'ex1', setId: 'set_a', reps: 18));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.prFor('ex1')?.weight, 18);

      // Now edit set_b to 13-13. Without the fix, set_b would chase the
      // stale head=12 and fire achieved. With the fix, head=18 ⇒ silent.
      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      bloc.add(const UpdateSetDraft(
          exerciseId: 'ex1', setId: 'set_b', weight: 13));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UpdateSetDraft(
          exerciseId: 'ex1', setId: 'set_b', reps: 13));
      await Future<void>.delayed(Duration.zero);

      expect(signals.whereType<PrAchievedSignal>(), isEmpty,
          reason: '13-13 does not beat live head 18-18');
      expect(bloc.prFor('ex1')?.weight, 18,
          reason: 'head still set_a');

      await sub.cancel();
    },
  );

  test(
    'editing a logged set DOWN below another logged set demotes its head role',
    () async {
      await restoreThree();

      bloc.add(const LogSet(
          exerciseId: 'ex1', setId: 'set_a', weight: 100, reps: 5));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LogSet(
          exerciseId: 'ex1', setId: 'set_b', weight: 110, reps: 5));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.prFor('ex1')?.weight, 110);

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      // Edit set_b down to 90. Head should fall to set_a(100).
      bloc.add(const UpdateSetDraft(
          exerciseId: 'ex1', setId: 'set_b', weight: 90));
      await Future<void>.delayed(Duration.zero);

      expect(bloc.prFor('ex1')?.weight, 100);
      // set_b was revoked. No achieved — set_a's record (100) didn't
      // beat set_b's old record (110); falling back is not a celebration.
      expect(signals.whereType<PrRevokedSignal>().single.setId, 'set_b');
      expect(signals.whereType<PrAchievedSignal>(), isEmpty);

      await sub.cancel();
    },
  );

  test(
    'editing an UNLOGGED set does not trigger any PR recompute or signal',
    () async {
      await restoreThree();

      bloc.add(const LogSet(
          exerciseId: 'ex1', setId: 'set_a', weight: 100, reps: 5));
      await Future<void>.delayed(Duration.zero);

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      // Type into set_b (unlogged) at heavy values — never logs, so it
      // must not enter the PR ranking.
      bloc.add(const UpdateSetDraft(
          exerciseId: 'ex1', setId: 'set_b', weight: 500));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const UpdateSetDraft(
          exerciseId: 'ex1', setId: 'set_b', reps: 50));
      await Future<void>.delayed(Duration.zero);

      expect(signals, isEmpty);
      expect(bloc.prFor('ex1')?.weight, 100,
          reason: 'head unchanged — set_b is not logged');

      await sub.cancel();
    },
  );
}
