import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/exercise_taxonomy.dart';
import 'package:maxhype/models/generator/generator_metadata.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/services/generator/exercise_orderer.dart';
import 'package:maxhype/services/generator/workout_generator_service.dart';

/// Parity with the web's final ordering pass (`orderWorkoutExercises`,
/// script.js:5804-5980): compounds before isolation per section, canonical
/// block order per split, core last on Legs.
Exercise _ex(
  String name, {
  required String category,
  required ExerciseType type,
  String equipment = 'Barbell',
  String? movementGroup,
  String? primaryMuscle,
  String? movementPattern,
  String? hypertrophyRole,
}) {
  return Exercise(
    id: name,
    name: name,
    sets: 3,
    reps: 10,
    weight: 0,
    muscleGroups: const [],
    equipmentType: EquipmentType.barbell,
    rating: 0,
    generatorMeta: GeneratorMetadata(
      category: category,
      bodyPart: const BodyPart('Chest'),
      equipment: GeneratorEquipment(equipment),
      type: type,
      tier: ExerciseTier.a,
      minExperience: ExperienceLevel.none,
      movementGroup: movementGroup,
      primaryMuscle: primaryMuscle,
      movementPattern: movementPattern,
      hypertrophyRole: hypertrophyRole,
    ),
  );
}

List<String> _names(List<Exercise> list) => [for (final e in list) e.name];

