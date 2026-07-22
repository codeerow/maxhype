import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/rotation_memory.dart';
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

/// How often [name] appears in the first slot's category across many seeds.
int frequency(
  AssetWorkoutGeneratorService svc,
  String split,
  String name, {
  required RotationMemory memory,
  int seeds = 120,
}) {
  var count = 0;
  for (var seed = 0; seed < seeds; seed++) {
    final w = svc.generate(
      GenerationRequest(
        splitName: split,
        durationMinutes: 90,
        experience: ExperienceLevel.advanced,
        rotationMemory: memory,
      ),
      seed: seed,
    );
    if (w.exercises.any((e) => e.name == name)) count++;
  }
  return count;
}

void main() {
  test('empty rotation memory leaves generation deterministic vs 2A', () async {
    final svc = await service();
    // Same seed + empty memory → identical to a no-memory request.
    final a = svc.generate(
      const GenerationRequest(
        splitName: 'Push Day',
        durationMinutes: 90,
        experience: ExperienceLevel.advanced,
      ),
      seed: 5,
    );
    final b = svc.generate(
      const GenerationRequest(
        splitName: 'Push Day',
        durationMinutes: 90,
        experience: ExperienceLevel.advanced,
        rotationMemory: RotationMemory.empty(),
      ),
      seed: 5,
    );
    expect(
      a.exercises.map((e) => e.name),
      b.exercises.map((e) => e.name),
    );
  });

  test('a recently-trained exercise is strongly deprioritized', () async {
    final svc = await service();
    // A common Push chest-press exercise. With an empty memory it shows up in a
    // healthy fraction of workouts; once it's in rotation memory (an exact
    // match → -50), it should nearly vanish from generated workouts.
    const target = 'Barbell Bench Press';
    final baseline = frequency(svc, 'Push Day', target,
        memory: const RotationMemory.empty());
    expect(baseline, greaterThan(0),
        reason: 'sanity: $target should appear without memory');

    final repo = AssetExerciseRepository(
      jsonLoader: () async =>
          File('assets/data/exercise_library.json').readAsString(),
    );
    await repo.load();
    final memory = const RotationMemory.empty()
        .recordCompletion('Push Day', [repo.getExerciseByName(target)!]);

    final loaded = frequency(svc, 'Push Day', target, memory: memory);

    // The -50 exact-match penalty pushes the recently-trained exercise out of
    // contention: it appears far less often (and in practice not at all, since
    // the chest-press pool has ample unpenalized alternatives).
    expect(
      loaded,
      lessThan(baseline ~/ 2),
      reason: 'rotation memory should sharply reduce $target frequency '
          '(baseline=$baseline, loaded=$loaded)',
    );
  });
}
