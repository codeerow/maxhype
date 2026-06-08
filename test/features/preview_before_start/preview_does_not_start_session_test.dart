// Fixes the brief requirements for Item 6 — Preview exercises before Start:
//   - "Previewing an exercise must not start the workout timer."
//   - "Must not create an active workout session."
//   - "Must not log anything automatically." (brief §6)
//   - "If the user backs out without pressing Start Workout, there
//      should be no active session." (brief §6)
//
// The user-visible promise is "I can browse and pre-fill, but my
// session doesn't start until I tap Start". These tests pin the
// invariant on WorkoutPreviewBloc and WorkoutSessionBloc — preview
// mutations stay in the preview cubit, the session bloc stays Idle.

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/screens/workout_detail/bloc/workout_preview_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_bloc.dart';
import 'package:maxhype/screens/workout_session/bloc/workout_session_state.dart';
import 'package:mocktail/mocktail.dart';

import '../../screens/workout_session/bloc/helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(registerSessionFallback);

  late MockWorkoutSessionRepository repo;
  late MockPersonalRecordRepository prRepo;
  late WorkoutSessionBloc sessionBloc;
  late WorkoutPreviewBloc previewBloc;

  setUp(() {
    repo = MockWorkoutSessionRepository();
    prRepo = MockPersonalRecordRepository();
    when(() => repo.loadActive()).thenAnswer((_) async => null);
    when(() => repo.save(any())).thenAnswer((_) async {});
    when(() => prRepo.bestFor(any())).thenAnswer((_) async => null);
    sessionBloc = WorkoutSessionBloc(
      repository: repo,
      prRepository: prRepo,
      bell: FakeBell(),
      scheduler: FakeScheduler(),
    );
    previewBloc = WorkoutPreviewBloc();
  });

  tearDown(() async {
    await sessionBloc.close();
    await previewBloc.close();
  });

  test('seeding a preview draft does not create a session', () {
    previewBloc.seedEffectiveSets('ex1', 3);
    expect(sessionBloc.state, isA<SessionIdle>(),
        reason: 'preview must not flip the bloc out of Idle');
    verifyNever(() => repo.save(any()));
  });

  test('editing weight/reps in preview does not create a session', () {
    previewBloc.seedEffectiveSets('ex1', 2);
    final firstId = previewBloc.draftFor('ex1').sets.first.id;

    previewBloc.setWeight(
      exerciseId: 'ex1',
      setId: firstId,
      kind: SetKind.effective,
      weight: 100,
      clear: false,
    );
    previewBloc.setReps(
      exerciseId: 'ex1',
      setId: firstId,
      kind: SetKind.effective,
      reps: 5,
      clear: false,
    );

    expect(sessionBloc.state, isA<SessionIdle>());
    verifyNever(() => repo.save(any()));
  });

  test(
      'adding warmups / drop sets and editing them in preview does not '
      'create a session (clarification 6.18)', () {
    previewBloc.addRow('ex1', SetKind.warmup);
    previewBloc.addRow('ex1', SetKind.dropSet);
    previewBloc.addRow('ex1', SetKind.warmup);
    expect(previewBloc.draftFor('ex1').warmups.length, 2);
    expect(previewBloc.draftFor('ex1').dropSets.length, 1);

    expect(sessionBloc.state, isA<SessionIdle>(),
        reason: 'add/delete preview rows must not start a workout');
  });

  test(
      'discarding the preview bloc (user backs out without Start) leaves '
      'the session bloc untouched', () async {
    previewBloc.seedEffectiveSets('ex1', 2);
    previewBloc.addRow('ex1', SetKind.warmup);
    await previewBloc.close();

    expect(sessionBloc.state, isA<SessionIdle>());
    verifyNever(() => repo.save(any()));
  });
}
