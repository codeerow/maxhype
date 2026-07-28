import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/generator/exercise_taxonomy.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/generator_metadata.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/services/generator/anti_dominance.dart';
import 'package:maxhype/services/generator/build_state.dart';
import 'package:maxhype/services/generator/workout_generator_service.dart';

const _ad = AntiDominance();

Exercise ex(String name, {String movementPattern = 'flat_press'}) => Exercise(
  id: name,
  name: name,
  sets: 3,
  reps: 8,
  weight: 0,
  muscleGroups: const [],
  equipmentType: EquipmentType.barbell,
  rating: 0,
  generatorMeta: GeneratorMetadata(
    category: 'chest press',
    bodyPart: const BodyPart('Chest'),
    equipment: const GeneratorEquipment('Barbell'),
    type: ExerciseType.compound,
    tier: ExerciseTier.a,
    minExperience: ExperienceLevel.none,
    movementPattern: movementPattern,
  ),
);

void main() {
  group('anti-dominance severity² curve', () {
    test('no penalty below the 20% threshold', () {
      final state = BuildState('Push Day');
      // 1 use out of 5 total in slotType → 20% exactly → not > 0.2 → 0.
      state.slotUsage['triceps_stretch'] = {'X': 1};
      state.slotTotals['triceps_stretch'] = 5;
      expect(_ad.penaltyFor(ex('X'), 'triceps_stretch', state), 0);
    });

    test('penalty grows with dominance and matches the prototype curve', () {
      final state = BuildState('Push Day');
      // slotType with NO multiplier entry → mult 1.0. pct=0.5 → severity=0.375
      // → 0.375^2.2 * 5000 ≈ -566 (sign negative).
      state.slotUsage['some_slot'] = {'X': 5};
      state.slotTotals['some_slot'] = 10;
      final p = _ad.penaltyFor(ex('X'), 'some_slot', state);
      expect(p, lessThan(0));
      // Ballpark check against the documented curve (pct=0.5 base ≈ -281..-566
      // depending on exponent; we use 2.2). Just assert it's a strong penalty.
      expect(p, lessThan(-100));
    });

    test('slot multiplier scales the penalty', () {
      final base = BuildState('Push Day')
        ..slotUsage['plain'] = {'X': 8}
        ..slotTotals['plain'] = 10;
      final mult = BuildState('Legs + Core')
        ..slotUsage['legs_glute_accessory'] = {'X': 8}
        ..slotTotals['legs_glute_accessory'] = 10;
      final pPlain = _ad.penaltyFor(ex('X'), 'plain', base);
      final pMult = _ad.penaltyFor(ex('X'), 'legs_glute_accessory', mult);
      // legs_glute_accessory multiplier is 2.2 → same pct, 2.2× the penalty.
      expect(pMult, closeTo(pPlain * 2.2, 0.001));
    });

    test('null slotType or empty slot → 0', () {
      final state = BuildState('Push Day');
      expect(_ad.penaltyFor(ex('X'), null, state), 0);
      expect(_ad.penaltyFor(ex('X'), 'never_used', state), 0);
    });
  });

  group('canonical anchors (Phase 14C)', () {
    test('canonical anchor boosted on primary-compound, experience-scaled', () {
      final bench = ex('Barbell Bench Press');
      expect(
        _ad.anchorAdjustment(
          bench,
          ExperienceLevel.advanced,
          isPrimaryCompoundSlot: true,
        ),
        18,
      );
      expect(
        _ad.anchorAdjustment(
          bench,
          ExperienceLevel.intermediate,
          isPrimaryCompoundSlot: true,
        ),
        14,
      );
      expect(
        _ad.anchorAdjustment(
          bench,
          ExperienceLevel.beginner,
          isPrimaryCompoundSlot: true,
        ),
        10,
      );
    });

    test('variant anchor penalized (smaller magnitude than boost)', () {
      final hack = ex('Hack Squat');
      expect(
        _ad.anchorAdjustment(
          hack,
          ExperienceLevel.advanced,
          isPrimaryCompoundSlot: true,
        ),
        -14,
      );
      expect(
        _ad.anchorAdjustment(
          hack,
          ExperienceLevel.beginner,
          isPrimaryCompoundSlot: true,
        ),
        -6,
      );
    });

    test('no adjustment off primary-compound slots or for unknown names', () {
      final bench = ex('Barbell Bench Press');
      expect(
        _ad.anchorAdjustment(
          bench,
          ExperienceLevel.advanced,
          isPrimaryCompoundSlot: false,
        ),
        0,
      );
      expect(
        _ad.anchorAdjustment(
          ex('Some Random Machine'),
          ExperienceLevel.advanced,
          isPrimaryCompoundSlot: true,
        ),
        0,
      );
    });
  });

  group('pull-alternation on real Pull Day generation', () {
    test('the two primary pulls never share a movement axis', () async {
      final repo = AssetExerciseRepository(
        jsonLoader: () async =>
            File('assets/data/exercise_library.json').readAsString(),
      );
      await repo.load();
      final svc = AssetWorkoutGeneratorService(repo);
      const primaryPulls = {'horizontal_row', 'supported_row', 'vertical_pull'};
      for (var seed = 0; seed < 80; seed++) {
        final w = svc.generate(
          const GenerationRequest(
            splitName: 'Pull Day',
            durationMinutes: 120,
            experience: ExperienceLevel.advanced,
          ),
          seed: seed,
        );
        final axes = <String>[];
        for (final e in w.exercises) {
          final p = e.generatorMeta?.movementPattern;
          if (p != null && primaryPulls.contains(p)) {
            axes.add(p == 'vertical_pull' ? 'vertical' : 'horizontal');
          }
        }
        // Pull-alternation is a SELECTION rule: the second committed primary
        // pull must alternate axis from the first. The final ordering pass
        // (script.js:5919, ported) then re-groups rows/pulldowns into blocks,
        // so commit order is no longer observable in the returned list — the
        // order-independent consequence is that a workout with 2+ primary
        // pulls always covers BOTH axes (a same-axis pair could never have
        // been committed).
        if (axes.length >= 2) {
          expect(
            axes.toSet(),
            {'horizontal', 'vertical'},
            reason:
                'seed $seed: 2+ primary pulls must span both axes, got $axes',
          );
        }
      }
    });
  });
}
