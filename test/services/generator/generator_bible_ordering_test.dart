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

/// Regression tests for the Generator Bible's Legs + Core ordering rules
/// (docs/generator/MAXHYPE_GENERATOR_BIBLE_V2.md, "Ordering Philosophy" and
/// the V2.1 isolation-phase implementation note):
///
///   1. Squat/primary bilateral
///   2. Secondary compound/unilateral
///   3. Hinge
///   4. Quad isolation
///   5. Hamstring isolation
///   6. Calves
///   7. Core
///
/// These tests verify the Bible itself, not today's implementation details:
///
/// * The unit group feeds the orderer exercises whose `category` is UNKNOWN
///   to SECTION_PRIORITY / SECTION_GROUPS, so the group-block pass cannot
///   contribute any ordering. Only the Bible phase classification
///   (movement pattern / primary muscle) can produce the expected order —
///   the tests fail if phase ordering regresses, no matter how
///   SECTION_PRIORITY changes.
/// * The generated group asserts the same rules on real generator output by
///   exercise metadata (never by phase numbers or priority tables).
Exercise _leg(
  String name, {
  required String mp,
  required String pm,
  required String role,
  ExerciseType type = ExerciseType.compound,
  String category = 'uncategorized',
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
      bodyPart: const BodyPart('Legs'),
      equipment: const GeneratorEquipment('Barbell'),
      type: type,
      tier: ExerciseTier.a,
      minExperience: ExperienceLevel.none,
      primaryMuscle: pm,
      movementPattern: mp,
      hypertrophyRole: role,
    ),
  );
}

Exercise _squat() =>
    _leg('Back Squat', mp: 'squat', pm: 'quads', role: 'primary_compound');
Exercise _legPress() =>
    _leg('Leg Press', mp: 'leg_press', pm: 'quads', role: 'primary_compound');
Exercise _lunge() =>
    _leg('Lunge', mp: 'lunge', pm: 'quads', role: 'secondary_compound');
Exercise _splitSquat() => _leg(
  'Bulgarian Split Squat',
  mp: 'lunge',
  pm: 'quads',
  role: 'secondary_compound',
);
Exercise _stepUp() =>
    _leg('Step Up', mp: 'lunge', pm: 'quads', role: 'secondary_compound');
Exercise _quadIso() => _leg(
  'Leg Extension',
  mp: 'knee_extension',
  pm: 'quads',
  role: 'isolation',
  type: ExerciseType.isolation,
);
Exercise _hamIso() => _leg(
  'Seated Leg Curl',
  mp: 'knee_flexion',
  pm: 'hamstrings',
  role: 'isolation',
  type: ExerciseType.isolation,
);

List<String> _names(List<Exercise> list) => [for (final e in list) e.name];

