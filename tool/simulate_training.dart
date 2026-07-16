// Offline training simulator for the MaxHype workout generator.
//
// Runs a configurable number of PPL weeks, threading cross-session rotation
// memory between sessions EXACTLY as the app does on-device (each finished
// workout is recorded into rotation memory before the next is generated), and
// writes two CSV reports you can open in Excel / Numbers / Sheets:
//
//   * <out>_sessions.csv  — one row per exercise: week, day, split, exercise,
//     sets, reps, and the generator metadata (primaryMuscle / movementPattern /
//     equipment / tier) that explains why it was picked.
//   * <out>_variety.csv   — one row per distinct exercise: how many times it
//     appeared across the whole run, plus a run summary (library coverage,
//     repeat rate) — the numbers to show a client.
//
// This is a dev/QA tool, not shipped in the app. It imports the production
// generator and asset library directly, so what it reports is exactly what the
// app produces.
//
// Usage (via the Flutter test runner, because the asset repository imports
// flutter/services — plain `dart run` can't load the engine):
//
//   flutter test tool/simulate_training.dart \
//     --dart-define=SIM_ARGS="--weeks=8 --days=3 --duration=90 --experience=advanced --out=build/sim"
//
// Or use the convenience wrapper: `bash tool/simulate.sh --weeks=8 ...`
//
//   --weeks        number of weeks to simulate (default 8)
//   --days         training days per week, P/P/L cycle (default 3)
//   --duration     minutes per workout: 45/60/75/90/105/120 (default 90)
//   --experience   none|beginner|intermediate|advanced (default advanced)
//   --out          output path prefix (default build/sim)
//   --no-rotation  disable rotation memory (each session starts fresh) — useful
//                  to A/B the effect of rotation by diffing two runs
//   --seed         base RNG seed (default 1000); the per-session seed varies
//                  deterministically so a run is reproducible

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/rotation_memory.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/services/generator/workout_generator_service.dart';

const _pplCycle = ['Push Day', 'Pull Day', 'Legs + Core'];

// Args come in via --dart-define=SIM_ARGS="--weeks=8 ..." because this runs
// under the Flutter test runner (see the header comment for why).
const _simArgs = String.fromEnvironment('SIM_ARGS');

void main() {
  test('run training simulation and write CSV reports', () async {
    await _run(_simArgs.split(RegExp(r'\s+')).where((a) => a.isNotEmpty).toList());
  });
}

Future<void> _run(List<String> args) async {
  final opts = _parseArgs(args);

  final repo = AssetExerciseRepository(
    jsonLoader: () async =>
        File('assets/data/exercise_library.json').readAsString(),
  );
  await repo.load();
  final svc = AssetWorkoutGeneratorService(repo);

  final totalGeneratable =
      repo.getGeneratableExercises(opts.experience).length;

  // Simulate: generate each session, record it into rotation memory, carry the
  // memory forward. Split cycles P/P/L continuously across weeks.
  var memory = const RotationMemory.empty();
  final sessions = <_Session>[];
  var dayIndex = 0;
  for (var week = 1; week <= opts.weeks; week++) {
    for (var d = 0; d < opts.days; d++) {
      final split = _pplCycle[dayIndex % _pplCycle.length];
      final w = svc.generate(
        GenerationRequest(
          splitName: split,
          durationMinutes: opts.duration,
          experience: opts.experience,
          rotationMemory: opts.rotation ? memory : const RotationMemory.empty(),
        ),
        // Vary the seed per session (as production does with a time/counter)
        // while staying reproducible for a given base seed.
        seed: opts.seed + dayIndex,
      );
      sessions.add(_Session(week, d + 1, split, w.exercises));
      // Record the "completed" workout so the next generation rotates away.
      memory = memory.recordCompletion(split, w.exercises);
      dayIndex++;
    }
  }

  final sessionsPath = '${opts.out}_sessions.csv';
  final varietyPath = '${opts.out}_variety.csv';
  await _writeSessionsCsv(sessionsPath, sessions);
  await _writeVarietyCsv(varietyPath, sessions, totalGeneratable, opts);

  // Console summary.
  final allNames = <String>[];
  for (final s in sessions) {
    allNames.addAll(s.exercises.map((e) => e.name));
  }
  final distinct = allNames.toSet().length;
  stdout
    ..writeln('MaxHype training simulation')
    ..writeln('  config      : ${opts.weeks} weeks x ${opts.days} days, '
        '${opts.duration}min, ${opts.experience.name}, '
        'rotation ${opts.rotation ? "ON" : "OFF"}')
    ..writeln('  sessions    : ${sessions.length}')
    ..writeln('  exercises   : ${allNames.length} total, $distinct distinct')
    ..writeln('  coverage    : $distinct / $totalGeneratable generatable '
        '(${(100 * distinct / totalGeneratable).toStringAsFixed(0)}%)')
    ..writeln('  reports     :')
    ..writeln('    $sessionsPath')
    ..writeln('    $varietyPath');
}

