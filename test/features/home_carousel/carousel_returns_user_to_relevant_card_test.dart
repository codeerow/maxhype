// Fixes the brief requirements for Item 3 — Home carousel
// auto-positioning:
//   - "Home carousel should land on the current workout card, not a
//      random/previous card" (brief §3, when an active workout exists)
//   - "User briefly sees Push card marked Completed · 17 mins, then
//      carousel auto-aligns to next workout card" (brief §3)
//   - "If the completed workout was the final card of the week — stay
//      on the completed final card" (brief §3, clarification 3.8)
//   - "skip already-completed cards when picking the next destination"
//     (clarification 3.7 — "the next not completed workout")
//   - "App restart with active workout → carousel lands on active
//      workout card" (brief §11)

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/workout.dart';
import 'package:maxhype/models/workout_completion.dart';
import 'package:maxhype/widgets/carousel_positioning.dart';

Workout _w(String id) => Workout(
      id: id,
      title: id,
      subtitle: '',
      duration: '30 min',
      exerciseCount: 0,
      recoveryInfo: RecoveryInfo(
        status: RecoveryStatus.ready,
        percentage: 100,
        description: '',
      ),
      exercises: const <Exercise>[],
      targetMuscles: const [],
    );

WorkoutCompletion _completion(String id, DateTime at) => WorkoutCompletion(
      workoutId: id,
      completedAt: at,
      durationSeconds: 17 * 60,
    );

void main() {
  final workouts = [_w('push'), _w('pull'), _w('legs'), _w('arms')];
  // Pick a Wednesday so "this week" is unambiguous.
  final now = DateTime(2026, 6, 3, 9, 0);
  final earlierThisWeek = DateTime(2026, 6, 1, 18, 0); // Monday this week
  final lastWeek = DateTime(2026, 5, 25, 18, 0);

  group('On mount with an active session', () {
    test('returns the index of the active workout so the carousel can focus it',
        () {
      expect(
        activeCardIndex(workouts: workouts, activeWorkoutId: 'legs'),
        2,
      );
    });

    test('returns null when there is no active workout (carousel stays put)',
        () {
      expect(
        activeCardIndex(workouts: workouts, activeWorkoutId: null),
        isNull,
      );
    });

    test('returns null when the active workoutId is not in the list', () {
      expect(
        activeCardIndex(
          workouts: workouts,
          activeWorkoutId: 'mystery_workout',
        ),
        isNull,
      );
    });
  });

  group('After a workout finishes', () {
    test(
        'lands on the first not-completed workout in plan order, even when '
        'that workout sits BEFORE the one the user just finished', () {
      // Just finished `pull` (index 1). `push` (0) was never completed
      // this week — that's what's still missing from the plan, so the
      // carousel must rewind to it rather than skip ahead to `legs`.
      final next = nextNotCompletedIndex(
        workouts: workouts,
        fromIndex: 1,
        completions: {},
        now: now,
      );
      expect(next, 0,
          reason:
              'next-in-plan semantics — the first remaining workout wins, '
              'regardless of carousel position');
    });

    test(
        'skips already-completed workouts when picking the next destination '
        '(clarification 3.7)', () {
      // `push` completed earlier in the week, `pull` just finished —
      // `legs` is the first remaining; `arms` follows it.
      final next = nextNotCompletedIndex(
        workouts: workouts,
        fromIndex: 1,
        completions: {'push': _completion('push', earlierThisWeek)},
        now: now,
      );
      expect(next, 2);
    });

    test(
        'stays on the finished card when every other workout in the week is '
        'completed (brief §3 — "stay on the completed final card")', () {
      final next = nextNotCompletedIndex(
        workouts: workouts,
        fromIndex: 1,
        completions: {
          'push': _completion('push', earlierThisWeek),
          'legs': _completion('legs', earlierThisWeek),
          'arms': _completion('arms', earlierThisWeek),
        },
        now: now,
      );
      expect(next, isNull);
    });

    test(
        'a completion from last week does NOT block its workout from being '
        'picked as the next destination (clarification 1.2 — weekly reset)',
        () {
      // `legs` was completed last week — that record is on disk but
      // doesn't count this week, so the helper should treat it as a
      // not-yet-done card. With nothing else completed, the first
      // remaining is `push` (0).
      final next = nextNotCompletedIndex(
        workouts: workouts,
        fromIndex: 1,
        completions: {'legs': _completion('legs', lastWeek)},
        now: now,
      );
      expect(next, 0);
    });

    test(
        'when the finished workout is the only remaining gap and the user '
        'finishes it, returns null (stay put)', () {
      // Push, legs, arms completed this week. Pull was just finished —
      // nothing remains, so the carousel stays on the finished card.
      final next = nextNotCompletedIndex(
        workouts: workouts,
        fromIndex: 1,
        completions: {
          'push': _completion('push', earlierThisWeek),
          'legs': _completion('legs', earlierThisWeek),
          'arms': _completion('arms', earlierThisWeek),
        },
        now: now,
      );
      expect(next, isNull);
    });

    test('returns null on a single-workout carousel (nowhere to go)', () {
      final next = nextNotCompletedIndex(
        workouts: [_w('only')],
        fromIndex: 0,
        completions: {},
        now: now,
      );
      expect(next, isNull);
    });
  });
}
