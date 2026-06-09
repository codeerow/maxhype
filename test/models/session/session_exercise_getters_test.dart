import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/session/session_exercise.dart';
import 'package:maxhype/models/session/session_set.dart';

/// Build a SessionExercise with [n] effective sets. Each entry in
/// [loggedIndices] gets a non-null `loggedAt` so it counts as logged.
SessionExercise _ex({
  int n = 3,
  List<int> loggedIndices = const [],
  SessionSet? warmup,
  bool completed = false,
}) {
  final loggedSet = loggedIndices.toSet();
  return SessionExercise(
    exerciseId: 'ex1',
    name: 'Bench',
    equipment: EquipmentType.barbell,
    targetSets: n,
    warmups: warmup == null ? const [] : [warmup],
    completed: completed,
    sets: [
      for (var i = 0; i < n; i++)
        SessionSet(
          id: 'set_$i',
          weight: loggedSet.contains(i) ? (100 + i).toDouble() : null,
          reps: loggedSet.contains(i) ? 5 : null,
          loggedAt: loggedSet.contains(i)
              ? DateTime(2025, 1, 1, 10, i)
              : null,
        ),
    ],
  );
}

SessionSet _warmup({bool logged = false}) {
  return SessionSet(
    id: 'warmup',
    kind: SetKind.warmup,
    weight: logged ? 40 : null,
    reps: logged ? 10 : null,
    loggedAt: logged ? DateTime(2025, 1, 1, 9, 55) : null,
  );
}

