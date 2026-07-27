import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';

/// Parity with the web generator's upper-bound experience gating.
///
/// The web library caps a few quad exercises so they never reach advanced/
/// intermediate users. We express the same rules in data:
///   * Dumbbell Step Up / Dumbbell Split Squat → maxExperience: "beginner"
///     (generatable only for none/beginner).
///   * Barbell Step Up → generatorExclude (the web sets an impossible
///     min=intermediate + max=beginner range, i.e. never auto-generated; we
///     state that intent directly as generatorExclude).
Future<AssetExerciseRepository> loadedRepo() async {
  final repo = AssetExerciseRepository(
    jsonLoader: () async =>
        File('assets/data/exercise_library.json').readAsString(),
  );
  await repo.load();
  return repo;
}

void main() {
  group('experience-cap parity with web', () {
    late AssetExerciseRepository repo;

    setUp(() async {
      repo = await loadedRepo();
    });

    Set<String> generatableAt(ExperienceLevel level) =>
        repo.getGeneratableExercises(level).map((e) => e.name).toSet();

    test('Dumbbell Step Up / Split Squat: none & beginner only', () {
      for (final capped in const ['Dumbbell Step Up', 'Dumbbell Split Squat']) {
        expect(generatableAt(ExperienceLevel.none), contains(capped),
            reason: '$capped should be generatable for none');
        expect(generatableAt(ExperienceLevel.beginner), contains(capped),
            reason: '$capped should be generatable for beginner');
        expect(generatableAt(ExperienceLevel.intermediate), isNot(contains(capped)),
            reason: '$capped is capped at beginner — not for intermediate');
        expect(generatableAt(ExperienceLevel.advanced), isNot(contains(capped)),
            reason: '$capped is capped at beginner — not for advanced');
      }
    });

    test('Barbell Step Up: never auto-generated at any level', () {
      for (final level in ExperienceLevel.values) {
        expect(
          generatableAt(level),
          isNot(contains('Barbell Step Up')),
          reason: 'Barbell Step Up is generatorExclude — never auto-generated '
              '(${level.name})',
        );
      }
    });
  });
}
