// Pins behaviour for Item 5 — Workout In Progress bar navigation
// (brief §5):
//
//   - "If the user was actively logging a specific exercise →
//      navigate to that exact exercise/logging screen"
//   - "If workout started but no exercise has been started/logged
//      yet → route to the first/next incomplete exercise"
//   - "the last one being logged (the same logic as active exercise)"
//     (clarification 5.13)
//
// `resumeTargetExerciseId` is the pure helper that encodes those
// rules. The actual nested-push UX is exercised in the demo walk.

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/session/session_exercise.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/models/session/workout_session.dart';
import 'package:maxhype/screens/workout_session/in_progress_bar_routing.dart';

SessionExercise _exercise({
  required String id,
  bool completed = false,
  List<SessionSet> sets = const [],
}) {
  return SessionExercise(
    exerciseId: id,
    name: id,
    equipment: EquipmentType.barbell,
    targetSets: sets.length,
    sets: sets,
    completed: completed,
  );
}

SessionSet _logged(String id, DateTime at) => SessionSet(
      id: id,
      weight: 100,
      reps: 5,
      loggedAt: at,
    );

WorkoutSession _session({
  required List<SessionExercise> exercises,
  String? activeExerciseId,
}) {
  return WorkoutSession(
    id: 'session',
    workoutId: 'workout',
    workoutName: 'workout',
    startedAt: DateTime(2026, 6, 1, 9),
    exercises: exercises,
    activeExerciseId: activeExerciseId,
  );
}

void main() {
  test(
      'an active exercise sends the user straight to its logging screen '
      '(brief §5 — "navigate to that exact exercise")', () {
    final session = _session(
      exercises: [
        _exercise(id: 'ex1'),
        _exercise(id: 'ex2'),
        _exercise(id: 'ex3'),
      ],
      activeExerciseId: 'ex2',
    );
    expect(resumeTargetExerciseId(session), 'ex2');
  });

  test(
      'with no active exercise but some sets logged, the bar routes to the '
      'exercise that received the most recent log (clarification 5.13)', () {
    final session = _session(
      exercises: [
        _exercise(id: 'ex1', sets: [
          _logged('s1', DateTime(2026, 6, 1, 9, 5)),
        ]),
        _exercise(id: 'ex2', sets: [
          _logged('s2', DateTime(2026, 6, 1, 9, 20)),
        ]),
        _exercise(id: 'ex3'),
      ],
    );
    expect(resumeTargetExerciseId(session), 'ex2');
  });

  test(
      'no active exercise, nothing logged yet — bar routes to the first '
      'incomplete exercise (brief §5)', () {
    final session = _session(
      exercises: [
        _exercise(id: 'ex1', completed: true),
        _exercise(id: 'ex2'),
        _exercise(id: 'ex3'),
      ],
    );
    expect(resumeTargetExerciseId(session), 'ex2',
        reason:
            'ex1 is already done so the first not-yet-touched row wins');
  });

  test(
      'fresh session — bar routes to the first exercise as the first '
      'incomplete (brief §5)', () {
    final session = _session(
      exercises: [
        _exercise(id: 'ex1'),
        _exercise(id: 'ex2'),
        _exercise(id: 'ex3'),
      ],
    );
    expect(resumeTargetExerciseId(session), 'ex1');
  });

  test(
      'a completed exercise referenced by activeExerciseId is ignored — the '
      'bar falls through to the last-logged / first-incomplete rules', () {
    final session = _session(
      exercises: [
        _exercise(id: 'ex1', completed: true),
        _exercise(id: 'ex2', sets: [
          _logged('s2', DateTime(2026, 6, 1, 9, 10)),
        ]),
      ],
      activeExerciseId: 'ex1',
    );
    expect(resumeTargetExerciseId(session), 'ex2');
  });

  test('returns null on an empty session (defensive — bar should be hidden)',
      () {
    final session = _session(exercises: const []);
    expect(resumeTargetExerciseId(session), isNull);
  });
}
