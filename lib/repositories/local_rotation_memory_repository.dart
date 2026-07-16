import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/exercise.dart';
import '../models/generator/rotation_memory.dart';
import 'rotation_memory_repository.dart';

/// Local filesystem implementation of [RotationMemoryRepository].
///
/// Storage: `rotation_memory.json` in the app documents directory, shape
/// `{ "memory": {split: {bucket: [names]}}, "completions": [key, ...] }`.
/// The `completions` list is the dedup tracker (rolling window of the last
/// [_maxCompletions] processed completion keys — script.js:11420).
///
/// Uses the same durability pattern as `LocalWorkoutCompletionRepository`:
/// a write-lock serialises writes, write-temp-then-rename makes them atomic,
/// and a corrupt store is cleared rather than crashing generation.
class LocalRotationMemoryRepository implements RotationMemoryRepository {
  /// Test seam — production leaves this null and uses the app documents dir.
  final Future<Directory> Function()? _directoryResolver;

  LocalRotationMemoryRepository({
    Future<Directory> Function()? directoryResolver,
  }) : _directoryResolver = directoryResolver;

  static const _fileName = 'rotation_memory.json';

  /// Max processed-completion keys retained (script.js:11420).
  static const _maxCompletions = 100;

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

  /// Reads the raw store (memory + completions), defaulting to empty and
  /// clearing a corrupt file rather than throwing.
  Future<({RotationMemory memory, List<String> completions})> _read() async {
    try {
      final file = await _file();
      if (!file.existsSync()) {
        return (memory: const RotationMemory.empty(), completions: <String>[]);
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return (memory: const RotationMemory.empty(), completions: <String>[]);
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final memory = RotationMemory.fromJson(
        (decoded['memory'] as Map<String, dynamic>?) ?? const {},
      );
      final completions =
          ((decoded['completions'] as List<dynamic>?) ?? const [])
              .cast<String>();
      return (memory: memory, completions: completions);
    } on Object {
      try {
        final file = await _file();
        if (file.existsSync()) await file.delete();
      } on FileSystemException {
        // best-effort cleanup
      }
      return (memory: const RotationMemory.empty(), completions: <String>[]);
    }
  }

  @override
  Future<RotationMemory> load() async => (await _read()).memory;

  @override
  Future<void> recordCompletion(
    String split,
    List<Exercise> exercises, {
    required String completionKey,
  }) =>
      _enqueueWrite(() async {
        final current = await _read();
        // Dedup: skip if this completion was already recorded.
        if (current.completions.contains(completionKey)) return;

        final nextMemory = current.memory.recordCompletion(split, exercises);
        final nextCompletions = [...current.completions, completionKey];
        while (nextCompletions.length > _maxCompletions) {
          nextCompletions.removeAt(0);
        }

        final encoded = jsonEncode({
          'memory': nextMemory.toJson(),
          'completions': nextCompletions,
        });
        final file = await _file();
        await file.parent.create(recursive: true);
        final tmp = File('${file.path}.tmp');
        await tmp.writeAsString(encoded, flush: true);
        await tmp.rename(file.path);
      });
}
