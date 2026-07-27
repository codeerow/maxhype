import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/services/generator/workout_generator_service.dart';

/// Regression for the customer report: on Advanced, the web generator never
/// auto-picks Smith Machine exercises (getAvailableForSlot skips them for
/// advanced unless favorited). We express the same rule declaratively via
/// `maxExperience: "intermediate"` in the exercise library, enforced through
/// [GeneratorMetadata.isGeneratableAt]. This test locks that behavior in.
Future<AssetWorkoutGeneratorService> service() async {
  final repo = AssetExerciseRepository(
    jsonLoader: () async =>
        File('assets/data/exercise_library.json').readAsString(),
  );
  await repo.load();
  return AssetWorkoutGeneratorService(repo);
}

const _splits = ['Push Day', 'Pull Day', 'Legs + Core'];

void main() {
  group('Smith Machine experience gating', () {
    test('advanced never auto-generates a Smith Machine pick '
        'across an 8-week PPL run', () async {
      final svc = await service();
      final offenders = <String>[];
      // Mirror the validation pack: 8 weeks x 3 splits, seed stepping so the
      // whole run is deterministic.
      for (var session = 0; session < 24; session++) {
        final split = _splits[session % _splits.length];
        final w = svc.generate(
          GenerationRequest(
            splitName: split,
            durationMinutes: 90,
            experience: ExperienceLevel.advanced,
          ),
          seed: 1000 + session,
        );
        for (final e in w.exercises) {
          if (e.generatorMeta?.equipment.label == 'Smith Machine') {
            final week = session ~/ _splits.length + 1;
            offenders.add('w$week $split: ${e.name}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason: 'Smith Machine must not appear on advanced:\n'
            '${offenders.join('\n')}',
      );
    });

    test('intermediate still receives Smith Machine as an eligible pick',
        () async {
      final svc = await service();
      // Smith remains generatable at/below its intermediate cap. Across enough
      // seeds at least one Smith pick should surface for an intermediate PPL
      // user (the library has 15 Smith exercises spanning every split).
      var sawSmith = false;
      for (var seed = 0; seed < 40 && !sawSmith; seed++) {
        for (final split in _splits) {
          final w = svc.generate(
            GenerationRequest(
              splitName: split,
              durationMinutes: 120,
              experience: ExperienceLevel.intermediate,
            ),
            seed: seed,
          );
          if (w.exercises
              .any((e) => e.generatorMeta?.equipment.label == 'Smith Machine')) {
            sawSmith = true;
            break;
          }
        }
      }
      expect(
        sawSmith,
        isTrue,
        reason: 'Smith Machine should stay eligible for intermediate users; '
            'the maxExperience cap must only gate advanced.',
      );
    });
  });
}
