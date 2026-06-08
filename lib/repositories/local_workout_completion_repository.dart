import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/workout_completion.dart';
import 'workout_completion_repository.dart';

/// Local filesystem implementation of [WorkoutCompletionRepository].
///
/// Storage: `workout_completion.json` in the app documents directory.
/// Shape: a single JSON object `{ workoutId: WorkoutCompletionJson, ...}`.
///
/// Writes are serialised through a write-lock and use the
/// write-temp-then-rename dance so a crash mid-write can never leave a
/// half-written file behind (same approach as
/// `LocalWorkoutSessionRepository`).
class LocalWorkoutCompletionRepository
    implements WorkoutCompletionRepository {
  /// Test seam — production wiring leaves this null and falls back to
  /// `getApplicationDocumentsDirectory`. Tests pass a temp directory so
  /// the repo can be exercised against a real filesystem without
  /// mocking path_provider's MethodChannel.
  final Future<Directory> Function()? _directoryResolver;

  LocalWorkoutCompletionRepository({
    Future<Directory> Function()? directoryResolver,
  }) : _directoryResolver = directoryResolver;

  static const _fileName = 'workout_completion.json';

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

  Future<File> _file() async {
    final dir = await _dir();
    return File('${dir.path}/$_fileName');
  }

  @override
  Future<Map<String, WorkoutCompletion>> loadAll() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return {};
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return {};

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final out = <String, WorkoutCompletion>{};
      decoded.forEach((key, value) {
        out[key] = WorkoutCompletion.fromJson(value as Map<String, dynamic>);
      });
      return out;
    } on Object {
      // Corrupt store — clear silently and start over rather than
      // crash the home screen. Same defensive posture as
      // LocalWorkoutSessionRepository.loadActive.
      try {
        final file = await _file();
        if (file.existsSync()) await file.delete();
      } on FileSystemException {
        // best-effort cleanup
      }
      return {};
    }
  }

  @override
  Future<void> upsert(WorkoutCompletion completion) => _enqueueWrite(() async {
        final existing = await loadAll();
        existing[completion.workoutId] = completion;
        final encoded = <String, dynamic>{
          for (final entry in existing.entries) entry.key: entry.value.toJson(),
        };

        final file = await _file();
        await file.parent.create(recursive: true);
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(jsonEncode(encoded), flush: true);
        await tmp.rename(file.path);
      });
}
