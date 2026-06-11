import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/session/session_exercise.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/models/session/workout_session.dart';
import 'package:maxhype/repositories/local_personal_record_repository.dart';

/// Build a finished WorkoutSession with one exercise and the supplied
/// list of (weight, reps) sets. All sets get `loggedAt = startedAt + i*1m`
/// so the achievement timestamp is deterministic per index.
WorkoutSession _session({
  required String id,
  required String exerciseId,
  required List<(double weight, int reps)> sets,
  DateTime? startedAt,
}) {
  final start = startedAt ?? DateTime(2025, 1, 1, 10);
  return WorkoutSession(
    id: id,
    workoutId: 'w1',
    workoutName: 'Test',
    startedAt: start,
    finishedAt: start.add(const Duration(hours: 1)),
    status: SessionStatus.finished,
    exercises: [
      SessionExercise(
        slotId: exerciseId,
        exerciseId: exerciseId,
        name: 'Bench',
        equipment: EquipmentType.barbell,
        targetSets: sets.length,
        sets: [
          for (var i = 0; i < sets.length; i++)
            SessionSet(
              id: 'set_${id}_$i',
              weight: sets[i].$1,
              reps: sets[i].$2,
              loggedAt: start.add(Duration(minutes: i + 1)),
            ),
        ],
      ),
    ],
  );
}

