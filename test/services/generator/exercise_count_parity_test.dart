import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/services/generator/workout_generator_service.dart';

/// Parity with the web generator's exercise-count budget.
///
/// The prototype sizes every workout as
/// `min(DURATION_PROFILES[experience][split][minutes].ex, slots.length)`
/// (script.js:6503) and bounds the slot fill by that budget (script.js:6874),
/// so lower experience tiers get fewer exercises than the advanced-authored
/// slot plans. This suite locks the full matrix to the counts the web engine
/// actually produces (verified empirically by executing the prototype's
/// `buildWorkoutForIndex` headless across every cell).
///
/// The one intentional "shortfall" cell: Advanced Push 105/120 budgets 9 but
/// both engines produce 8 — the 9th slot (a second front-delt slot) is blocked
/// by the shared `front_raise: 1` movement-group cap. That parity (8 == 8) is
/// asserted here too.
Future<AssetWorkoutGeneratorService> service() async {
  final repo = AssetExerciseRepository(
    jsonLoader: () async =>
        File('assets/data/exercise_library.json').readAsString(),
  );
  await repo.load();
  return AssetWorkoutGeneratorService(repo);
}

/// experience → split → duration → expected exercise count.
///
/// Values are the web's `DURATION_PROFILES[...].ex` clamped to the slot count,
/// with the empirically confirmed Advanced Push 105/120 → 8 exception.
const Map<ExperienceLevel, Map<String, Map<int, int>>> expectedCounts = {
  ExperienceLevel.none: {
    'Push Day': {45: 4, 60: 5, 75: 6, 90: 7, 105: 7, 120: 7},
    'Pull Day': {45: 4, 60: 5, 75: 6, 90: 6, 105: 7, 120: 7},
    'Legs + Core': {45: 5, 60: 6, 75: 7, 90: 8, 105: 8, 120: 9},
  },
  ExperienceLevel.beginner: {
    'Push Day': {45: 5, 60: 6, 75: 6, 90: 7, 105: 7, 120: 7},
    'Pull Day': {45: 5, 60: 6, 75: 6, 90: 7, 105: 7, 120: 7},
    'Legs + Core': {45: 5, 60: 6, 75: 7, 90: 8, 105: 8, 120: 9},
  },
  ExperienceLevel.intermediate: {
    'Push Day': {45: 5, 60: 6, 75: 7, 90: 7, 105: 8, 120: 8},
    'Pull Day': {45: 5, 60: 6, 75: 7, 90: 7, 105: 8, 120: 8},
    'Legs + Core': {45: 5, 60: 6, 75: 7, 90: 8, 105: 8, 120: 9},
  },
  ExperienceLevel.advanced: {
    // 105/120 budget 9; both engines land on 8 (front_raise cap, see above).
    'Push Day': {45: 5, 60: 6, 75: 7, 90: 8, 105: 8, 120: 8},
    'Pull Day': {45: 5, 60: 6, 75: 7, 90: 8, 105: 8, 120: 8},
    'Legs + Core': {45: 5, 60: 6, 75: 7, 90: 8, 105: 8, 120: 9},
  },
};

void main() {
  group('exercise-count parity with web', () {
    late AssetWorkoutGeneratorService svc;

    setUpAll(() async {
      svc = await service();
    });

    for (final expEntry in expectedCounts.entries) {
      final experience = expEntry.key;
      for (final splitEntry in expEntry.value.entries) {
        final split = splitEntry.key;
        for (final durEntry in splitEntry.value.entries) {
          final minutes = durEntry.key;
          final expected = durEntry.value;
          test('$split @$minutes ${experience.name} → $expected exercises', () {
            for (var seed = 1000; seed < 1010; seed++) {
              final w = svc.generate(
                GenerationRequest(
                  splitName: split,
                  durationMinutes: minutes,
                  experience: experience,
                ),
                seed: seed,
              );
              expect(
                w.exercises.length,
                expected,
                reason:
                    '$split @$minutes ${experience.name} seed=$seed: '
                    'got ${w.exercises.map((e) => e.name).toList()}',
              );
            }
          });
        }
      }
    }
  });
}
