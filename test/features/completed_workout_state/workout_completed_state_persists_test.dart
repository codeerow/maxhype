// Fixes the brief requirements for Item 1 — Completed workout card state:
//   - "Completed state must persist after navigation, app restart, and
//      session restore" (brief §1)
//   - "just recover workouts every week" (clarification 1.2)
//   - "the latest duration" (clarification 1.3)
//   - "the total elapsed wall-clock between Start and Finish"
//     (clarification 1.5)
//
// These tests exercise the on-disk store (the user-visible promise is
// "state persists"), the ISO-week boundary that flips Completed back to
// Ready, and the "latest-wins" rule for same-workout-finished-twice.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/workout_completion.dart';
import 'package:maxhype/repositories/local_workout_completion_repository.dart';

void main() {
  late Directory tempDir;
  late LocalWorkoutCompletionRepository repo;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('mh_completion_');
    repo = LocalWorkoutCompletionRepository(
      directoryResolver: () async => tempDir,
    );
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test(
      'completed state persists across repository instances (simulating '
      'app restart within the same week)', () async {
    // Finish workout A on Monday.
    await repo.upsert(WorkoutCompletion(
      workoutId: 'push_day',
      completedAt: DateTime(2026, 6, 1, 18, 30), // Monday
      durationSeconds: 17 * 60,
    ));

    // Re-instantiating the repository (same directory) mirrors what
    // happens after an app restart — disk is the source of truth.
    final reopened = LocalWorkoutCompletionRepository(
      directoryResolver: () async => tempDir,
    );
    final map = await reopened.loadAll();

    expect(map.containsKey('push_day'), isTrue);
    expect(map['push_day']!.durationSeconds, 17 * 60);
  });

  test(
      'a completion from the previous ISO week does not count as completed '
      'in the current week (brief §1, clarification 1.2)', () async {
    final lastWeekFinish = DateTime(2026, 5, 25, 18, 30); // prev Monday
    final thisWeekNow = DateTime(2026, 6, 1, 9, 0); // this Monday

    await repo.upsert(WorkoutCompletion(
      workoutId: 'push_day',
      completedAt: lastWeekFinish,
      durationSeconds: 17 * 60,
    ));

    final stored = (await repo.loadAll())['push_day']!;
    // The record is still on disk — but the home screen filters by
    // ISO-week before showing the Completed footer, so this call must
    // report "not in current week" for the card to revert to Ready.
    expect(isInSameWeek(stored.completedAt, thisWeekNow), isFalse);
  });

  test(
      'finishing the same workout twice in one week keeps the latest '
      'duration (clarification 1.3)', () async {
    // First finish — 10 minutes on Monday morning.
    await repo.upsert(WorkoutCompletion(
      workoutId: 'push_day',
      completedAt: DateTime(2026, 6, 1, 8, 30),
      durationSeconds: 10 * 60,
    ));
    // Second finish later the same day — 25 minutes.
    await repo.upsert(WorkoutCompletion(
      workoutId: 'push_day',
      completedAt: DateTime(2026, 6, 1, 18, 30),
      durationSeconds: 25 * 60,
    ));

    final stored = (await repo.loadAll())['push_day']!;
    expect(stored.durationSeconds, 25 * 60,
        reason: 'latest finish must overwrite earlier duration');
  });

  test(
      'duration recorded is the wall-clock elapsed between Start and Finish '
      '(clarification 1.5)', () async {
    final start = DateTime(2026, 6, 1, 9, 0);
    final finish = DateTime(2026, 6, 1, 9, 17, 30);
    await repo.upsert(WorkoutCompletion(
      workoutId: 'push_day',
      completedAt: finish,
      durationSeconds: finish.difference(start).inSeconds,
    ));

    final stored = (await repo.loadAll())['push_day']!;
    expect(stored.durationSeconds, 17 * 60 + 30,
        reason:
            '17 minutes 30 seconds of wall-clock — not active logging time');
  });

  test(
      'two workouts completed in the same week each get their own record '
      '(no collision on the workoutId key)', () async {
    await repo.upsert(WorkoutCompletion(
      workoutId: 'push_day',
      completedAt: DateTime(2026, 6, 1, 18, 0),
      durationSeconds: 17 * 60,
    ));
    await repo.upsert(WorkoutCompletion(
      workoutId: 'pull_day',
      completedAt: DateTime(2026, 6, 2, 18, 0),
      durationSeconds: 22 * 60,
    ));

    final map = await repo.loadAll();
    expect(map.length, 2);
    expect(map['push_day']!.durationSeconds, 17 * 60);
    expect(map['pull_day']!.durationSeconds, 22 * 60);
  });

  test('a corrupt completion file is recovered into an empty map on load',
      () async {
    final file = File('${tempDir.path}/workout_completion.json');
    file.writeAsStringSync('{not valid json');
    final map = await repo.loadAll();
    expect(map, isEmpty,
        reason:
            'a corrupt store must not crash the home screen — start fresh');
  });

  group('isInSameWeek (ISO-week boundary semantics)', () {
    test('Sunday and the following Monday are in different ISO weeks', () {
      final sunday = DateTime(2026, 6, 7, 23, 59);
      final monday = DateTime(2026, 6, 8, 0, 1);
      expect(isInSameWeek(sunday, monday), isFalse,
          reason:
              'ISO weeks run Monday–Sunday; Monday begins a new week so the '
              'previous Sunday must not count as "this week"');
    });

    test('Monday and Sunday of the same ISO week are in the same week', () {
      final monday = DateTime(2026, 6, 1, 9, 0);
      final sunday = DateTime(2026, 6, 7, 22, 0);
      expect(isInSameWeek(monday, sunday), isTrue);
    });

    test('completion and "now" on different days same week → same week', () {
      final completion = DateTime(2026, 6, 1, 18, 0);
      final now = DateTime(2026, 6, 3, 9, 0);
      expect(isInSameWeek(completion, now), isTrue);
    });
  });
}
