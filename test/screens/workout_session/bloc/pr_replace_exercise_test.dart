import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/screens/workout_session/bloc/pr_signal.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers.dart';

/// Documents how PR head behaves across `ReplaceExercise` under the
/// recompute-from-sets architecture (variant B).
///
/// Key rules:
///   * Replace drops the old id's head and historical baseline.
///   * The new id loads its OWN historical baseline (independent lookup
///     against `prRepository.bestFor(newId)`).
///   * Carried-over logged sets count for the new id — `_recomputeFor`
///     ranks them alongside the new historical baseline, so a replace
///     does not "lose" PR information from the user's already-logged
///     work.
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
    // Default historical baseline is featherweight (1×1) so every
    // exercise — including replacement targets — passes the
    // workout-level "first workout is silent" gate and intra-session
    // signals fire as the carryover-and-replace logic intends. Specific
    // tests can override per-id (e.g. to model a fresh exercise with no
    // prior history).
    when(() => prRepo.bestFor(any()))
        .thenAnswer((_) async => pr(weight: 1, reps: 1));
    bloc = WorkoutSessionBloc(repository: repo, prRepository: prRepo);
  });

  tearDown(() async {
    await bloc.close();
  });

  Future<void> restoreSingleExercise() async {
    when(() => repo.loadActive()).thenAnswer(
      (_) async => makeSession(
        exercises: [
          makeExercise(exerciseId: 'ex_old', setIds: ['set_a', 'set_b']),
        ],
      ),
    );
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);
    await Future<void>.delayed(Duration.zero);
  }

  Exercise _newExercise(String id) => Exercise(
        id: id,
        name: 'New Lift',
        sets: 2,
        reps: 10,
        weight: 0,
        muscleGroups: const [],
        equipmentType: EquipmentType.barbell,
        rating: 0,
      );

  test(
    'replace before any LogSet: new exerciseId acts like a fresh exercise',
    () async {
      // Override the default featherweight baseline for the replacement
      // id only — this test is specifically about the "no history yet"
      // path, so the post-replace head must really be null and the
      // first set must land silently.
      when(() => prRepo.bestFor('ex_new'))
          .thenAnswer((_) async => null);

      await restoreSingleExercise();

      bloc.add(ReplaceExercise(
        oldExerciseId: 'ex_old',
        newExercise: _newExercise('ex_new'),
      ));
      await Future<void>.delayed(Duration.zero);

      // Sanity: the session no longer carries ex_old, and ex_new has no
      // PR head yet.
      expect(bloc.prFor('ex_new'), isNull);
      expect(bloc.prFor('ex_old'), isNull);

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      // First set on the replacement → silent baseline, no celebration
      // (workout-level rule: no historical baseline for ex_new).
      bloc.add(const LogSet(
        exerciseId: 'ex_new',
        setId: 'set_a',
        weight: 100,
        reps: 5,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(signals, isEmpty,
          reason: 'fresh exercise → first set is silent baseline');
      expect(bloc.prFor('ex_new')?.weight, 100);

      await sub.cancel();
    },
  );

  test(
    'replace AFTER logged sets on old id: carried sets seed head on new id',
    () async {
      await restoreSingleExercise();

      // Log two sets on ex_old. After replace these carry over to ex_new.
      bloc.add(const LogSet(
          exerciseId: 'ex_old', setId: 'set_a', weight: 100, reps: 5));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const LogSet(
          exerciseId: 'ex_old', setId: 'set_b', weight: 110, reps: 5));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.prFor('ex_old')?.weight, 110);

      bloc.add(ReplaceExercise(
        oldExerciseId: 'ex_old',
        newExercise: _newExercise('ex_new'),
      ));
      await Future<void>.delayed(Duration.zero);

      // ex_new now owns the carried logged sets — ranking picks the
      // heaviest as head. The user's work isn't lost.
      expect(bloc.prFor('ex_new')?.weight, 110);
      // Old id no longer tracked — its head is gone.
      expect(bloc.prFor('ex_old'), isNull);
      // hasFreshPr is true because the head was produced by a live set
      // (set_b), not by a historical baseline.
      expect(bloc.hasFreshPr('ex_new'), isTrue);
    },
  );

  test(
    'after replace with carried logged set, '
    'logging a heavier set fires PrAchievedSignal as expected',
    () async {
      await restoreSingleExercise();

      // Log set_a, then replace — set_a carries over to ex_new as head.
      bloc.add(const LogSet(
          exerciseId: 'ex_old', setId: 'set_a', weight: 100, reps: 5));
      await Future<void>.delayed(Duration.zero);
      bloc.add(ReplaceExercise(
        oldExerciseId: 'ex_old',
        newExercise: _newExercise('ex_new'),
      ));
      await Future<void>.delayed(Duration.zero);
      expect(bloc.prFor('ex_new')?.weight, 100,
          reason: 'carried set_a is the head of ex_new');

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      // set_b beats set_a → revoke(set_a) + achieved(set_b).
      bloc.add(const LogSet(
        exerciseId: 'ex_new',
        setId: 'set_b',
        weight: 120,
        reps: 5,
      ));
      await Future<void>.delayed(Duration.zero);

      expect(signals.whereType<PrRevokedSignal>().single.setId, 'set_a');
      expect(signals.whereType<PrAchievedSignal>().single.setId, 'set_b');
      expect(bloc.prFor('ex_new')?.weight, 120);

      await sub.cancel();
    },
  );

  test(
    'replace then beat: subsequent set beating new baseline fires '
    'PrAchievedSignal as for any fresh exercise',
    () async {
      await restoreSingleExercise();

      bloc.add(ReplaceExercise(
        oldExerciseId: 'ex_old',
        newExercise: _newExercise('ex_new'),
      ));
      await Future<void>.delayed(Duration.zero);

      // First set on ex_new → silent baseline at 100.
      bloc.add(const LogSet(
          exerciseId: 'ex_new', setId: 'set_a', weight: 100, reps: 5));
      await Future<void>.delayed(Duration.zero);

      final signals = <PrSignal>[];
      final sub = bloc.prSignals.listen(signals.add);

      // Second set beats baseline → signal expected.
      bloc.add(const LogSet(
          exerciseId: 'ex_new', setId: 'set_b', weight: 110, reps: 5));
      await Future<void>.delayed(Duration.zero);

      expect(signals.whereType<PrAchievedSignal>(), hasLength(1));
      expect(bloc.prFor('ex_new')?.weight, 110);

      await sub.cancel();
    },
  );
}