void main() {
  group('loggedSetsCount', () {
    test('counts only logged effective sets', () {
      expect(_ex(n: 4, loggedIndices: [0, 2]).loggedSetsCount, 2);
    });

    test('zero when nothing is logged', () {
      expect(_ex(n: 3).loggedSetsCount, 0);
    });

    test('warmup does not contribute', () {
      expect(
        _ex(n: 2, warmup: _warmup(logged: true)).loggedSetsCount,
        0,
      );
    });
  });

  group('hasAnyLoggedSet', () {
    test('false when no effective and no warmup logged', () {
      expect(_ex(n: 2).hasAnyLoggedSet, isFalse);
    });

    test('true when any effective set logged', () {
      expect(_ex(n: 2, loggedIndices: [1]).hasAnyLoggedSet, isTrue);
    });

    test('false when only warmup is logged (warm-up alone is not activity)', () {
      expect(
        _ex(n: 2, warmup: _warmup(logged: true)).hasAnyLoggedSet,
        isFalse,
      );
    });

    test('false when warmup is pending and no effective logged', () {
      expect(
        _ex(n: 2, warmup: _warmup(logged: false)).hasAnyLoggedSet,
        isFalse,
      );
    });
  });

  group('isAllSetsLogged', () {
    test('false for empty sets list', () {
      expect(_ex(n: 0).isAllSetsLogged, isFalse);
    });

    test('true only when every effective set logged', () {
      expect(_ex(n: 3, loggedIndices: [0, 1, 2]).isAllSetsLogged, isTrue);
      expect(_ex(n: 3, loggedIndices: [0, 1]).isAllSetsLogged, isFalse);
    });

    test('warmup state is irrelevant', () {
      expect(
        _ex(
          n: 2,
          loggedIndices: [0, 1],
          warmup: _warmup(logged: false),
        ).isAllSetsLogged,
        isTrue,
      );
    });
  });

  group('hasWarmupPending', () {
    test('false when warmup is null', () {
      expect(_ex(n: 1).hasWarmupPending, isFalse);
    });

    test('true when warmup exists and is unlogged', () {
      expect(
        _ex(n: 1, warmup: _warmup(logged: false)).hasWarmupPending,
        isTrue,
      );
    });

    test('false when warmup exists and is logged', () {
      expect(
        _ex(n: 1, warmup: _warmup(logged: true)).hasWarmupPending,
        isFalse,
      );
    });
  });

  group('lastLoggedSet', () {
    test('null when no sets logged', () {
      expect(_ex(n: 3).lastLoggedSet, isNull);
    });

    test('returns the rightmost logged set (preserves source order)', () {
      // Indices 0 and 2 logged → rightmost is set_2.
      final ex = _ex(n: 3, loggedIndices: [0, 2]);
      expect(ex.lastLoggedSet?.id, 'set_2');
    });

    test('warmup is ignored even when it would be later in time', () {
      // Only warmup is logged; lastLoggedSet looks at effective sets only.
      final ex = _ex(n: 2, warmup: _warmup(logged: true));
      expect(ex.lastLoggedSet, isNull);
    });
  });

  group('firstUnloggedSet', () {
    test('returns the leftmost unlogged effective set', () {
      // [logged, unlogged, logged] → first unlogged is set_1.
      final ex = _ex(n: 3, loggedIndices: [0, 2]);
      expect(ex.firstUnloggedSet?.id, 'set_1');
    });

    test('null when every effective set is logged', () {
      expect(_ex(n: 2, loggedIndices: [0, 1]).firstUnloggedSet, isNull);
    });

    test('first set when nothing is logged', () {
      expect(_ex(n: 3).firstUnloggedSet?.id, 'set_0');
    });
  });

  group('currentTarget / isCurrentTargetWarmup', () {
    test('warmup pending: target is the warmup', () {
      final w = _warmup(logged: false);
      final ex = _ex(n: 2, warmup: w, loggedIndices: [0]);
      expect(ex.currentTarget?.id, w.id);
      expect(ex.isCurrentTargetWarmup, isTrue);
    });

    test('warmup logged: target is the first unlogged effective set', () {
      final w = _warmup(logged: true);
      final ex = _ex(n: 3, warmup: w, loggedIndices: [0]);
      expect(ex.currentTarget?.id, 'set_1');
      expect(ex.isCurrentTargetWarmup, isFalse);
    });

    test('no warmup, all effective logged: target is null', () {
      expect(_ex(n: 2, loggedIndices: [0, 1]).currentTarget, isNull);
    });

    test('no warmup, fresh exercise: target is set_0', () {
      expect(_ex(n: 2).currentTarget?.id, 'set_0');
      expect(_ex(n: 2).isCurrentTargetWarmup, isFalse);
    });
  });

  group('isOnFinalEffectiveSet', () {
    test('true when exactly one effective set remains unlogged (no warmup)',
        () {
      expect(_ex(n: 3, loggedIndices: [0, 1]).isOnFinalEffectiveSet, isTrue);
    });

    test('false when two or more remain unlogged', () {
      expect(_ex(n: 3, loggedIndices: [0]).isOnFinalEffectiveSet, isFalse);
    });

    test('false when none remain unlogged (everything done)', () {
      expect(
        _ex(n: 2, loggedIndices: [0, 1]).isOnFinalEffectiveSet,
        isFalse,
      );
    });

    test('warmup pending blocks isOnFinalEffectiveSet even if 1 set remains',
        () {
      // Without the warmup guard, the Log-Set button would say "Done!" while
      // the warmup row is still the actual target — a UX regression.
      final ex = _ex(
        n: 2,
        loggedIndices: [0],
        warmup: _warmup(logged: false),
      );
      expect(ex.isOnFinalEffectiveSet, isFalse);
    });

    test('logged warmup does not block isOnFinalEffectiveSet', () {
      final ex = _ex(
        n: 2,
        loggedIndices: [0],
        warmup: _warmup(logged: true),
      );
      expect(ex.isOnFinalEffectiveSet, isTrue);
    });
  });

  group('isAwaitingDoneConfirmation', () {
    test('true when every effective set is logged and not yet completed', () {
      expect(
        _ex(n: 3, loggedIndices: [0, 1, 2]).isAwaitingDoneConfirmation,
        isTrue,
      );
    });

    test('false when at least one effective set is still unlogged', () {
      expect(
        _ex(n: 3, loggedIndices: [0, 1]).isAwaitingDoneConfirmation,
        isFalse,
      );
    });

    test('false once the exercise is marked completed', () {
      expect(
        _ex(n: 2, loggedIndices: [0, 1], completed: true)
            .isAwaitingDoneConfirmation,
        isFalse,
      );
    });

    test('pending warmup blocks the awaiting-Done state', () {
      // Otherwise the bottom button would flip to "Done" while the warmup
      // row is still unsatisfied — same UX regression isOnFinalEffectiveSet
      // already guards against.
      final ex = _ex(
        n: 2,
        loggedIndices: [0, 1],
        warmup: _warmup(logged: false),
      );
      expect(ex.isAwaitingDoneConfirmation, isFalse);
    });

    test('logged warmup permits the awaiting-Done state', () {
      final ex = _ex(
        n: 2,
        loggedIndices: [0, 1],
        warmup: _warmup(logged: true),
      );
      expect(ex.isAwaitingDoneConfirmation, isTrue);
    });

    test('empty effective sets cannot be in awaiting-Done state', () {
      // isAllSetsLogged is false on empty lists, so this should propagate.
      expect(_ex(n: 0).isAwaitingDoneConfirmation, isFalse);
    });
  });
}
