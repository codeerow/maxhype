import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/generator/exercise_taxonomy.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/generator_metadata.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/services/generator/build_state.dart';
import 'package:maxhype/services/generator/movement_caps.dart';
import 'package:maxhype/services/generator/workout_generator_service.dart';

const _caps = MovementCaps();

Exercise ex(
  String name, {
  required String category,
  String equipment = 'Barbell',
  String? primaryMuscle,
  String? movementPattern,
  String? movementGroup,
  String? stimulusType,
}) {
  return Exercise(
    id: name,
    name: name,
    sets: 3,
    reps: 8,
    weight: 0,
    muscleGroups: const [],
    equipmentType: EquipmentType.barbell,
    rating: 0,
    generatorMeta: GeneratorMetadata(
      category: category,
      bodyPart: const BodyPart('Chest'),
      equipment: GeneratorEquipment(equipment),
      type: ExerciseType.compound,
      tier: ExerciseTier.a,
      minExperience: ExperienceLevel.none,
      primaryMuscle: primaryMuscle,
      movementPattern: movementPattern,
      movementGroup: movementGroup,
      stimulusType: stimulusType,
    ),
  );
}

Future<AssetWorkoutGeneratorService> service() async {
  final repo = AssetExerciseRepository(
    jsonLoader: () async =>
        File('assets/data/exercise_library.json').readAsString(),
  );
  await repo.load();
  return AssetWorkoutGeneratorService(repo);
}

void main() {
  group('pattern bucket routing (this app vocabulary)', () {
    test('Push: chest presses route by angle; shoulder press via '
        'vertical_press', () {
      expect(
        _caps.patternBucketOf(
          ex('Bench',
              category: 'chest press',
              primaryMuscle: 'chest',
              movementPattern: 'flat_press'),
          'Push Day',
        ),
        'flat_press',
      );
      expect(
        _caps.patternBucketOf(
          ex('OHP',
              category: 'shoulder press',
              primaryMuscle: 'shoulders',
              movementPattern: 'vertical_press'),
          'Push Day',
        ),
        'shoulder_press',
      );
    });

    test('Pull: supported_row folds into horizontal_row; rear_delt via pm', () {
      expect(
        _caps.patternBucketOf(
          ex('Chest Supported Row',
              category: 'row',
              primaryMuscle: 'back',
              movementPattern: 'supported_row'),
          'Pull Day',
        ),
        'horizontal_row',
      );
      expect(
        _caps.patternBucketOf(
          ex('Reverse Fly',
              category: 'rear delt',
              primaryMuscle: 'rear_delt',
              movementPattern: 'rear_delt_fly'),
          'Pull Day',
        ),
        'rear_delt',
      );
    });

    test('Legs: knee_flexion → hamstring_curl; knee_extension quads → '
        'quad_iso', () {
      expect(
        _caps.patternBucketOf(
          ex('Leg Curl',
              category: 'hamstring curl',
              primaryMuscle: 'hamstrings',
              movementPattern: 'knee_flexion'),
          'Legs + Core',
        ),
        'hamstring_curl',
      );
      expect(
        _caps.patternBucketOf(
          ex('Leg Extension',
              category: 'quad',
              primaryMuscle: 'quads',
              movementPattern: 'knee_extension'),
          'Legs + Core',
        ),
        'quad_iso',
      );
    });
  });

  group('movement-group super-group hard cap', () {
    test('chest_press super-group allows 2 then blocks the 3rd', () {
      final flat = ex('Bench', category: 'chest press', movementGroup: 'flat_press');
      final incline =
          ex('Incline', category: 'incline press', movementGroup: 'incline_press');
      final decline =
          ex('Decline', category: 'decline press', movementGroup: 'decline_press');
      // 0 committed → allowed; with 2 chest-press variants → blocked.
      expect(_caps.isMovementGroupCapAllowed([], decline), isTrue);
      expect(
        _caps.isMovementGroupCapAllowed([flat, incline], decline),
        isFalse,
        reason: 'chest_press cap is 2',
      );
    });

    test('shoulder_press super-group cap is 1', () {
      final sp1 = ex('OHP', category: 'shoulder press', movementGroup: 'shoulder_press');
      final sp2 = ex('Seated OHP',
          category: 'shoulder press', movementGroup: 'shoulder_press');
      expect(_caps.isMovementGroupCapAllowed([sp1], sp2), isFalse);
    });

    test('uncapped groups are always allowed', () {
      final curl = ex('Curl', category: 'biceps', movementGroup: 'dumbbell_curl');
      final curl2 =
          ex('Curl 2', category: 'biceps', movementGroup: 'dumbbell_curl');
      // dumbbell_curl has no super-group → uncapped.
      expect(_caps.isMovementGroupCapAllowed([curl], curl2), isTrue);
    });
  });

  group('commit tracks balance buckets', () {
    test('committing bumps pattern & stimulus usage', () {
      final state = BuildState('Push Day');
      final bench = ex('Bench',
          category: 'chest press',
          primaryMuscle: 'chest',
          movementPattern: 'flat_press',
          movementGroup: 'flat_press');
      state.commit(bench, movementGroup: 'flat_press');
      expect(state.patternUsage['flat_press'], 1);
      expect(state.stimulusUsage['chest'], 1); // Push: chest primaryMuscle
    });
  });

  group('caps hold on real generated workouts (every split × duration)', () {
    test('no super-group exceeds its MOVEMENT_GROUP_CAP', () async {
      final svc = await service();
      const splits = ['Push Day', 'Pull Day', 'Legs + Core'];
      const durations = [45, 60, 75, 90, 105, 120];
      for (final split in splits) {
        for (final mins in durations) {
          for (final exp in ExperienceLevel.values) {
            final w = svc.generate(
              GenerationRequest(
                splitName: split,
                durationMinutes: mins,
                experience: exp,
              ),
              seed: 77,
            );
            final counts = <String, int>{};
            for (final e in w.exercises) {
              final sg = _caps.movementSuperGroupOf(e);
              if (sg == null) continue;
              counts[sg] = (counts[sg] ?? 0) + 1;
            }
            counts.forEach((sg, n) {
              final cap = MovementCaps.movementGroupCaps[sg]!;
              expect(
                n,
                lessThanOrEqualTo(cap),
                reason: '$split/$mins/${exp.name}: $sg count $n > cap $cap',
              );
            });
          }
        }
      }
    });

    test('Push never gets two of the same chest-press angle', () async {
      final svc = await service();
      // Chest-press angles are a hard invariant (never flushed back).
      for (var seed = 0; seed < 60; seed++) {
        final w = svc.generate(
          const GenerationRequest(
            splitName: 'Push Day',
            durationMinutes: 120,
            experience: ExperienceLevel.advanced,
          ),
          seed: seed,
        );
        final angleCounts = <String, int>{};
        for (final e in w.exercises) {
          final bucket = _caps.patternBucketOf(e, 'Push Day');
          if (MovementCaps.chestPressAngleBuckets.contains(bucket)) {
            angleCounts[bucket!] = (angleCounts[bucket] ?? 0) + 1;
          }
        }
        angleCounts.forEach((bucket, n) {
          expect(n, lessThanOrEqualTo(1),
              reason: 'seed $seed: $bucket appeared $n times');
        });
      }
    });
  });
}