class _Session {
  final int week;
  final int day;
  final String split;
  final List<Exercise> exercises;
  _Session(this.week, this.day, this.split, this.exercises);
}

class _Opts {
  final int weeks;
  final int days;
  final int duration;
  final ExperienceLevel experience;
  final String out;
  final bool rotation;
  final int seed;
  _Opts(this.weeks, this.days, this.duration, this.experience, this.out,
      {required this.rotation, required this.seed});
}

_Opts _parseArgs(List<String> args) {
  final m = <String, String>{};
  final flags = <String>{};
  for (final a in args) {
    if (a.startsWith('--') && a.contains('=')) {
      final i = a.indexOf('=');
      m[a.substring(2, i)] = a.substring(i + 1);
    } else if (a.startsWith('--')) {
      flags.add(a.substring(2));
    }
  }
  return _Opts(
    int.tryParse(m['weeks'] ?? '') ?? 8,
    int.tryParse(m['days'] ?? '') ?? 3,
    int.tryParse(m['duration'] ?? '') ?? 90,
    ExperienceLevel.fromWire(m['experience'] ?? 'advanced'),
    m['out'] ?? 'build/sim',
    rotation: !flags.contains('no-rotation'),
    seed: int.tryParse(m['seed'] ?? '') ?? 1000,
  );
}

String _csv(Object? v) {
  final s = '$v';
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

Future<void> _writeSessionsCsv(String path, List<_Session> sessions) async {
  final b = StringBuffer()
    ..writeln([
      'week',
      'day',
      'split',
      'slot',
      'exercise',
      'sets',
      'reps',
      'primaryMuscle',
      'movementPattern',
      'equipment',
      'tier',
    ].map(_csv).join(','));
  for (final s in sessions) {
    var slot = 0;
    for (final e in s.exercises) {
      slot++;
      final meta = e.generatorMeta;
      b.writeln([
        s.week,
        s.day,
        s.split,
        slot,
        e.name,
        e.sets,
        e.reps,
        meta?.primaryMuscle ?? '',
        meta?.movementPattern ?? '',
        meta?.equipment.label ?? '',
        meta?.tier.wireValue ?? '',
      ].map(_csv).join(','));
    }
  }
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsString(b.toString());
}

Future<void> _writeVarietyCsv(
  String path,
  List<_Session> sessions,
  int totalGeneratable,
  _Opts opts,
) async {
  // Count appearances per exercise, and per (split,exercise) so we can show
  // where each exercise landed.
  final count = <String, int>{};
  final perSplit = <String, Map<String, int>>{};
  for (final s in sessions) {
    for (final e in s.exercises) {
      count[e.name] = (count[e.name] ?? 0) + 1;
      (perSplit[e.name] ??= {})[s.split] =
          ((perSplit[e.name] ?? const {})[s.split] ?? 0) + 1;
    }
  }
  final ranked = count.keys.toList()
    ..sort((a, b) => count[b]!.compareTo(count[a]!));

  final totalPicks = count.values.fold<int>(0, (a, b) => a + b);
  final distinct = count.length;

  final b = StringBuffer()
    // Run summary block first (a few key=value rows), then the per-exercise
    // table. Excel reads it fine; the blank line separates the two.
    ..writeln('${_csv("metric")},${_csv("value")}')
    ..writeln('${_csv("weeks")},${_csv(opts.weeks)}')
    ..writeln('${_csv("days_per_week")},${_csv(opts.days)}')
    ..writeln('${_csv("duration_min")},${_csv(opts.duration)}')
    ..writeln('${_csv("experience")},${_csv(opts.experience.name)}')
    ..writeln('${_csv("rotation")},${_csv(opts.rotation ? "on" : "off")}')
    ..writeln('${_csv("total_sessions")},${_csv(sessions.length)}')
    ..writeln('${_csv("total_exercise_picks")},${_csv(totalPicks)}')
    ..writeln('${_csv("distinct_exercises")},${_csv(distinct)}')
    ..writeln('${_csv("library_generatable")},${_csv(totalGeneratable)}')
    ..writeln('${_csv("library_coverage_pct")},'
        '${_csv((100 * distinct / totalGeneratable).toStringAsFixed(1))}')
    ..writeln('${_csv("avg_appearances_per_used_exercise")},'
        '${_csv((totalPicks / distinct).toStringAsFixed(2))}')
    ..writeln()
    ..writeln([
      'exercise',
      'total_appearances',
      'pct_of_picks',
      'push',
      'pull',
      'legs_core',
    ].map(_csv).join(','));
  for (final name in ranked) {
    final ps = perSplit[name] ?? const {};
    b.writeln([
      name,
      count[name],
      '${(100 * count[name]! / totalPicks).toStringAsFixed(1)}%',
      ps['Push Day'] ?? 0,
      ps['Pull Day'] ?? 0,
      ps['Legs + Core'] ?? 0,
    ].map(_csv).join(','));
  }
  final f = File(path);
  await f.parent.create(recursive: true);
  await f.writeAsString(b.toString());
}
