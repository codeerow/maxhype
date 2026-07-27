import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/fitness_plan.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/services/generator/workout_assembler.dart';
import 'package:maxhype/services/generator/workout_generator_service.dart';

Future<AssetWorkoutGeneratorService> service() async {
  final repo = AssetExerciseRepository(
    jsonLoader: () async =>
        File('assets/data/exercise_library.json').readAsString(),
  );
  await repo.load();
  return AssetWorkoutGeneratorService(repo);
}

const _splits = ['Push Day', 'Pull Day', 'Legs + Core'];
const _durations = [45, 60, 75, 90, 105, 120];
const _experiences = ExperienceLevel.values;

void main() {
  group('core invariants across every split × duration × experience', () {
    test('no duplicate exercises within a workout', () async {
      final svc = await service();
      for (final split in _splits) {
        for (final mins in _durations) {
          for (final exp in _experiences) {
            final w = svc.generate(
              GenerationRequest(
                splitName: split,
                durationMinutes: mins,
                experience: exp,
              ),
              seed: 100,
            );
            final names = w.exercises.map((e) => e.name).toList();
            expect(
              names.toSet().length,
              names.length,
              reason: 'dup in $split/$mins/${exp.name}: $names',
            );
          }
        }
      }
    });

    test('every exercise is eligible for the requested experience', () async {
      final svc = await service();
      for (final mins in _durations) {
        for (final exp in _experiences) {
          for (final split in _splits) {
            final w = svc.generate(
              GenerationRequest(
                splitName: split,
                durationMinutes: mins,
                experience: exp,
              ),
              seed: 7,
            );
            for (final e in w.exercises) {
              final meta = e.generatorMeta!;
              // Default-fallback picks can bypass eligibility, but generated
              // picks must respect min-experience + not be replaceOnly/excluded.
              if (!meta.replaceOnly && !meta.generatorExclude) {
                expect(
                  exp.rank,
                  greaterThanOrEqualTo(meta.minExperience.rank),
                  reason:
                      '${e.name} needs ${meta.minExperience.name} '
                      'but plan is ${exp.name}',
                );
                // Upper experience bound: a maxExperience-capped exercise (e.g.
                // Smith Machine at intermediate) must never be auto-generated
                // for a higher tier.
                final maxExp = meta.maxExperience;
                if (maxExp != null) {
                  expect(
                    exp.rank,
                    lessThanOrEqualTo(maxExp.rank),
                    reason:
                        '${e.name} capped at ${maxExp.name} '
                        'but plan is ${exp.name}',
                  );
                }
              }
            }
          }
        }
      }
    });

    test('workout is non-empty and fills most slots', () async {
      final svc = await service();
      final repo = AssetExerciseRepository(
        jsonLoader: () async =>
            File('assets/data/exercise_library.json').readAsString(),
      );
      await repo.load();
      for (final split in _splits) {
        for (final mins in _durations) {
          final slotCount = repo.slotPlans.slotsFor(split, mins).length;
          final w = svc.generate(
            GenerationRequest(
              splitName: split,
              durationMinutes: mins,
              experience: ExperienceLevel.intermediate,
            ),
            seed: 3,
          );
          expect(w.exercises, isNotEmpty);
          // Slots resolve to real exercises, but the movement-group HARD cap can
          // legitimately leave a slot short rather than duplicate a capped
          // super-group (e.g. Push 105 has two front-delt slots but the library
          // exposes only one front-raise super-group → the second stays empty,
          // faithful to the prototype, which likewise emits a short workout).
          // So fill count is at-most slotCount, and never more than one slot
          // short of it.
          expect(
            w.exercises.length,
            lessThanOrEqualTo(slotCount),
            reason: '$split/$mins produced more than $slotCount exercises',
          );
          expect(
            w.exercises.length,
            greaterThanOrEqualTo(slotCount - 1),
            reason: '$split/$mins filled only ${w.exercises.length}/$slotCount '
                '(more than one slot short)',
          );
        }
      }
    });

    test('set counts respect per-category caps', () async {
      final svc = await service();
      final repo = AssetExerciseRepository(
        jsonLoader: () async =>
            File('assets/data/exercise_library.json').readAsString(),
      );
      await repo.load();
      final tables = repo.metadataTables!;
      for (final mins in _durations) {
        for (final split in _splits) {
          final w = svc.generate(
            GenerationRequest(
              splitName: split,
              durationMinutes: mins,
              experience: ExperienceLevel.advanced,
            ),
            seed: 5,
          );
          for (final e in w.exercises) {
            final cat = e.generatorMeta?.category;
            if (cat != null) {
              final cap = tables.setLimitFor(cat, 6);
              expect(
                e.sets,
                lessThanOrEqualTo(cap),
                reason: '${e.name} ($cat) has ${e.sets} > cap $cap',
              );
            }
            expect(e.sets, greaterThanOrEqualTo(1));
          }
        }
      }
    });
  });

  group('duration & experience affect output', () {
    test('longer duration yields more total working sets', () async {
      final svc = await service();
      int volume(int mins) => svc
          .generate(
            GenerationRequest(
              splitName: 'Push Day',
              durationMinutes: mins,
              experience: ExperienceLevel.intermediate,
            ),
            seed: 1,
          )
          .exercises
          .fold<int>(0, (s, e) => s + e.sets);
      expect(volume(120), greaterThan(volume(45)));
    });

    test('none-experience never includes advanced-gated exercises', () async {
      final svc = await service();
      for (final split in _splits) {
        for (final mins in _durations) {
          final w = svc.generate(
            GenerationRequest(
              splitName: split,
              durationMinutes: mins,
              experience: ExperienceLevel.none,
            ),
            seed: 9,
          );
          for (final e in w.exercises) {
            final meta = e.generatorMeta!;
            if (!meta.replaceOnly && !meta.generatorExclude) {
              expect(
                meta.minExperience,
                ExperienceLevel.none,
                reason: '${e.name} gated above none in $split/$mins',
              );
            }
          }
        }
      }
    });
  });

  group('determinism', () {
    test('same seed → identical workout', () async {
      final svc = await service();
      GenerationRequest req(String s) => GenerationRequest(
        splitName: s,
        durationMinutes: 90,
        experience: ExperienceLevel.intermediate,
      );
      for (final split in _splits) {
        final a = svc.generate(req(split), seed: 42);
        final b = svc.generate(req(split), seed: 42);
        expect(
          a.exercises.map((e) => e.name).toList(),
          b.exercises.map((e) => e.name).toList(),
        );
      }
    });
  });

  group('core placement', () {
    test('Legs + Core ends with a core-category exercise', () async {
      final svc = await service();
      // The legs_core slot's "abs"/"core accessory" categories expand (via
      // COMPOSITE_CATEGORIES) to these real library categories.
      const coreCats = {
        'crunch',
        'dynamic core',
        'rotation',
        'leg raise',
        'plank',
        'back extension',
      };
      for (final mins in _durations) {
        for (final exp in _experiences) {
          final w = svc.generate(
            GenerationRequest(
              splitName: 'Legs + Core',
              durationMinutes: mins,
              experience: exp,
            ),
            seed: 11,
          );
          final last = w.exercises.last.generatorMeta!.category;
          expect(
            coreCats.contains(last),
            isTrue,
            reason: 'Legs+Core/$mins/${exp.name} ends with $last, not core',
          );
        }
      }
    });
  });

  group('plan → card set (WorkoutAssembler)', () {
    test('card count matches days per week, cycling P/P/L', () async {
      final svc = await service();
      final assembler = WorkoutAssembler(svc);
      final plan = FitnessPlan.defaults().copyWith(daysPerWeek: 5);
      final cards = assembler.buildCards(plan, seedBase: 1000);
      expect(cards.length, 5);
      expect(cards.map((c) => c.title).toList(), [
        'Push',
        'Pull',
        'Legs + Core',
        'Push',
        'Pull',
      ]);
      for (final c in cards) {
        expect(c.exercises, isNotEmpty);
        expect(c.exerciseCount, c.exercises.length);
        expect(c.targetMuscles, isNotEmpty);
      }
    });

    test('same plan + seedBase → identical cards (reproducible)', () async {
      final svc = await service();
      final assembler = WorkoutAssembler(svc);
      final plan = FitnessPlan.defaults().copyWith(daysPerWeek: 3);
      final a = assembler.buildCards(plan, seedBase: 55);
      final b = assembler.buildCards(plan, seedBase: 55);
      for (var i = 0; i < a.length; i++) {
        expect(
          a[i].exercises.map((e) => e.name),
          b[i].exercises.map((e) => e.name),
        );
      }
    });
  });

  group('planned prescription (pre-start placeholders)', () {
    test('every generated exercise carries planned reps (and non-negative '
        'weight) from the slot default', () async {
      final svc = await service();
      for (final split in _splits) {
        for (final mins in _durations) {
          final w = svc.generate(
            GenerationRequest(
              splitName: split,
              durationMinutes: mins,
              experience: ExperienceLevel.intermediate,
            ),
            seed: 4,
          );
          for (final e in w.exercises) {
            expect(
              e.reps,
              greaterThan(0),
              reason: '${e.name} has no planned reps → empty placeholder',
            );
            expect(e.weight, greaterThanOrEqualTo(0));
          }
        }
      }
    });
  });
}
