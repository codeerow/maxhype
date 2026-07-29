import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/split_type.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/services/generator/workout_generator_service.dart';

Future<AssetWorkoutGeneratorService> service() async {
  final repo = AssetExerciseRepository(
    jsonLoader: () async =>
        File('assets/data/exercise_library.json').readAsString(),
  );
  await repo.load();
  return AssetWorkoutGeneratorService(repo);
}

void main() {
  const splits = ['Push Day', 'Pull Day', 'Legs + Core'];

  test('estimatedMinutes stays close to the target duration', () async {
    final svc = await service();
    for (final exp in ExperienceLevel.values) {
      for (final mins in kSupportedDurations) {
        // Window matches estimateWorkoutMinutes (±8% of target, rounded).
        final tolerance = (mins * 0.08).round();
        for (final split in splits) {
          for (var seed = 0; seed < 8; seed++) {
            final w = svc.generate(
              GenerationRequest(
                splitName: split,
                durationMinutes: mins,
                experience: exp,
              ),
              seed: seed,
            );
            expect(
              (w.estimatedMinutes - mins).abs(),
              lessThanOrEqualTo(tolerance),
              reason:
                  '$exp $split @$mins seed=$seed '
                  'estimated ${w.estimatedMinutes}, off by more than $tolerance',
            );
            expect(w.estimatedMinutes, greaterThan(0));
          }
        }
      }
    }
  });

  test('estimatedMinutes varies across re-rolls of the same plan', () async {
    final svc = await service();
    // Regression: for a *fixed* plan (same target, split, experience) the card
    // must not show a flat echo of the pick — different re-rolls pick different
    // exercises and so must land on different minute estimates around 75.
    final seen = <int>{};
    for (var seed = 0; seed < 20; seed++) {
      final w = svc.generate(
        const GenerationRequest(
          splitName: 'Push Day',
          durationMinutes: 75,
          experience: ExperienceLevel.advanced,
        ),
        seed: seed,
      );
      seen.add(w.estimatedMinutes);
    }
    expect(
      seen.length,
      greaterThan(3),
      reason: 'estimate should spread across re-rolls, got only $seen',
    );
  });

  test('estimatedMinutes is deterministic for a given seed', () async {
    final svc = await service();
    const req = GenerationRequest(
      splitName: 'Legs + Core',
      durationMinutes: 90,
      experience: ExperienceLevel.intermediate,
    );
    final a = svc.generate(req, seed: 7).estimatedMinutes;
    final b = svc.generate(req, seed: 7).estimatedMinutes;
    expect(a, b);
  });

  test('estimateWorkoutMinutes falls back to target on empty input', () {
    expect(estimateWorkoutMinutes(const <Exercise>[], targetMinutes: 75), 75);
  });
}