void main() {
  const orderer = ExerciseOrderer();

  group('Bible Legs+Core ordering — unit, immune to SECTION_PRIORITY', () {
    List<String> ordered(List<Exercise> input) =>
        _names(orderer.order('Legs + Core', input));

    test('squat before lunge', () {
      expect(ordered([_lunge(), _squat()]), ['Back Squat', 'Lunge']);
    });

    test('squat before split squat', () {
      expect(ordered([_splitSquat(), _squat()]), [
        'Back Squat',
        'Bulgarian Split Squat',
      ]);
    });

    test('squat before step-up', () {
      expect(ordered([_stepUp(), _squat()]), ['Back Squat', 'Step Up']);
    });

    test('leg press (primary bilateral) before the lunge family', () {
      // Bible phase 1 vs phase 2. Today's slot plans never co-select a leg
      // press and a lunge-family movement, so generation cannot exercise
      // this pair — but the Bible mandates the order, and the phase pass
      // must guarantee it if selection ever changes.
      expect(ordered([_lunge(), _legPress()]), ['Leg Press', 'Lunge']);
      expect(ordered([_stepUp(), _legPress()]), ['Leg Press', 'Step Up']);
    });

    test('quad isolation before hamstring isolation', () {
      expect(ordered([_hamIso(), _quadIso()]), [
        'Leg Extension',
        'Seated Leg Curl',
      ]);
    });

    test('full scrambled Bible flow reassembles in spec order', () {
      final input = [
        _hamIso(),
        _stepUp(),
        _leg(
          'Crunch',
          mp: 'crunch',
          pm: 'abs',
          role: 'isolation',
          type: ExerciseType.isolation,
        ),
        _quadIso(),
        _leg(
          'Calf Raise',
          mp: 'calf_raise',
          pm: 'calves',
          role: 'isolation',
          type: ExerciseType.isolation,
        ),
        _splitSquat(),
        _leg(
          'Romanian Deadlift',
          mp: 'hinge',
          pm: 'hamstrings',
          role: 'primary_compound',
        ),
        _lunge(),
        _leg(
          'Hip Thrust',
          mp: 'hip_thrust',
          pm: 'glutes',
          role: 'secondary_compound',
        ),
        _squat(),
      ];
      expect(orderer.order('Legs + Core', input).map((e) => e.name).toList(), [
        'Back Squat',
        'Step Up',
        'Bulgarian Split Squat',
        'Lunge',
        'Romanian Deadlift',
        'Hip Thrust',
        'Leg Extension',
        'Seated Leg Curl',
        'Calf Raise',
        'Crunch',
      ]);
    });
  });

  group('Bible Legs+Core ordering — generated workouts', () {
    late AssetWorkoutGeneratorService svc;

    setUpAll(() async {
      final repo = AssetExerciseRepository(
        jsonLoader: () async =>
            File('assets/data/exercise_library.json').readAsString(),
      );
      await repo.load();
      svc = AssetWorkoutGeneratorService(repo);
    });

    // Bible groupings by library metadata, not by implementation tables.
    bool isPrimaryBilateral(Exercise e) {
      final mp = e.generatorMeta?.movementPattern;
      return mp == 'squat' || mp == 'leg_press';
    }

    bool isLungeFamily(Exercise e) =>
        e.generatorMeta?.movementPattern == 'lunge';

    bool isHingeFamily(Exercise e) {
      final mp = e.generatorMeta?.movementPattern;
      return mp == 'hinge' || mp == 'hip_thrust';
    }

    bool isQuadIso(Exercise e) {
      final mp = e.generatorMeta?.movementPattern;
      return mp == 'knee_extension' || mp == 'leg_extension';
    }

    bool isHamIso(Exercise e) {
      final mp = e.generatorMeta?.movementPattern;
      return mp == 'knee_flexion' || mp == 'hamstring_curl';
    }

    test(
      'squat/primary bilateral → lunge family → hinge; '
      'quad iso → ham iso — across seeds, durations, experiences',
      () {
        void mustPrecede(
          GeneratedWorkout w,
          bool Function(Exercise) earlier,
          bool Function(Exercise) later,
          String rule,
          String cfg,
        ) {
          final names = w.exercises.map((e) => e.name).toList();
          final lastEarlier = w.exercises.lastIndexWhere(earlier);
          final firstLater = w.exercises.indexWhere(later);
          if (lastEarlier == -1 || firstLater == -1) return;
          expect(
            lastEarlier < firstLater,
            isTrue,
            reason: 'Bible rule "$rule" violated at $cfg: $names',
          );
        }

        for (final exp in ExperienceLevel.values) {
          for (final mins in const [45, 60, 75, 90, 105, 120]) {
            for (var seed = 0; seed < 100; seed++) {
              final w = svc.generate(
                GenerationRequest(
                  splitName: 'Legs + Core',
                  durationMinutes: mins,
                  experience: exp,
                ),
                seed: seed,
              );
              final cfg = '${exp.name}@$mins seed=$seed';
              mustPrecede(
                w,
                isPrimaryBilateral,
                isLungeFamily,
                'squat/primary bilateral before lunge/split squat/step-up',
                cfg,
              );
              mustPrecede(
                w,
                isLungeFamily,
                isHingeFamily,
                'lunge family before hinge/hip thrust',
                cfg,
              );
              mustPrecede(
                w,
                isPrimaryBilateral,
                isHingeFamily,
                'squat/primary bilateral before hinge/hip thrust',
                cfg,
              );
              mustPrecede(
                w,
                isQuadIso,
                isHamIso,
                'quad isolation before hamstring isolation',
                cfg,
              );
            }
          }
        }
      },
    );

    test('split squats and step-ups specifically follow every squat', () {
      // Gary's explicit regression list, asserted by category so the test
      // reads like the Bible even if movement patterns are ever remapped.
      for (var seed = 0; seed < 300; seed++) {
        final w = svc.generate(
          const GenerationRequest(
            splitName: 'Legs + Core',
            durationMinutes: 90,
            experience: ExperienceLevel.advanced,
          ),
          seed: seed,
        );
        final lastSquat = w.exercises.lastIndexWhere(
          (e) => e.generatorMeta?.category == 'squat',
        );
        for (final cat in const ['lunge', 'step up']) {
          final first = w.exercises.indexWhere(
            (e) => e.generatorMeta?.category == cat,
          );
          if (lastSquat != -1 && first != -1) {
            expect(
              lastSquat < first,
              isTrue,
              reason:
                  'squat must precede $cat (seed=$seed): '
                  '${w.exercises.map((e) => e.name).toList()}',
            );
          }
        }
      }
    });
  });
}
