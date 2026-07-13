import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/generator/experience_level.dart';
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
  test('smoke: generate one of each split @ 90 min intermediate', () async {
    final svc = await service();
    for (final split in ['Push Day', 'Pull Day', 'Legs + Core']) {
      final w = svc.generate(
        GenerationRequest(
          splitName: split,
          durationMinutes: 90,
          experience: ExperienceLevel.intermediate,
        ),
        seed: 1,
      );
      // ignore: avoid_print
      print('\n$split @90 intermediate:');
      for (final e in w.exercises) {
        // ignore: avoid_print
        print('  - ${e.sets}x ${e.name}  '
            '[${e.generatorMeta?.category} / ${e.generatorMeta?.movementGroup}]');
      }
      expect(w.exercises, isNotEmpty, reason: '$split produced no exercises');
    }
  });

  test('smoke: duration scales total set volume', () async {
    final svc = await service();
    int volume(int mins) {
      final w = svc.generate(
        GenerationRequest(
          splitName: 'Push Day',
          durationMinutes: mins,
          experience: ExperienceLevel.intermediate,
        ),
        seed: 1,
      );
      return w.exercises.fold<int>(0, (sum, e) => sum + e.sets);
    }

    final v45 = volume(45);
    final v120 = volume(120);
    // ignore: avoid_print
    print('Push total working sets: 45min=$v45, 120min=$v120');
    expect(v120, greaterThan(v45),
        reason: 'longer workouts should have more total volume');
  });
}
