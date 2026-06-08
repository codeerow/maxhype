// Fixes the brief requirements for Item 8 / Item 11:
//   - "Warm-up sets should not count toward PR" (brief §8, clarification 8.24)
//   - "Drop sets should not count toward PR by default" (brief §8,
//      clarification 8.24)
//   - "Replacing/deleting sets should not cause false PR animations"
//     (brief §11)
//
// A "false PR animation" in our system means a `PrAchievedSignal` fired
// on the side-channel — that's what the logging screen and session card
// subscribe to.

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/session/personal_record.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/screens/workout_session/bloc/pr_signal.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_event.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../screens/workout_session/bloc/helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(registerSessionFallback);

  late MockWorkoutSessionRepository repo;
  late MockPersonalRecordRepository prRepo;
  late WorkoutSessionBloc bloc;

  /// Stable historical baseline (95 lb × 5) so that the workout-level
  /// "first-workout silence" guard is OFF — meaning PR signals *can*
  /// fire if the rules say they should. Without a baseline the bloc
  /// suppresses PR animations entirely (see brief §1 of milestone 4).
  PersonalRecord historicalBaseline() => PersonalRecord(
        exerciseId: 'ex1',
        weight: 95,
        reps: 5,
        achievedAt: DateTime(2024, 11, 1),
      );

  setUp(() {
    repo = MockWorkoutSessionRepository();
    prRepo = MockPersonalRecordRepository();
    when(() => repo.loadActive()).thenAnswer((_) async => makeSession(
          exercises: [
            makeExercise(
              exerciseId: 'ex1',
              setIds: ['set_a', 'set_b'],
              warmupIds: ['w1'],
              dropSetIds: ['d1'],
            ),
          ],
        ));
    when(() => repo.save(any())).thenAnswer((_) async {});
    when(() => prRepo.bestFor('ex1'))
        .thenAnswer((_) async => historicalBaseline());
    bloc = WorkoutSessionBloc(
      repository: repo,
      prRepository: prRepo,
      bell: FakeBell(),
      scheduler: FakeScheduler(),
    );
  });

  tearDown(() => bloc.close());

  Future<List<PrSignal>> _restoreAndCollectSignals() async {
    final signals = <PrSignal>[];
    bloc.prSignals.listen(signals.add);
    bloc.add(const RestoreSession());
    await bloc.stream.firstWhere((s) => s is SessionActive);
    // Let the prRepo.bestFor future complete and the bloc's
    // PrCacheLoaded follow-up event flow through.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return signals;
  }

  test('a heavy warmup heavier than the historical PR does not become the PR',
      () async {
    final signals = await _restoreAndCollectSignals();

    // Log a warmup at 200 lb — way above the 95 lb historical PR.
    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'w1',
      weight: 200,
      reps: 20,
      kind: SetKind.warmup,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.prFor('ex1')?.weight, 95,
        reason: 'warmup must not displace the historical PR head');
    expect(signals.whereType<PrAchievedSignal>(), isEmpty,
        reason: 'a logged warmup must not fire the PR celebration');
  });

  test('a heavy drop set heavier than the historical PR does not become the PR',
      () async {
    final signals = await _restoreAndCollectSignals();

    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'd1',
      weight: 300,
      reps: 8,
      kind: SetKind.dropSet,
    ));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.prFor('ex1')?.weight, 95,
        reason: 'drop set must not displace the historical PR head');
    expect(signals.whereType<PrAchievedSignal>(), isEmpty,
        reason: 'a logged drop set must not fire the PR celebration');
  });

  test(
      'deleting a working set rolls the PR back to the runner-up, '
      'ignoring warmups and drops in the ranking', () async {
    final signals = await _restoreAndCollectSignals();

    // Climb the working sets above the historical baseline.
    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'set_a',
      weight: 110,
      reps: 5,
    ));
    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'set_b',
      weight: 120,
      reps: 5,
    ));
    await Future<void>.delayed(Duration.zero);
    // Stuff in a warmup and a drop heavier than every working set —
    // they must not influence the head or the rollback target.
    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'w1',
      weight: 250,
      reps: 12,
      kind: SetKind.warmup,
    ));
    bloc.add(const LogSet(
      exerciseId: 'ex1',
      setId: 'd1',
      weight: 250,
      reps: 12,
      kind: SetKind.dropSet,
    ));
    await Future<void>.delayed(Duration.zero);

    // Head is now the 120-lb working set.
    expect(bloc.prFor('ex1')?.weight, 120);

    // Delete the 120 head — head must fall back to 110 (the next
    // working set), NOT to the 250-lb warmup or drop.
    signals.clear();
    bloc.add(const DeleteSet(exerciseId: 'ex1', setId: 'set_b'));
    await Future<void>.delayed(Duration.zero);

    expect(bloc.prFor('ex1')?.weight, 110,
        reason:
            'rollback target must be the next working set, not a warmup/drop');
    expect(signals.whereType<PrAchievedSignal>(), isEmpty,
        reason: 'rollback is not a new PR — no celebration must fire');
  });
}
