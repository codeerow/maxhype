import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/exercise_taxonomy.dart';
import 'package:maxhype/models/generator/generator_slot.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';

/// Loads the real bundled asset from disk (via the jsonLoader seam) so these
/// tests exercise the actual ported library, not a fixture.
Future<AssetExerciseRepository> loadedRepo() async {
  final repo = AssetExerciseRepository(
    jsonLoader: () async =>
        File('assets/data/exercise_library.json').readAsString(),
  );
  await repo.load();
  return repo;
}

void main() {
  group('library integrity', () {
    test('loads the full 187-exercise library', () async {
      final repo = await loadedRepo();
      expect(repo.getAllExercises().length, 187);
    });

    test('every exercise carries generator metadata', () async {
      final repo = await loadedRepo();
      for (final e in repo.getAllExercises()) {
        expect(e.generatorMeta, isNotNull, reason: '${e.name} missing meta');
      }
    });

    test('ids are unique', () async {
      final repo = await loadedRepo();
      final ids = repo.getAllExercises().map((e) => e.id).toSet();
      expect(ids.length, 187);
    });

    test('names resolve via getExerciseByName', () async {
      final repo = await loadedRepo();
      final bench = repo.getExerciseByName('Barbell Bench Press');
      expect(bench, isNotNull);
      expect(bench!.generatorMeta!.category, 'chest press');
      expect(bench.generatorMeta!.tier, ExerciseTier.a);
      expect(bench.generatorMeta!.minExperience, ExperienceLevel.intermediate);
      expect(bench.generatorMeta!.movementGroup, 'flat_press');
      expect(bench.generatorMeta!.stable, isTrue);
    });

    test('primary + secondary muscle and movement pattern are populated',
        () async {
      final repo = await loadedRepo();
      final bench = repo.getExerciseByName('Barbell Bench Press')!.generatorMeta!;
      expect(bench.primaryMuscle, 'chest');
      expect(bench.secondaryMuscles, containsAll(['triceps', 'front_delt']));
      expect(bench.movementPattern, 'flat_press');
      expect(bench.stimulusType, 'compound');
      expect(bench.hypertrophyRole, 'primary_compound');
    });

    test('every generatable exercise has a primary muscle + movement pattern',
        () async {
      final repo = await loadedRepo();
      final gen = repo.getGeneratableExercises(ExperienceLevel.advanced);
      for (final e in gen) {
        expect(e.generatorMeta!.primaryMuscle, isNotNull,
            reason: '${e.name} has no primaryMuscle');
        expect(e.generatorMeta!.movementPattern, isNotNull,
            reason: '${e.name} has no movementPattern');
      }
    });

    test('coarse muscle + equipment projected for the existing UI', () async {
      final repo = await loadedRepo();
      final bench = repo.getExerciseByName('Barbell Bench Press')!;
      // Existing Replace/atlas UI reads muscleGroups.first + equipmentType.
      expect(bench.muscleGroups, isNotEmpty);
      expect(bench.equipmentType.name, 'barbell');

      final smith = repo.getExerciseByName('Smith Machine Bench Press')!;
      // Smith Machine collapses onto the coarse "machine" bucket.
      expect(smith.equipmentType.name, 'machine');
      // ...while the full-fidelity label is preserved in generator meta.
      expect(smith.generatorMeta!.equipment.label, 'Smith Machine');
    });
  });

  group('generator queries', () {
    test('getExercisesByCategory filters by category', () async {
      final repo = await loadedRepo();
      final presses = repo.getExercisesByCategory('chest press');
      expect(presses, isNotEmpty);
      expect(
        presses.every((e) => e.generatorMeta!.category == 'chest press'),
        isTrue,
      );
    });

    test('getExercisesByTier filters by tier', () async {
      final repo = await loadedRepo();
      final tierA = repo.getExercisesByTier(ExerciseTier.a);
      expect(tierA, isNotEmpty);
      expect(tierA.every((e) => e.generatorMeta!.tier == ExerciseTier.a), isTrue);
    });

    test('experience gating is monotonic — higher level ⊇ lower level',
        () async {
      final repo = await loadedRepo();
      final none = repo.getGeneratableExercises(ExperienceLevel.none).length;
      final beginner =
          repo.getGeneratableExercises(ExperienceLevel.beginner).length;
      final intermediate =
          repo.getGeneratableExercises(ExperienceLevel.intermediate).length;
      final advanced =
          repo.getGeneratableExercises(ExperienceLevel.advanced).length;
      expect(none, lessThanOrEqualTo(beginner));
      expect(beginner, lessThanOrEqualTo(intermediate));
      expect(intermediate, lessThanOrEqualTo(advanced));
    });

    test('generatable excludes replaceOnly and generatorExclude', () async {
      final repo = await loadedRepo();
      final gen = repo.getGeneratableExercises(ExperienceLevel.advanced);
      expect(
        gen.any((e) =>
            e.generatorMeta!.replaceOnly || e.generatorMeta!.generatorExclude),
        isFalse,
      );
    });

    test('advanced-only exercise is gated out below advanced', () async {
      final repo = await loadedRepo();
      final atIntermediate =
          repo.getGeneratableExercises(ExperienceLevel.intermediate);
      // "Deadlift" is advanced-min in the prototype.
      expect(atIntermediate.any((e) => e.name == 'Deadlift'), isFalse);
      final atAdvanced =
          repo.getGeneratableExercises(ExperienceLevel.advanced);
      final deadlift = repo.getExerciseByName('Deadlift');
      // Only assert presence if the library actually contains it.
      if (deadlift != null && !deadlift.generatorMeta!.replaceOnly) {
        expect(atAdvanced.any((e) => e.name == 'Deadlift'), isTrue);
      }
    });
  });

  group('metadata tables', () {
    test('duration profiles resolve for every PPL cell', () async {
      final repo = await loadedRepo();
      final tables = repo.metadataTables!;
      for (final exp in ExperienceLevel.values) {
        for (final split in ['Push Day', 'Pull Day', 'Legs + Core']) {
          for (final mins in [45, 60, 75, 90, 105, 120]) {
            final p = tables.profileFor(
                experience: exp, splitName: split, minutes: mins);
            expect(p, isNotNull,
                reason: 'missing profile $exp/$split/$mins');
            expect(p!.exercises, greaterThan(0));
            expect(p.workingSetsMin, lessThanOrEqualTo(p.workingSetsMax));
          }
        }
      }
    });

    test('unknown duration falls back to nearest tier', () async {
      final repo = await loadedRepo();
      final tables = repo.metadataTables!;
      final p = tables.profileFor(
          experience: ExperienceLevel.beginner,
          splitName: 'Push Day',
          minutes: 63); // not a real tier → nearest is 60
      final exact = tables.profileFor(
          experience: ExperienceLevel.beginner,
          splitName: 'Push Day',
          minutes: 60);
      expect(p!.exercises, exact!.exercises);
    });

    test('set limits: compounds capped higher than core', () async {
      final repo = await loadedRepo();
      final tables = repo.metadataTables!;
      expect(tables.setLimitFor('chest press', 99), 5);
      expect(tables.setLimitFor('abs', 99), 3);
      // Uncapped category returns the global max.
      expect(tables.setLimitFor('not_a_category', 4), 4);
    });
  });

  group('PPL templates', () {
    test('exposes exactly the three PPL templates with slots', () async {
      final repo = await loadedRepo();
      final names = repo.pplTemplates.map((t) => t.name).toList();
      expect(names, ['Push Day', 'Pull Day', 'Legs + Core']);
      expect(repo.pplTemplates.every((t) => t.slots.isNotEmpty), isTrue);
    });

    test('every slot default resolves to a real library exercise', () async {
      final repo = await loadedRepo();
      for (final t in repo.pplTemplates) {
        for (final slot in t.slots) {
          expect(repo.getExerciseByName(slot.defaultExercise), isNotNull,
              reason: '${t.name}: ${slot.defaultExercise} not in library');
        }
      }
    });
  });

  group('slot plans (2A)', () {
    const durations = [45, 60, 75, 90, 105, 120];
    const splits = ['Push Day', 'Pull Day', 'Legs + Core'];

    test('every PPL split × duration has a non-empty ordered slot list',
        () async {
      final repo = await loadedRepo();
      for (final split in splits) {
        for (final mins in durations) {
          final slots = repo.slotPlans.slotsFor(split, mins);
          expect(slots, isNotEmpty, reason: '$split @ $mins has no slots');
          expect(slots.every((s) => s.slotType != null), isTrue);
        }
      }
    });

    test('slot counts grow with duration (per prototype)', () async {
      final repo = await loadedRepo();
      // Push 5/6/7/8/9/9, Legs 5/6/7/8/8/9 — monotonic non-decreasing.
      for (final split in splits) {
        var prev = 0;
        for (final mins in durations) {
          final n = repo.slotPlans.slotsFor(split, mins).length;
          expect(n, greaterThanOrEqualTo(prev), reason: '$split @ $mins');
          prev = n;
        }
      }
    });

    test('every slot default resolves to a real library exercise', () async {
      final repo = await loadedRepo();
      for (final split in splits) {
        for (final mins in durations) {
          for (final slot in repo.slotPlans.slotsFor(split, mins)) {
            if (slot.defaultExercise != null) {
              expect(repo.getExerciseByName(slot.defaultExercise!), isNotNull,
                  reason: '$split@$mins ${slot.defaultExercise} missing');
            }
          }
        }
      }
    });

    test('Legs + Core places the core slot last at every duration', () async {
      final repo = await loadedRepo();
      for (final mins in durations) {
        final slots = repo.slotPlans.slotsFor('Legs + Core', mins);
        expect(slots.last.slotType, contains('core'),
            reason: 'core not last at $mins: '
                '${slots.map((s) => s.slotType).toList()}');
      }
    });

    test('Push triceps_push carries a random variant with probability 0.3',
        () async {
      final repo = await loadedRepo();
      final slots = repo.slotPlans.slotsFor('Push Day', 90);
      final tp = slots.firstWhere((s) => s.slotType == 'triceps_push');
      expect(tp.randomVariant, isNotNull);
      expect(tp.randomVariant!.probability, 0.3);
      // The alt swaps the category order toward compound press.
      expect(tp.randomVariant!.alt.categories.first, 'compound press');
    });
  });

  group('set-density table (2A)', () {
    test('primary compound sets match the prototype table', () async {
      final repo = await loadedRepo();
      final t = repo.setDensity;
      const expected = {45: 3, 60: 4, 75: 4, 90: 4, 105: 5, 120: 5};
      expected.forEach((mins, sets) {
        expect(t.setsFor(SlotRole.primaryCompound, mins), sets,
            reason: 'primary @ $mins');
      });
    });

    test('isolation applies the +1 display compensation', () async {
      final repo = await loadedRepo();
      // Raw isolation @45 is 2 in the table; displayed is 3.
      expect(repo.setDensity.setsFor(SlotRole.isolation, 45), 3);
      expect(repo.setDensity.setsFor(SlotRole.isolation, 120), 4);
    });

    test('core is exempt from the +1 compensation', () async {
      final repo = await loadedRepo();
      expect(repo.setDensity.setsFor(SlotRole.core, 45), 3);
      expect(repo.setDensity.setsFor(SlotRole.core, 120), 4);
    });

    test('unknown duration falls back to nearest tier', () async {
      final repo = await loadedRepo();
      expect(repo.setDensity.setsFor(SlotRole.primaryCompound, 63),
          repo.setDensity.setsFor(SlotRole.primaryCompound, 60));
    });
  });

  test('throws if used before load()', () {
    final repo = AssetExerciseRepository(jsonLoader: () async => '{}');
    expect(repo.getAllExercises, throwsStateError);
  });
}
