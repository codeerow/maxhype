import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/muscle_group.dart';
import 'package:maxhype/models/session/session_exercise.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/models/session/session_warmup_type.dart';
import 'package:maxhype/models/session/workout_session.dart';

/// Round-trip helper: encode → decode through real JSON to ensure the
/// payload is actually JSON-serialisable (catches non-primitive leaks
/// like enum instances slipping through `toJson`).
T _roundTrip<T>(Map<String, dynamic> json, T Function(Map<String, dynamic>) from) {
  final raw = jsonEncode(json);
  final decoded = jsonDecode(raw) as Map<String, dynamic>;
  return from(decoded);
}

void main() {
  group('SessionSet', () {
    test('full roundtrip preserves every field', () {
      final original = SessionSet(
        id: 'set_1',
        weight: 102.5,
        reps: 7,
        loggedAt: DateTime.utc(2025, 3, 14, 15, 9, 26),
      );
      final restored = _roundTrip(original.toJson(), SessionSet.fromJson);

      expect(restored.id, original.id);
      expect(restored.weight, original.weight);
      expect(restored.reps, original.reps);
      expect(restored.loggedAt, original.loggedAt);
      expect(restored.isLogged, isTrue);
      expect(restored.isFilled, isTrue);
    });

    test('empty draft set roundtrips with all nullable fields null', () {
      const original = SessionSet(id: 'set_draft');
      final restored = _roundTrip(original.toJson(), SessionSet.fromJson);

      expect(restored.id, 'set_draft');
      expect(restored.weight, isNull);
      expect(restored.reps, isNull);
      expect(restored.loggedAt, isNull);
      expect(restored.isLogged, isFalse);
      expect(restored.isFilled, isFalse);
    });

    test('integer weight encoded as num decodes back to double', () {
      // Hand-craft the wire shape — older sessions may have whole-number
      // weights serialised as ints. fromJson casts via `num?.toDouble()`,
      // so this must still work.
      final raw = {
        'id': 'set_1',
        'weight': 100, // int, not double
        'reps': 5,
        'loggedAt': null,
      };
      final restored = SessionSet.fromJson(raw);
      expect(restored.weight, 100.0);
      expect(restored.weight, isA<double>());
    });
  });

  group('SessionExercise', () {
    test('full roundtrip preserves every field including warmup & muscleGroups',
        () {
      final original = SessionExercise(
        exerciseId: 'ex_bench',
        name: 'Barbell Bench Press',
        equipment: EquipmentType.barbell,
        muscleGroups: const [MuscleGroup.chest, MuscleGroup.shoulders],
        targetSets: 3,
        sets: const [
          SessionSet(id: 's1', weight: 100, reps: 5),
          SessionSet(id: 's2', weight: 105, reps: 4),
        ],
        warmupSet: const SessionSet(id: 'w1', weight: 60, reps: 10),
        notes: 'felt good',
        completed: true,
      );
      final restored =
          _roundTrip(original.toJson(), SessionExercise.fromJson);

      expect(restored.exerciseId, original.exerciseId);
      expect(restored.name, original.name);
      expect(restored.equipment, original.equipment);
      expect(restored.muscleGroups, original.muscleGroups);
      expect(restored.targetSets, original.targetSets);
      expect(restored.sets.map((s) => s.id), ['s1', 's2']);
      expect(restored.warmupSet?.id, 'w1');
      expect(restored.notes, 'felt good');
      expect(restored.completed, isTrue);
    });

    test('null warmupSet stays null after roundtrip', () {
      final original = SessionExercise(
        exerciseId: 'ex1',
        name: 'Squat',
        equipment: EquipmentType.barbell,
        targetSets: 1,
        sets: const [SessionSet(id: 's1')],
        warmupSet: null,
      );
      final restored =
          _roundTrip(original.toJson(), SessionExercise.fromJson);

      expect(restored.warmupSet, isNull);
    });

    test('defaults are applied when optional fields missing from wire', () {
      // Older payloads may not carry `muscleGroups`, `notes`, `completed`,
      // or `warmupSet`. The decoder must fill them with sensible defaults.
      final raw = {
        'exerciseId': 'ex_legacy',
        'name': 'Old Lift',
        'equipment': 'barbell',
        // muscleGroups omitted
        'targetSets': 2,
        'sets': [
          {'id': 's1', 'weight': null, 'reps': null, 'loggedAt': null},
          {'id': 's2', 'weight': null, 'reps': null, 'loggedAt': null},
        ],
        // warmupSet, notes, completed omitted
      };
      final restored = SessionExercise.fromJson(raw);

      expect(restored.muscleGroups, isEmpty);
      expect(restored.notes, '');
      expect(restored.completed, isFalse);
      expect(restored.warmupSet, isNull);
    });

    test('unknown equipment value falls back to bodyweight', () {
      final raw = {
        'exerciseId': 'ex1',
        'name': 'Mystery Lift',
        'equipment': 'antigravityDevice', // not a real EquipmentType
        'targetSets': 1,
        'sets': [
          {'id': 's1', 'weight': null, 'reps': null, 'loggedAt': null},
        ],
      };
      final restored = SessionExercise.fromJson(raw);
      expect(restored.equipment, EquipmentType.bodyweight);
    });

    test('unknown muscle-group value falls back to chest', () {
      final raw = {
        'exerciseId': 'ex1',
        'name': 'Lift',
        'equipment': 'barbell',
        'muscleGroups': ['chest', 'phantomLimb'],
        'targetSets': 1,
        'sets': [
          {'id': 's1', 'weight': null, 'reps': null, 'loggedAt': null},
        ],
      };
      final restored = SessionExercise.fromJson(raw);
      // 'phantomLimb' falls back to chest, so list ends up [chest, chest].
      expect(restored.muscleGroups.length, 2);
      expect(restored.muscleGroups.every((m) => m == MuscleGroup.chest), isTrue);
    });
  });

  group('WorkoutSession', () {
    WorkoutSession sampleSession() => WorkoutSession(
          id: 'session_1',
          workoutId: 'workout_1',
          workoutName: 'Push Day',
          startedAt: DateTime.utc(2025, 1, 1, 10),
          finishedAt: DateTime.utc(2025, 1, 1, 11, 15),
          activeExerciseId: 'ex_bench',
          activeRestEndsAt: DateTime.utc(2025, 1, 1, 10, 32),
          restDurationSeconds: 90,
          warmup: WarmupType.stationaryBike,
          status: SessionStatus.finished,
          exercises: [
            SessionExercise(
              exerciseId: 'ex_bench',
              name: 'Bench',
              equipment: EquipmentType.barbell,
              targetSets: 2,
              sets: const [
                SessionSet(id: 's1', weight: 100, reps: 5),
                SessionSet(id: 's2', weight: 105, reps: 4),
              ],
            ),
          ],
        );

    test('full roundtrip preserves every field', () {
      final original = sampleSession();
      final restored =
          _roundTrip(original.toJson(), WorkoutSession.fromJson);

      expect(restored.id, original.id);
      expect(restored.workoutId, original.workoutId);
      expect(restored.workoutName, original.workoutName);
      expect(restored.startedAt, original.startedAt);
      expect(restored.finishedAt, original.finishedAt);
      expect(restored.activeExerciseId, original.activeExerciseId);
      expect(restored.activeRestEndsAt, original.activeRestEndsAt);
      expect(restored.restDurationSeconds, original.restDurationSeconds);
      expect(restored.warmup, original.warmup);
      expect(restored.status, original.status);
      expect(restored.exercises.length, 1);
      expect(restored.exercises.single.sets.map((s) => s.id), ['s1', 's2']);
    });

    test('minimal active session roundtrips with nullable fields null', () {
      final original = WorkoutSession(
        id: 'session_min',
        workoutId: 'w1',
        workoutName: 'Min',
        startedAt: DateTime.utc(2025, 1, 1, 10),
        exercises: const [],
      );
      final restored =
          _roundTrip(original.toJson(), WorkoutSession.fromJson);

      expect(restored.activeExerciseId, isNull);
      expect(restored.activeRestEndsAt, isNull);
      expect(restored.finishedAt, isNull);
      expect(restored.status, SessionStatus.active);
      expect(restored.warmup, WarmupType.none);
      expect(restored.restDurationSeconds, 120); // default
      expect(restored.exercises, isEmpty);
    });

    test('legacy payload (missing restDurationSeconds, warmup, status)', () {
      // Older clients didn't write these fields. Decoder must apply
      // defaults rather than throw.
      final raw = {
        'id': 'legacy_1',
        'workoutId': 'w1',
        'workoutName': 'Legacy',
        'startedAt': DateTime.utc(2025, 1, 1, 10).toIso8601String(),
        'exercises': <Map<String, dynamic>>[],
        'activeExerciseId': null,
        'activeRestEndsAt': null,
        // restDurationSeconds, warmup, status, finishedAt omitted
      };
      final restored = WorkoutSession.fromJson(raw);

      expect(restored.restDurationSeconds, 120);
      expect(restored.warmup, WarmupType.none);
      expect(restored.status, SessionStatus.active);
      expect(restored.finishedAt, isNull);
    });

    test('toJson output is JSON-serialisable (no enum or DateTime leaks)',
        () {
      final raw = sampleSession().toJson();
      // jsonEncode throws if it hits a non-primitive — that's the assertion.
      expect(() => jsonEncode(raw), returnsNormally);
    });

    test('UTC and local DateTime survive roundtrip via ISO-8601', () {
      // We don't claim wall-time-zone preservation, only instant-equality.
      final localStart = DateTime(2025, 6, 15, 14, 30);
      final original = WorkoutSession(
        id: 's1',
        workoutId: 'w1',
        workoutName: 'tz',
        startedAt: localStart,
        exercises: const [],
      );
      final restored =
          _roundTrip(original.toJson(), WorkoutSession.fromJson);
      // isAtSameMomentAs compares instants regardless of zone tag.
      expect(restored.startedAt.isAtSameMomentAs(localStart), isTrue);
    });
  });

  group('SessionStatus', () {
    test('every enum value roundtrips through key', () {
      for (final status in SessionStatus.values) {
        expect(SessionStatusKey.fromKey(status.key), status,
            reason: 'roundtrip failed for $status');
      }
    });

    test('unknown / null key defaults to active', () {
      expect(SessionStatusKey.fromKey(null), SessionStatus.active);
      expect(SessionStatusKey.fromKey('something_else'), SessionStatus.active);
    });
  });

  group('WarmupType', () {
    test('every enum value roundtrips through storageKey', () {
      for (final w in WarmupType.values) {
        expect(WarmupTypeExtension.fromKey(w.storageKey), w,
            reason: 'roundtrip failed for $w');
      }
    });

    test('unknown / null key defaults to none', () {
      expect(WarmupTypeExtension.fromKey(null), WarmupType.none);
      expect(
        WarmupTypeExtension.fromKey('unrecognised'),
        WarmupType.none,
      );
    });

    test('storageKey values are distinct (no aliasing collisions)', () {
      final keys = WarmupType.values.map((w) => w.storageKey).toSet();
      expect(keys.length, WarmupType.values.length);
    });
  });
}
