import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/session/session_set.dart';
import '../models/session/workout_session.dart';
import 'workout_session_repository.dart';

class LocalWorkoutSessionRepository implements WorkoutSessionRepository {
  static const _activeFlagKey = 'workout_session.has_active';
  static const _activeFileName = 'workout_session_active.json';
  static const _historyFileName = 'workout_history.jsonl';

  Future<File> _activeFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_activeFileName');
  }

  Future<File> _historyFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_historyFileName');
  }

  @override
  Future<WorkoutSession?> loadActive() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_activeFlagKey) ?? false)) return null;

      final file = await _activeFile();
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;

      final json = jsonDecode(raw) as Map<String, dynamic>;
      final session = WorkoutSession.fromJson(json);
      if (session.status != SessionStatus.active) return null;
      return session;
    } catch (_) {
      // Corrupt store — clear silently rather than crash on launch.
      await clearActive();
      return null;
    }
  }

  @override
  Future<void> save(WorkoutSession session) async {
    final file = await _activeFile();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(session.toJson()), flush: true);
    await tmp.rename(file.path);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeFlagKey, true);
  }

  @override
  Future<void> clearActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeFlagKey, false);

    final file = await _activeFile();
    if (await file.exists()) {
      try {
        await file.delete();
      } catch (_) {}
    }
  }

  @override
  Future<void> archiveFinished(WorkoutSession session) async {
    final file = await _historyFile();
    final line = '${jsonEncode(session.toJson())}\n';
    await file.writeAsString(line, mode: FileMode.append, flush: true);
  }

  @override
  Future<SessionSet?> lastLogFor(String exerciseId) async {
    final file = await _historyFile();
    if (!await file.exists()) return null;

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
          if (ex.warmupSet?.isLogged ?? false) return ex.warmupSet;
        }
      } catch (_) {
        continue; // skip corrupt line
      }
    }
    return null;
  }
}
