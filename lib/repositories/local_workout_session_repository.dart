import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session/session_set.dart';
import '../models/session/workout_session.dart';
import 'workout_session_repository.dart';

class LocalWorkoutSessionRepository implements WorkoutSessionRepository {
  /// Optional callback fired after a finished session has been appended to
  /// `workout_history.jsonl`. The PR repository wires this to invalidate
  /// its in-memory cache, so the freshly-archived session is taken into
  /// account next time `bestFor()` is called.
  final void Function()? onArchive;

  /// Override for the directory that holds the active-session file and
  /// `workout_history.jsonl`. Production wiring leaves this null and
  /// falls back to `getApplicationDocumentsDirectory`. Tests pass a temp
  /// dir so the repository can be exercised against a real filesystem
  /// without mocking the path_provider MethodChannel.
  final Future<Directory> Function()? _directoryResolver;

  LocalWorkoutSessionRepository({
    this.onArchive,
    Future<Directory> Function()? directoryResolver,
  }) : _directoryResolver = directoryResolver;

  static const _activeFlagKey = 'workout_session.has_active';
  static const _activeFileName = 'workout_session_active.json';
  static const _historyFileName = 'workout_history.jsonl';

  /// Serializes filesystem mutations (`save`, `clearActive`,
  /// `archiveFinished`) so concurrent callers don't race on the
  /// write-temp-then-rename dance — without this, two `save` calls in
  /// flight clobber each other's `.tmp` and the second rename throws
  /// `PathNotFoundException`. New writes are chained behind whatever the
  /// previous write is doing.
  Future<void> _writeLock = Future.value();

  Future<T> _enqueueWrite<T>(Future<T> Function() task) {
    final completer = Completer<T>();
    _writeLock = _writeLock.then((_) async {
      try {
        completer.complete(await task());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  Future<Directory> _dir() async =>
      _directoryResolver?.call() ?? getApplicationDocumentsDirectory();

  Future<File> _activeFile() async {
    final dir = await _dir();
    return File('${dir.path}/$_activeFileName');
  }

  Future<File> _historyFile() async {
    final dir = await _dir();
    return File('${dir.path}/$_historyFileName');
  }

  @override
  Future<WorkoutSession?> loadActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_activeFlagKey) ?? false)) return null;

      final file = await _activeFile();
      if (!file.existsSync()) return null;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = WorkoutSession.fromJson(json);
      if (session.status != SessionStatus.active) return null;
      return session;
    } on Object {
      // Corrupt store (FileSystemException, FormatException, json shape
      // mismatch) — clear silently rather than crash on launch.
      await clearActive();
      return null;
    }
  }

  @override
  Future<void> save(WorkoutSession session) => _enqueueWrite(() async {
        final file = await _activeFile();
        // Ensure the Documents directory exists — first launch on a freshly
        // wiped simulator can land here before the OS has materialized it.
        await file.parent.create(recursive: true);
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(session.toJson()), flush: true);
        await tmp.rename(file.path);

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_activeFlagKey, true);
      });

  @override
  Future<void> clearActive() => _enqueueWrite(() async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_activeFlagKey, false);

        final file = await _activeFile();
        if (file.existsSync()) {
          try {
            await file.delete();
          } on FileSystemException {
            // Best-effort cleanup; tolerate platform-level delete failures.
          }
        }
      });

  @override
  Future<void> archiveFinished(WorkoutSession session) => _enqueueWrite(() async {
        final file = await _historyFile();
        final line = '${jsonEncode(session.toJson())}\n';
        await file.writeAsString(line, mode: FileMode.append, flush: true);
        onArchive?.call();
      });

  @override
  Future<SessionSet?> lastLogFor(String exerciseId) async {
    final file = await _historyFile();
    if (!file.existsSync()) return null;

    // History is append-only JSONL; iterate from newest entry by reading the
    // whole file and walking backwards. For Part 1 (low session count) this
    // is fine; if history grows large we can switch to a tail-read or an
    // index file later.
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return null;
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty).toList();
    for (var i = lines.length - 1; i >= 0; i--) {
      try {
        final session = WorkoutSession.fromJson(
          jsonDecode(lines[i]) as Map<String, dynamic>,
        );
        for (final ex in session.exercises) {
          if (ex.exerciseId != exerciseId) continue;
          // Walk this exercise's sets from the last logged one.
          for (var j = ex.sets.length - 1; j >= 0; j--) {
            final s = ex.sets[j];
            if (s.isLogged) return s;
          }
          // Fall back to the most recent logged warmup (used to pre-fill
          // weight/reps when the user starts a new session and hasn't yet
          // logged a working set for this exercise).
          for (var j = ex.warmups.length - 1; j >= 0; j--) {
            final w = ex.warmups[j];
            if (w.isLogged) return w;
          }
        }
      } on FormatException {
        continue; // skip corrupt JSON line
      }
    }
    return null;
  }
}
