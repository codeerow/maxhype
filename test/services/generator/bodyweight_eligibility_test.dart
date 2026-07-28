import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/services/generator/workout_generator_service.dart';

/// Parity with the web's bodyweight auto-generation gate
/// (`getAvailableForSlot`, script.js:12077-12095).
///
/// A `Bodyweight`-equipment exercise may be auto-generated only if:
///   * its category is an inherently-bodyweight core category
///     (crunch / dynamic core / rotation / leg raise / plank /
///     back extension), or
///   * it is whitelisted with an experience floor: Dips (intermediate+),
///     Chin Ups (advanced only).
///
/// Everything else (bodyweight Calf Raise, Lunge, Walking Lunge, Kickback,
/// Bodyweight Squats, ...) is skipped by automatic selection but remains
/// fully available for manual Replace — verified empirically against the web
/// engine (64+ headless builds: zero non-whitelisted bodyweight picks).
Future<AssetExerciseRepository> loadedRepo() async {
  final repo = AssetExerciseRepository(
    jsonLoader: () async =>
        File('assets/data/exercise_library.json').readAsString(),
  );
  await repo.load();
  return repo;
}

const _coreCategories = {
  'crunch',
  'dynamic core',
  'rotation',
  'leg raise',
  'plank',
  'back extension',
};

const _splits = ['Push Day', 'Pull Day', 'Legs + Core'];

void main() {
  late AssetExerciseRepository repo;
  late AssetWorkoutGeneratorService svc;

  setUpAll(() async {
    repo = await loadedRepo();
    svc = AssetWorkoutGeneratorService(repo);
  });

  group('bodyweight auto-eligibility predicate', () {
    test('non-bodyweight equipment is unaffected', () {
      final ex = repo.getExerciseByName('Barbell Bench Press')!;
      for (final level in ExperienceLevel.values) {
        expect(
          ex.generatorMeta!.isBodyweightAutoEligible(ex.name, level),
          isTrue,
        );
      }
    });

    test('core-category bodyweight movements stay auto-generatable', () {
      final coreBw = repo
          .getAllExercises()
          .where(
            (e) =>
                e.generatorMeta?.equipment.label == 'Bodyweight' &&
                _coreCategories.contains(e.generatorMeta?.category),
          )
          .toList();
      expect(
        coreBw,
        isNotEmpty,
        reason: 'library should contain bodyweight core movements',
      );
      for (final ex in coreBw) {
        for (final level in ExperienceLevel.values) {
          expect(
            ex.generatorMeta!.isBodyweightAutoEligible(ex.name, level),
            isTrue,
            reason:
                '${ex.name} (${ex.generatorMeta!.category}) '
                'is core-category bodyweight',
          );
        }
      }
    });

    test('Dips: intermediate and above only', () {
      final meta = repo.getExerciseByName('Dips')!.generatorMeta!;
      expect(
        meta.isBodyweightAutoEligible('Dips', ExperienceLevel.none),
        isFalse,
      );
      expect(
        meta.isBodyweightAutoEligible('Dips', ExperienceLevel.beginner),
        isFalse,
      );
      expect(
        meta.isBodyweightAutoEligible('Dips', ExperienceLevel.intermediate),
        isTrue,
      );
      expect(
        meta.isBodyweightAutoEligible('Dips', ExperienceLevel.advanced),
        isTrue,
      );
    });

    test('Chin Ups: advanced only', () {
      final meta = repo.getExerciseByName('Chin Ups')!.generatorMeta!;
      for (final level in const [
        ExperienceLevel.none,
        ExperienceLevel.beginner,
        ExperienceLevel.intermediate,
      ]) {
        expect(
          meta.isBodyweightAutoEligible('Chin Ups', level),
          isFalse,
          reason: 'Chin Ups gated below advanced (${level.name})',
        );
      }
      expect(
        meta.isBodyweightAutoEligible('Chin Ups', ExperienceLevel.advanced),
        isTrue,
      );
    });

    test('non-core, non-whitelisted bodyweight is never auto-eligible', () {
      for (final name in const [
        'Calf Raise',
        'Lunge',
        'Walking Lunge',
        'Kickback',
      ]) {
        final ex = repo.getExerciseByName(name);
        expect(ex, isNotNull, reason: '$name should exist in the library');
        expect(
          ex!.generatorMeta!.equipment.label,
          'Bodyweight',
          reason: '$name is the bodyweight variant',
        );
        for (final level in ExperienceLevel.values) {
          expect(
            ex.generatorMeta!.isBodyweightAutoEligible(name, level),
            isFalse,
            reason: '$name must never be auto-generated (${level.name})',
          );
        }
      }
    });
  });

  group('generation runs never leak blocked bodyweight picks', () {
    bool allowedBodyweight(
      String name,
      String? category,
      ExperienceLevel level,
    ) {
      if (_coreCategories.contains(category)) return true;
      if (name == 'Dips') {
        return level.rank >= ExperienceLevel.intermediate.rank;
      }
      if (name == 'Chin Ups') {
        return level.rank >= ExperienceLevel.advanced.rank;
      }
      return false;
    }

    for (final level in ExperienceLevel.values) {
      test('8-week PPL run at ${level.name} (seed 1000, 90 min)', () {
        final offenders = <String>[];
        for (var session = 0; session < 24; session++) {
          final split = _splits[session % _splits.length];
          final w = svc.generate(
            GenerationRequest(
              splitName: split,
              durationMinutes: 90,
              experience: level,
            ),
            seed: 1000 + session,
          );
          for (final ex in w.exercises) {
            final meta = ex.generatorMeta;
            if (meta?.equipment.label != 'Bodyweight') continue;
            if (!allowedBodyweight(ex.name, meta?.category, level)) {
              offenders.add('$split/${level.name}: ${ex.name}');
            }
          }
        }
        expect(
          offenders,
          isEmpty,
          reason: 'blocked bodyweight picks leaked: $offenders',
        );
      });
    }

    test('Chin Ups never appears below advanced across durations', () {
      for (final level in const [
        ExperienceLevel.none,
        ExperienceLevel.beginner,
        ExperienceLevel.intermediate,
      ]) {
        for (final minutes in const [60, 90, 120]) {
          for (var seed = 500; seed < 520; seed++) {
            final w = svc.generate(
              GenerationRequest(
                splitName: 'Pull Day',
                durationMinutes: minutes,
                experience: level,
              ),
              seed: seed,
            );
            expect(
              w.exercises.map((e) => e.name),
              isNot(contains('Chin Ups')),
              reason: 'Chin Ups leaked at ${level.name}@$minutes seed=$seed',
            );
          }
        }
      }
    });
  });
}