void main() {
  late Directory tmp;
  late File historyFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mh_pr_repo_test_');
    historyFile = File('${tmp.path}/workout_history.jsonl');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  LocalPersonalRecordRepository newRepo() {
    return LocalPersonalRecordRepository(
      directoryResolver: () async => tmp,
    );
  }

  void writeSessions(List<WorkoutSession> sessions) {
    final buf = StringBuffer();
    for (final s in sessions) {
      buf.writeln(jsonEncode(s.toJson()));
    }
    historyFile.writeAsStringSync(buf.toString());
  }

  group('bestFor — empty / missing source', () {
    test('returns null when history file does not exist', () async {
      final repo = newRepo();
      expect(await repo.bestFor('ex1'), isNull);
    });

    test('returns null for an empty history file', () async {
      historyFile.writeAsStringSync('');
      final repo = newRepo();
      expect(await repo.bestFor('ex1'), isNull);
    });

    test('returns null for an exercise not present in history', () async {
      writeSessions([
        _session(
          id: 's1',
          exerciseId: 'ex1',
          sets: [(100, 5)],
        ),
      ]);
      final repo = newRepo();
      expect(await repo.bestFor('ex_unknown'), isNull);
    });
  });

  group('bestFor — selection rules', () {
    test('picks the heaviest weight across sessions', () async {
      writeSessions([
        _session(id: 's1', exerciseId: 'ex1', sets: [(100, 5)]),
        _session(id: 's2', exerciseId: 'ex1', sets: [(120, 3)]),
        _session(id: 's3', exerciseId: 'ex1', sets: [(110, 8)]),
      ]);
      final repo = newRepo();
      final pr = await repo.bestFor('ex1');
      expect(pr, isNotNull);
      expect(pr!.weight, 120);
      expect(pr.reps, 3);
    });

    test('same weight: more reps wins (PR.isBeatenBy tie-break)', () async {
      writeSessions([
        _session(id: 's1', exerciseId: 'ex1', sets: [(100, 5)]),
        _session(id: 's2', exerciseId: 'ex1', sets: [(100, 7)]),
        _session(id: 's3', exerciseId: 'ex1', sets: [(100, 4)]),
      ]);
      final repo = newRepo();
      final pr = await repo.bestFor('ex1');
      expect(pr!.weight, 100);
      expect(pr.reps, 7);
    });

    test('multiple sets in one session: best set wins', () async {
      writeSessions([
        _session(
          id: 's1',
          exerciseId: 'ex1',
          sets: [(80, 10), (100, 5), (90, 8)],
        ),
      ]);
      final repo = newRepo();
      final pr = await repo.bestFor('ex1');
      expect(pr!.weight, 100);
      expect(pr.reps, 5);
    });

    test('PRs are tracked independently per exercise', () async {
      writeSessions([
        _session(id: 's1', exerciseId: 'ex_bench', sets: [(100, 5)]),
        _session(id: 's2', exerciseId: 'ex_squat', sets: [(180, 3)]),
      ]);
      final repo = newRepo();
      expect((await repo.bestFor('ex_bench'))!.weight, 100);
      expect((await repo.bestFor('ex_squat'))!.weight, 180);
    });

    test('sets with null weight or reps are ignored', () async {
      // Hand-craft JSONL — toJson would emit nulls anyway, but we want
      // to exercise the loader's null filter explicitly.
      final start = DateTime(2025, 1, 1, 10);
      final raw = {
        'id': 's1',
        'workoutId': 'w1',
        'workoutName': 'T',
        'startedAt': start.toIso8601String(),
        'exercises': [
          {
            'exerciseId': 'ex1',
            'name': 'Bench',
            'equipment': 'barbell',
            'muscleGroups': <String>[],
            'targetSets': 2,
            'sets': [
              {
                'id': 'sa',
                'weight': null,
                'reps': 5,
                'loggedAt': start.toIso8601String(),
              },
              {
                'id': 'sb',
                'weight': 90,
                'reps': 6,
                'loggedAt':
                    start.add(const Duration(minutes: 1)).toIso8601String(),
              },
            ],
            'warmupSet': null,
            'notes': '',
            'completed': true,
          }
        ],
        'activeExerciseId': null,
        'activeRestEndsAt': null,
        'restDurationSeconds': 120,
        'warmup': 'none',
        'status': 'finished',
        'finishedAt':
            start.add(const Duration(hours: 1)).toIso8601String(),
      };
      historyFile.writeAsStringSync('${jsonEncode(raw)}\n');

      final repo = newRepo();
      final pr = await repo.bestFor('ex1');
      expect(pr, isNotNull);
      expect(pr!.weight, 90);
      expect(pr.reps, 6);
    });

    test('achievedAt comes from set.loggedAt', () async {
      final start = DateTime(2025, 3, 15, 9);
      writeSessions([
        _session(
          id: 's1',
          exerciseId: 'ex1',
          sets: [(100, 5)],
          startedAt: start,
        ),
      ]);
      final repo = newRepo();
      final pr = await repo.bestFor('ex1');
      // _session sets loggedAt = startedAt + (index+1)*1m → first set is +1m.
      expect(pr!.achievedAt, start.add(const Duration(minutes: 1)));
    });
  });

  group('bestFor — corrupt input', () {
    test('skips corrupt JSON lines and keeps reading valid ones', () async {
      final start = DateTime(2025, 1, 1, 10);
      final good = _session(
        id: 's1',
        exerciseId: 'ex1',
        sets: [(150, 5)],
        startedAt: start,
      );
      historyFile.writeAsStringSync(
        [
          '{not valid json at all',
          jsonEncode(good.toJson()),
          '}}}',
          '',
        ].join('\n'),
      );

      final repo = newRepo();
      final pr = await repo.bestFor('ex1');
      expect(pr, isNotNull);
      expect(pr!.weight, 150);
    });
  });

  group('cache & invalidate', () {
    test('second call reads from cache (file deletion is invisible)',
        () async {
      writeSessions([
        _session(id: 's1', exerciseId: 'ex1', sets: [(100, 5)]),
      ]);
      final repo = newRepo();

      final first = await repo.bestFor('ex1');
      expect(first!.weight, 100);

      // Delete the file out from under the repo; cache should keep
      // returning the previously loaded value.
      historyFile.deleteSync();
      final second = await repo.bestFor('ex1');
      expect(second!.weight, 100);
    });

    test('invalidate() forces a re-scan that picks up new sessions',
        () async {
      writeSessions([
        _session(id: 's1', exerciseId: 'ex1', sets: [(100, 5)]),
      ]);
      final repo = newRepo();

      expect((await repo.bestFor('ex1'))!.weight, 100);

      // Append a heavier session and invalidate.
      historyFile.writeAsStringSync(
        '${jsonEncode(_session(id: 's2', exerciseId: 'ex1', sets: [(130, 3)]).toJson())}\n',
        mode: FileMode.append,
      );
      repo.invalidate();

      expect((await repo.bestFor('ex1'))!.weight, 130);
    });

    test('concurrent first calls share a single inflight scan', () async {
      writeSessions([
        _session(id: 's1', exerciseId: 'ex1', sets: [(100, 5)]),
      ]);
      final repo = newRepo();

      // Fire two reads before either resolves. Both must complete and
      // return the same value — the inflight de-dup guards against a
      // double scan, but we can at least assert correctness here.
      final results = await Future.wait([
        repo.bestFor('ex1'),
        repo.bestFor('ex1'),
      ]);
      expect(results[0]!.weight, 100);
      expect(results[1]!.weight, 100);
    });
  });
}
