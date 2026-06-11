// Fixes the brief requirement (clarification 8.25):
//   "all sets should be logged or deleted"
// in conjunction with brief §11:
//   "Done state still requires user to manually press Done after final
//    set is logged"
//
// "All sets" in the milestone vocabulary covers every row regardless of
// kind: warm-ups, working sets, and drop sets must each be either
// logged or deleted before the bottom button flips to "Done".
//
// `SessionExercise.isAwaitingDoneConfirmation` is the single source of
// truth the UI binds to — these tests pin it.

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/session/session_exercise.dart';
import 'package:maxhype/models/session/session_set.dart';

SessionSet _logged(String id, SetKind kind) => SessionSet(
      id: id,
      kind: kind,
      weight: 100,
      reps: 5,
      loggedAt: DateTime(2025, 1, 1, 10),
    );

SessionSet _unlogged(String id, SetKind kind) =>
    SessionSet(id: id, kind: kind);

SessionExercise _ex({
  List<SessionSet> sets = const [],
  List<SessionSet> warmups = const [],
  List<SessionSet> dropSets = const [],
}) {
  return SessionExercise(
    slotId: 'ex1',
    exerciseId: 'ex1',
    name: 'Bench',
    equipment: EquipmentType.barbell,
    targetSets: sets.length,
    sets: sets,
    warmups: warmups,
    dropSets: dropSets,
  );
}

void main() {
  group(
      'Done is unavailable while any warmup, working set, or drop set is '
      'unlogged', () {
    test('a pending warmup blocks Done even after every working set is logged',
        () {
      final ex = _ex(
        sets: [_logged('s1', SetKind.effective)],
        warmups: [_unlogged('w1', SetKind.warmup)],
      );
      expect(ex.isAwaitingDoneConfirmation, isFalse);
    });

    test('a pending working set blocks Done even after warmups are logged',
        () {
      final ex = _ex(
        sets: [
          _logged('s1', SetKind.effective),
          _unlogged('s2', SetKind.effective),
        ],
        warmups: [_logged('w1', SetKind.warmup)],
      );
      expect(ex.isAwaitingDoneConfirmation, isFalse);
    });

    test(
        'a pending drop set blocks Done even after warmups and working sets '
        'are logged', () {
      final ex = _ex(
        sets: [_logged('s1', SetKind.effective)],
        warmups: [_logged('w1', SetKind.warmup)],
        dropSets: [_unlogged('d1', SetKind.dropSet)],
      );
      expect(ex.isAwaitingDoneConfirmation, isFalse);
    });
  });

  test(
      'Done becomes available after the last unlogged row across all sections '
      'is logged', () {
    final ex = _ex(
      sets: [
        _logged('s1', SetKind.effective),
        _logged('s2', SetKind.effective),
      ],
      warmups: [
        _logged('w1', SetKind.warmup),
        _logged('w2', SetKind.warmup),
      ],
      dropSets: [_logged('d1', SetKind.dropSet)],
    );
    expect(ex.isAwaitingDoneConfirmation, isTrue);
  });

  test(
      'Done becomes available once the last unlogged drop set is deleted '
      '(per clarification 8.25 — "logged or deleted")', () {
    // Pretend the user has logged all working sets and the warmup, then
    // deleted the only drop set. The resulting state — drop section
    // empty — should satisfy "all sets logged or deleted".
    final ex = _ex(
      sets: [_logged('s1', SetKind.effective)],
      warmups: [_logged('w1', SetKind.warmup)],
      // dropSets intentionally empty — represents the post-delete state.
    );
    expect(ex.isAwaitingDoneConfirmation, isTrue);
  });

  test(
      'Pressing Done does not auto-trigger after the final log — Done is a '
      'separate user action, the model only signals "awaiting" (brief §11)',
      () {
    final ex = _ex(
      sets: [
        _logged('s1', SetKind.effective),
        _logged('s2', SetKind.effective),
      ],
    );
    // The exercise is awaiting Done — but `completed` is still false
    // because no MarkExerciseDone event has fired. The UI uses this to
    // show a "Done" button; the bloc only flips `completed` when the
    // user actually taps it.
    expect(ex.isAwaitingDoneConfirmation, isTrue);
    expect(ex.completed, isFalse);
  });
}
