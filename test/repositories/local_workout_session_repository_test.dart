import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/session/session_exercise.dart';
import 'package:maxhype/models/session/session_set.dart';
import 'package:maxhype/models/session/workout_session.dart';
import 'package:maxhype/repositories/local_workout_session_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

WorkoutSession _makeSession({
  String id = 's1',
  SessionStatus status = SessionStatus.active,
  List<SessionExercise>? exercises,
  DateTime? startedAt,
  DateTime? finishedAt,
}) {
  return WorkoutSession(
    id: id,
    workoutId: 'w1',
    workoutName: 'Test',
    startedAt: startedAt ?? DateTime(2025, 1, 1, 10),
    finishedAt: finishedAt,
    status: status,
    exercises: exercises ??
        [
          SessionExercise(
            slotId: 'ex1',
            exerciseId: 'ex1',
            name: 'Bench',
            equipment: EquipmentType.barbell,
            targetSets: 1,
            sets: [
              SessionSet(
                id: 'set_a',
                weight: 100,
                reps: 5,
                loggedAt: DateTime(2025, 1, 1, 10, 5),
              ),
            ],
          ),
        ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mh_session_repo_test_');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  LocalWorkoutSessionRepository newRepo({void Function()? onArchive}) {
    return LocalWorkoutSessionRepository(
      onArchive: onArchive,
      directoryResolver: () async => tmp,
    );
  }

  File activeFile() => File('${tmp.path}/workout_session_active.json');
  File historyFile() => File('${tmp.path}/workout_history.jsonl');

  group('save / loadActive round-trip', () {
    test('save then loadActive returns the same session', () async {
      final repo = newRepo();
      final session = _makeSession();

      await repo.save(session);
      final loaded = await repo.loadActive();

      expect(loaded, isNotNull);
      expect(loaded!.id, session.id);
      expect(loaded.workoutId, session.workoutId);
      expect(loaded.exercises.single.exerciseId, 'ex1');
      expect(loaded.exercises.single.sets.single.weight, 100);
    });

    test('save sets the has_active flag', () async {
      final repo = newRepo();
      await repo.save(_makeSession());

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('workout_session.has_active'), isTrue);
    });

    test('save writes via temp + rename (no leftover .tmp on success)',
        () async {
      final repo = newRepo();
      await repo.save(_makeSession());

      expect(activeFile().existsSync(), isTrue);
      expect(File('${activeFile().path}.tmp').existsSync(), isFalse);
    });
  });

  group('loadActive — guards', () {
    test('returns null when has_active flag is false (default)', () async {
      // Even if the file exists, the flag governs visibility.
      activeFile().writeAsStringSync(jsonEncode(_makeSession().toJson()));
      final repo = newRepo();
      expect(await repo.loadActive(), isNull);
    });

    test('returns null when flag is true but file is missing', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('workout_session.has_active', true);
      final repo = newRepo();
      expect(await repo.loadActive(), isNull);
    });

    test('returns null when flag is true but file is empty', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('workout_session.has_active', true);
      activeFile().writeAsStringSync('');
      final repo = newRepo();
      expect(await repo.loadActive(), isNull);
    });

    test('returns null when status is not active', () async {
      final repo = newRepo();
      // Save a finished session through the same path (bypassing the
      // status-only guard in loadActive).
      await repo.save(
        _makeSession(status: SessionStatus.finished),
      );
      expect(await repo.loadActive(), isNull);
    });

    test('corrupt JSON: returns null and clears active (no crash)',
        () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('workout_session.has_active', true);
      activeFile().writeAsStringSync('{not json');

      final repo = newRepo();
      expect(await repo.loadActive(), isNull);
      // clearActive() was called — flag flipped, file gone.
      expect(prefs.getBool('workout_session.has_active'), isFalse);
      expect(activeFile().existsSync(), isFalse);
    });
  });

  group('clearActive', () {
    test('clears the flag and deletes the file', () async {
      final repo = newRepo();
      await repo.save(_makeSession());
      expect(activeFile().existsSync(), isTrue);

      await repo.clearActive();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('workout_session.has_active'), isFalse);
      expect(activeFile().existsSync(), isFalse);
    });

    test('is a no-op when nothing was saved', () async {
      final repo = newRepo();
      await repo.clearActive(); // must not throw

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('workout_session.has_active'), isFalse);
    });
  });

  group('archiveFinished', () {
    test('appends one JSONL line and fires onArchive', () async {
      var callbacks = 0;
      final repo = newRepo(onArchive: () => callbacks++);

      final finished = _makeSession(
        status: SessionStatus.finished,
        finishedAt: DateTime(2025, 1, 1, 11),
      );
      await repo.archiveFinished(finished);

      final raw = historyFile().readAsStringSync();
      final lines =
          raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
      expect(lines.length, 1);
      final decoded = jsonDecode(lines.single) as Map<String, dynamic>;
      expect(decoded['id'], finished.id);
      expect(decoded['status'], 'finished');
      expect(callbacks, 1);
    });

    test('multiple archives append (history grows, never overwrites)',
        () async {
      final repo = newRepo();
      await repo.archiveFinished(
        _makeSession(id: 's1', status: SessionStatus.finished),
      );
      await repo.archiveFinished(
        _makeSession(id: 's2', status: SessionStatus.finished),
      );

      final lines = historyFile()
          .readAsStringSync()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 2);
      expect((jsonDecode(lines[0]) as Map)['id'], 's1');
      expect((jsonDecode(lines[1]) as Map)['id'], 's2');
    });
  });

  group('lastLogFor', () {
    SessionExercise makeEx(
      String exerciseId,
      List<(double w, int r, DateTime at)> sets, {
      SessionSet? warmup,
    }) {
      return SessionExercise(
        slotId: exerciseId,
        exerciseId: exerciseId,
        name: 'Ex',
        equipment: EquipmentType.barbell,
        targetSets: sets.length,
        warmups: warmup == null ? const [] : [warmup],
        sets: [
          for (var i = 0; i < sets.length; i++)
            SessionSet(
              id: '${exerciseId}_$i',
              weight: sets[i].$1,
              reps: sets[i].$2,
              loggedAt: sets[i].$3,
            ),
        ],
      );
    }

    test('returns null when history file does not exist', () async {
      final repo = newRepo();
      expect(await repo.lastLogFor('ex1'), isNull);
    });

    test('returns null when history is empty', () async {
      historyFile().writeAsStringSync('');
      final repo = newRepo();
      expect(await repo.lastLogFor('ex1'), isNull);
    });

    test('returns null when exercise is not in any session', () async {
      final repo = newRepo();
      await repo.archiveFinished(_makeSession(id: 's1'));
      expect(await repo.lastLogFor('ex_unknown'), isNull);
    });

    test('returns the last logged effective set of the newest session',
        () async {
      final repo = newRepo();
      // Older session — bigger weight, but should NOT win (newer trumps).
      await repo.archiveFinished(_makeSession(
        id: 's_old',
        status: SessionStatus.finished,
        exercises: [
          makeEx('ex1', [
            (200, 5, DateTime(2025, 1, 1, 10, 5)),
          ]),
        ],
      ));
      // Newer session — last logged set is the (100, 6) one.
      await repo.archiveFinished(_makeSession(
        id: 's_new',
        status: SessionStatus.finished,
        exercises: [
          makeEx('ex1', [
            (80, 5, DateTime(2025, 1, 2, 10, 0)),
            (100, 6, DateTime(2025, 1, 2, 10, 5)),
          ]),
        ],
      ));

      final last = await repo.lastLogFor('ex1');
      expect(last, isNotNull);
      expect(last!.weight, 100);
      expect(last.reps, 6);
    });

    test('falls back to the last logged warmup when no effective sets are logged',
        () async {
      final repo = newRepo();
      await repo.archiveFinished(_makeSession(
        id: 's1',
        status: SessionStatus.finished,
        exercises: [
          makeEx(
            'ex1',
            const [], // no effective sets at all
            warmup: SessionSet(
              id: 'w1',
              kind: SetKind.warmup,
              weight: 40,
              reps: 10,
              loggedAt: DateTime(2025, 1, 1, 10, 0),
            ),
          ),
        ],
      ));

      final last = await repo.lastLogFor('ex1');
      expect(last, isNotNull);
      expect(last!.weight, 40);
      expect(last.reps, 10);
    });

    test('skips corrupt JSONL lines', () async {
      final repo = newRepo();
      // Manually craft a file with one bad and one good line.
      final good = _makeSession(
        id: 'g1',
        status: SessionStatus.finished,
        exercises: [
          makeEx('ex1', [(125, 4, DateTime(2025, 1, 1, 10, 0))]),
        ],
      );
      historyFile().writeAsStringSync(
        '{bad json\n${jsonEncode(good.toJson())}\n',
      );

      final last = await repo.lastLogFor('ex1');
      expect(last, isNotNull);
      expect(last!.weight, 125);
    });
  });

  group('write serialization (_writeLock)', () {
    test('concurrent saves do not throw (regression for PathNotFound race)',
        () async {
      final repo = newRepo();

      // Fire 10 saves without awaiting between them. Before the
      // write-lock was added, two simultaneous `.tmp → rename` dances
      // could race and the second rename threw PathNotFoundException.
      final futures = <Future<void>>[];
      for (var i = 0; i < 10; i++) {
        futures.add(repo.save(
          _makeSession(id: 's_$i'),
        ));
      }
      await Future.wait(futures);

      // The last write wins — the file must exist and parse cleanly.
      expect(activeFile().existsSync(), isTrue);
      final loaded = await repo.loadActive();
      expect(loaded, isNotNull);
      expect(loaded!.id, startsWith('s_'));
    });

    test('save + clearActive interleaved are serialized', () async {
      final repo = newRepo();

      // Issue a save, then immediately a clear, without awaiting save.
      // Both must serialize via the write-lock and leave a consistent
      // state (cleared).
      final s = repo.save(_makeSession());
      final c = repo.clearActive();
      await Future.wait([s, c]);

      expect(activeFile().existsSync(), isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('workout_session.has_active'), isFalse);
    });

    test('archiveFinished serializes with save (no torn writes)', () async {
      final repo = newRepo();

      final futures = <Future<void>>[];
      futures.add(repo.save(_makeSession(id: 'active_1')));
      futures.add(repo.archiveFinished(
        _makeSession(id: 'fin_1', status: SessionStatus.finished),
      ));
      futures.add(repo.save(_makeSession(id: 'active_2')));
      futures.add(repo.archiveFinished(
        _makeSession(id: 'fin_2', status: SessionStatus.finished),
      ));
      await Future.wait(futures);

      // History has both finished entries, in archive-call order.
      final lines = historyFile()
          .readAsStringSync()
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
      expect(lines.length, 2);
      final ids = lines
          .map((l) => (jsonDecode(l) as Map<String, dynamic>)['id'])
          .toList();
      expect(ids, containsAll(['fin_1', 'fin_2']));

      // Active file parses cleanly — no half-written state.
      final loaded = await repo.loadActive();
      expect(loaded, isNotNull);
    });
  });
}
