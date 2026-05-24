import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/session/personal_record.dart';
import '../models/session/workout_session.dart';
import 'personal_record_repository.dart';

/// Reads [PersonalRecord]s by scanning the same `workout_history.jsonl`
/// file the workout-session repository writes finished sessions to.
///
/// Cache: a single in-memory `Map<exerciseId, PersonalRecord>` rebuilt on
/// the first call after [invalidate] (or first ever call). The whole
/// history file is small in practice (one JSON line per finished
/// workout) so a full scan is fine — if it ever becomes a bottleneck
/// we can switch to an index file.
class LocalPersonalRecordRepository implements PersonalRecordRepository {
  /// Override for the directory that holds `workout_history.jsonl`.
  /// Production wiring leaves this null and falls back to
  /// `getApplicationDocumentsDirectory`. Tests pass a temp dir so the
  /// repository can be exercised against a real filesystem without
  /// mocking the path_provider MethodChannel.
  final Future<Directory> Function()? _directoryResolver;

  LocalPersonalRecordRepository({Future<Directory> Function()? directoryResolver})
      : _directoryResolver = directoryResolver;

  static const _historyFileName = 'workout_history.jsonl';

  Map<String, PersonalRecord>? _cache;
  Future<Map<String, PersonalRecord>>? _inflight;

  Future<File> _historyFile() async {
    final dir = await (_directoryResolver?.call() ??
        getApplicationDocumentsDirectory());
    return File('${dir.path}/$_historyFileName');
  }

  @override
  Future<PersonalRecord?> bestFor(String exerciseId) async {
    final cache = await _ensureCache();
    return cache[exerciseId];
  }

  @override
  void invalidate() {
    _cache = null;
    _inflight = null;
  }

  Future<Map<String, PersonalRecord>> _ensureCache() {
    if (_cache != null) return Future.value(_cache);
    return _inflight ??= _loadAll().then((value) {
      _cache = value;
      _inflight = null;
      return value;
    });
  }

  Future<Map<String, PersonalRecord>> _loadAll() async {
    final file = await _historyFile();
    if (!file.existsSync()) return {};
    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return {};

    final best = <String, PersonalRecord>{};
    final lines = raw.split('\n').where((l) => l.trim().isNotEmpty);
    for (final line in lines) {
      try {
        final session = WorkoutSession.fromJson(
          jsonDecode(line) as Map<String, dynamic>,
        );
        for (final ex in session.exercises) {
          for (final s in ex.sets) {
            if (!s.isLogged || s.weight == null || s.reps == null) continue;
            final candidate = PersonalRecord(
              exerciseId: ex.exerciseId,
              weight: s.weight!,
              reps: s.reps!,
              achievedAt: s.loggedAt ?? session.finishedAt ?? session.startedAt,
            );
            final existing = best[ex.exerciseId];
            if (existing == null ||
                existing.isBeatenBy(
                  weight: candidate.weight,
                  reps: candidate.reps,
                )) {
              best[ex.exerciseId] = candidate;
            }
          }
        }
      } on FormatException {
        continue;
      }
    }
    return best;
  }
}