void main() {
  const orderer = ExerciseOrderer();

  group('Push Day bucket rebuild', () {
    test('compounds lifted ahead of isolation; triceps last', () {
      // Deliberately authored in the Flutter 90-min slot order, where a chest
      // compound lands LAST and triceps precede a shoulder isolation.
      final input = [
        _ex(
          'Incline Bench',
          category: 'incline press',
          type: ExerciseType.compound,
        ),
        _ex('Incline Fly', category: 'chest fly', type: ExerciseType.isolation),
        _ex(
          'Shoulder Press',
          category: 'shoulder press',
          type: ExerciseType.compound,
        ),
        _ex(
          'Lateral Raise',
          category: 'side delt',
          type: ExerciseType.isolation,
          equipment: 'Dumbbell',
        ),
        _ex(
          'Skullcrushers',
          category: 'triceps',
          type: ExerciseType.isolation,
          movementGroup: 'skullcrusher',
        ),
        _ex(
          'Dips',
          category: 'compound press',
          type: ExerciseType.compound,
          movementGroup: 'tri_compound',
        ),
        _ex(
          'Front Raise',
          category: 'front delt',
          type: ExerciseType.isolation,
          equipment: 'Cable',
        ),
        _ex(
          'Bench Press',
          category: 'chest press',
          type: ExerciseType.compound,
        ),
      ];
      final out = _names(orderer.order('Push Day', input));
      expect(out, [
        'Bench Press', // chest compounds by priority (chest press 0 < incline 1)
        'Incline Bench',
        'Incline Fly', // chest isolation
        'Shoulder Press', // shoulder compounds
        'Lateral Raise', // shoulder iso: dumbbell before cable
        'Front Raise',
        'Dips', // triceps family: tri_compound before skullcrusher
        'Skullcrushers',
      ]);
    });

    test('shoulder isolation sorts dumbbell → machine → cable, then name', () {
      final input = [
        _ex(
          'C Raise',
          category: 'side delt',
          type: ExerciseType.isolation,
          equipment: 'Cable',
        ),
        _ex(
          'M Raise',
          category: 'side delt',
          type: ExerciseType.isolation,
          equipment: 'Machine',
        ),
        _ex(
          'B Front',
          category: 'front delt',
          type: ExerciseType.isolation,
          equipment: 'Barbell',
        ),
        _ex(
          'D Raise',
          category: 'side delt',
          type: ExerciseType.isolation,
          equipment: 'Dumbbell',
        ),
      ];
      final out = _names(orderer.order('Push Day', input));
      // Barbell has no equipment rank (9) → last; others by equipment order.
      expect(out, ['D Raise', 'M Raise', 'C Raise', 'B Front']);
    });

    test('triceps family order with compound-first inside a family', () {
      final input = [
        _ex(
          'Kickback',
          category: 'triceps',
          type: ExerciseType.isolation,
          movementGroup: 'tri_kickback',
        ),
        _ex(
          'Pushdown',
          category: 'triceps',
          type: ExerciseType.isolation,
          movementGroup: 'tri_pushdown',
        ),
        _ex(
          'Overhead Ext',
          category: 'triceps',
          type: ExerciseType.isolation,
          movementGroup: 'tri_overhead',
        ),
        _ex(
          'Close Grip Bench',
          category: 'compound press',
          type: ExerciseType.compound,
          movementGroup: 'tri_compound',
        ),
      ];
      final out = _names(orderer.order('Push Day', input));
      expect(out, ['Close Grip Bench', 'Overhead Ext', 'Pushdown', 'Kickback']);
    });
  });

  group('Pull Day block order', () {
    test(
      'upper_back → lats → rear_delt → biceps → support, compounds first',
      () {
        final input = [
          _ex('Curl', category: 'biceps', type: ExerciseType.isolation),
          _ex('Shrug', category: 'shrug', type: ExerciseType.isolation),
          _ex('Face Pull', category: 'rear delt', type: ExerciseType.isolation),
          _ex('Pulldown', category: 'pulldown', type: ExerciseType.compound),
          _ex(
            'Upright Row',
            category: 'upright row',
            type: ExerciseType.compound,
          ),
          _ex('Barbell Row', category: 'row', type: ExerciseType.compound),
        ];
        final out = _names(orderer.order('Pull Day', input));
        // upper_back block: both compounds, priority row(0) < upright row(6).
        expect(out, [
          'Barbell Row',
          'Upright Row',
          'Pulldown',
          'Face Pull',
          'Curl',
          'Shrug',
        ]);
      },
    );
  });

  group('Legs + Core phase order', () {
    Exercise leg(
      String name, {
      required String category,
      required ExerciseType type,
      required String pm,
      required String mp,
      required String role,
    }) => _ex(
      name,
      category: category,
      type: type,
      primaryMuscle: pm,
      movementPattern: mp,
      hypertrophyRole: role,
    );

    test(
      'squat/lunge -> hinge/hip thrust -> leg isolation -> calves -> core',
      () {
        final input = [
          leg(
            'Crunch',
            category: 'abs',
            type: ExerciseType.isolation,
            pm: 'abs',
            mp: 'crunch',
            role: 'isolation',
          ),
          leg(
            'Calf Raise',
            category: 'calf raise',
            type: ExerciseType.isolation,
            pm: 'calves',
            mp: 'calf_raise',
            role: 'isolation',
          ),
          leg(
            'Leg Extension',
            category: 'quad',
            type: ExerciseType.isolation,
            pm: 'quads',
            mp: 'knee_extension',
            role: 'isolation',
          ),
          leg(
            'Hip Thrust',
            category: 'hip thrust',
            type: ExerciseType.compound,
            pm: 'glutes',
            mp: 'hip_thrust',
            role: 'secondary_compound',
          ),
          leg(
            'Ham Curl',
            category: 'hamstring curl',
            type: ExerciseType.isolation,
            pm: 'hamstrings',
            mp: 'knee_flexion',
            role: 'isolation',
          ),
          leg(
            'Deadlift',
            category: 'hinge',
            type: ExerciseType.compound,
            pm: 'hamstrings',
            mp: 'hinge',
            role: 'primary_compound',
          ),
          leg(
            'Squat',
            category: 'squat',
            type: ExerciseType.compound,
            pm: 'quads',
            mp: 'squat',
            role: 'primary_compound',
          ),
        ];
        final out = _names(orderer.order('Legs + Core', input));
        expect(out, [
          'Squat', // phase 1
          'Deadlift', // phase 2: hinge
          'Hip Thrust', // phase 2: hip thrust
          'Leg Extension', // phase 3: isolations, quad iso first (stable)
          'Ham Curl',
          'Calf Raise', // phase 4
          'Crunch', // phase 5: core strictly last
        ]);
      },
    );

    test("customer's reference sequence orders exactly as specified", () {
      // "Back Squat -> Walking Lunge -> Romanian Deadlift -> Hip Thrust ->
      //  Leg Extension -> Seated Leg Curl -> Calf Raise -> Core" - fed in
      // scrambled, the phase pass must reproduce it.
      final input = [
        leg(
          'Seated Leg Curl',
          category: 'hamstring curl',
          type: ExerciseType.isolation,
          pm: 'hamstrings',
          mp: 'knee_flexion',
          role: 'isolation',
        ),
        leg(
          'Core Work',
          category: 'abs',
          type: ExerciseType.isolation,
          pm: 'abs',
          mp: 'crunch',
          role: 'isolation',
        ),
        leg(
          'Back Squat',
          category: 'squat',
          type: ExerciseType.compound,
          pm: 'quads',
          mp: 'squat',
          role: 'primary_compound',
        ),
        leg(
          'Calf Raise',
          category: 'calf raise',
          type: ExerciseType.isolation,
          pm: 'calves',
          mp: 'calf_raise',
          role: 'isolation',
        ),
        leg(
          'Romanian Deadlift',
          category: 'hinge',
          type: ExerciseType.compound,
          pm: 'hamstrings',
          mp: 'hinge',
          role: 'primary_compound',
        ),
        leg(
          'Leg Extension',
          category: 'quad',
          type: ExerciseType.isolation,
          pm: 'quads',
          mp: 'knee_extension',
          role: 'isolation',
        ),
        leg(
          'Walking Lunge',
          category: 'lunge',
          type: ExerciseType.compound,
          pm: 'quads',
          mp: 'lunge',
          role: 'secondary_compound',
        ),
        leg(
          'Hip Thrust',
          category: 'hip thrust',
          type: ExerciseType.compound,
          pm: 'glutes',
          mp: 'hip_thrust',
          role: 'secondary_compound',
        ),
      ];
      final out = _names(orderer.order('Legs + Core', input));
      expect(out, [
        'Back Squat',
        'Walking Lunge',
        'Romanian Deadlift',
        'Hip Thrust',
        'Leg Extension',
        'Seated Leg Curl',
        'Calf Raise',
        'Core Work',
      ]);
    });

    test('metadata-less exercise lands before core, never after', () {
      final input = [
        Exercise(
          id: 'x',
          name: 'Custom Move',
          sets: 3,
          reps: 10,
          weight: 0,
          muscleGroups: const [],
          equipmentType: EquipmentType.barbell,
          rating: 0,
        ),
        leg(
          'Crunch',
          category: 'abs',
          type: ExerciseType.isolation,
          pm: 'abs',
          mp: 'crunch',
          role: 'isolation',
        ),
        leg(
          'Squat',
          category: 'squat',
          type: ExerciseType.compound,
          pm: 'quads',
          mp: 'squat',
          role: 'primary_compound',
        ),
      ];
      final out = _names(orderer.order('Legs + Core', input));
      expect(out, ['Squat', 'Custom Move', 'Crunch']);
    });
  });

  group('generated workouts respect the canonical order', () {
    late AssetWorkoutGeneratorService svc;

    setUpAll(() async {
      final repo = AssetExerciseRepository(
        jsonLoader: () async =>
            File('assets/data/exercise_library.json').readAsString(),
      );
      await repo.load();
      svc = AssetWorkoutGeneratorService(repo);
    });

    int pushBucketOf(Exercise e) {
      final cat = e.generatorMeta!.category;
      final compound = e.generatorMeta!.type == ExerciseType.compound;
      const chest = {
        'chest press',
        'incline press',
        'decline press',
        'chest fly',
      };
      const shoulders = {'shoulder press', 'front delt', 'side delt'};
      const tri = {'triceps', 'compound press'};
      if (tri.contains(cat)) return 4;
      if (chest.contains(cat)) return compound ? 0 : 1;
      if (shoulders.contains(cat)) return compound ? 2 : 3;
      return 5;
    }

    test('Push: bucket order is monotonic across seeds and durations', () {
      for (final minutes in const [60, 90, 120]) {
        for (var seed = 2000; seed < 2020; seed++) {
          final w = svc.generate(
            GenerationRequest(
              splitName: 'Push Day',
              durationMinutes: minutes,
              experience: ExperienceLevel.advanced,
            ),
            seed: seed,
          );
          final buckets = w.exercises.map(pushBucketOf).toList();
          for (var i = 1; i < buckets.length; i++) {
            expect(
              buckets[i] >= buckets[i - 1],
              isTrue,
              reason:
                  'Push@$minutes seed=$seed out of order: '
                  '${w.exercises.map((e) => e.name).toList()}',
            );
          }
        }
      }
    });

    test(
      'Legs: generated workouts follow the phase sequence '
      '(squat/lunge → hinge/hip thrust → isolation → calves → core)',
      () {
        for (final experience in ExperienceLevel.values) {
          for (final minutes in const [60, 90, 120]) {
            for (var seed = 3000; seed < 3015; seed++) {
              final w = svc.generate(
                GenerationRequest(
                  splitName: 'Legs + Core',
                  durationMinutes: minutes,
                  experience: experience,
                ),
                seed: seed,
              );
              final phases = [
                for (final e in w.exercises) ExerciseOrderer.legsPhaseFor(e),
              ];
              // Non-decreasing phases (99 never occurs in generated output).
              for (var i = 1; i < phases.length; i++) {
                expect(
                  phases[i] >= phases[i - 1],
                  isTrue,
                  reason:
                      'phase regression at ${experience.name}@$minutes '
                      'seed=$seed: '
                      '${w.exercises.map((e) => '${e.name}(${ExerciseOrderer.legsPhaseFor(e)})').toList()}',
                );
                expect(phases[i], isNot(99));
              }
              // Core (phase 5) is always last: present and terminal.
              expect(phases.last, 5, reason: 'core must close the workout');
            }
          }
        }
      },
    );

    test('Legs: ordering is stable within each phase (deterministic + '
        'group-pass order preserved)', () {
      const quadIso = {'quad'};
      const hamIso = {'hamstring curl'};
      for (var seed = 3000; seed < 3020; seed++) {
        const req = GenerationRequest(
          splitName: 'Legs + Core',
          durationMinutes: 90,
          experience: ExperienceLevel.advanced,
        );
        final a = svc.generate(req, seed: seed);
        final b = svc.generate(req, seed: seed);
        // Same seed → identical order (stability/determinism).
        expect(
          a.exercises.map((e) => e.name).toList(),
          b.exercises.map((e) => e.name).toList(),
        );
        // Within phase 3, the group-pass relative order holds: every quad
        // isolation precedes every hamstring isolation (executed-web parity).
        final phase3 = a.exercises
            .where((e) => ExerciseOrderer.legsPhaseFor(e) == 3)
            .toList();
        final lastQuad = phase3.lastIndexWhere(
          (e) => quadIso.contains(e.generatorMeta?.category),
        );
        final firstHam = phase3.indexWhere(
          (e) => hamIso.contains(e.generatorMeta?.category),
        );
        if (lastQuad != -1 && firstHam != -1) {
          expect(
            lastQuad < firstHam,
            isTrue,
            reason:
                'quad isolations must precede hamstring isolations '
                'within phase 3 (seed=$seed): '
                '${phase3.map((e) => e.name).toList()}',
          );
        }
      }
    });

    test('Legs: core block is strictly last', () {
      const coreCats = {'abs', 'core accessory', 'back extension'};
      for (var seed = 2000; seed < 2030; seed++) {
        final w = svc.generate(
          const GenerationRequest(
            splitName: 'Legs + Core',
            durationMinutes: 90,
            experience: ExperienceLevel.advanced,
          ),
          seed: seed,
        );
        var seenCore = false;
        for (final e in w.exercises) {
          final isCore = coreCats.contains(e.generatorMeta?.category);
          if (seenCore) {
            expect(
              isCore,
              isTrue,
              reason:
                  'non-core after core (seed=$seed): '
                  '${w.exercises.map((x) => x.name).toList()}',
            );
          }
          seenCore = seenCore || isCore;
        }
      }
    });
  });
}
