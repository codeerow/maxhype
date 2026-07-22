import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/generator/exercise_taxonomy.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/generator_metadata.dart';
import 'package:maxhype/models/generator/generator_slot.dart';
import 'package:maxhype/services/generator/build_state.dart';
import 'package:maxhype/services/generator/exercise_scorer.dart';

/// Builds a generator-backed exercise with just the metadata the scorer reads.
Exercise ex(
  String name, {
  required String category,
  required String equipment,
  ExerciseType type = ExerciseType.compound,
  ExerciseTier tier = ExerciseTier.a,
  String? movementGroup,
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
      type: type,
      tier: tier,
      minExperience: ExperienceLevel.none,
      movementGroup: movementGroup,
    ),
  );
}

BuildState stateWith(List<Exercise> committed, {String split = 'Push Day'}) {
  final s = BuildState(split);
  for (final e in committed) {
    s.commit(e, movementGroup: e.generatorMeta?.movementGroup);
  }
  return s;
}

const _scorer = ExerciseScorer();
const _slot = GeneratorSlot(category: 'chest press');

void main() {
  group('movement-group diversity (all levels)', () {
    test('fresh group +3, repeated group -15', () {
      final fresh = ex(
        'Bench Press',
        category: 'chest press',
        equipment: 'Barbell',
        movementGroup: 'flat_press',
      );
      // Empty build: flat_press is fresh → +3, plus beginner Barbell -5 = -2.
      final base = _scorer.scoreOf(
        fresh,
        _slot,
        stateWith([]),
        ExperienceLevel.beginner,
      );
      expect(base, -2); // +3 fresh MG, -5 beginner barbell

      // Now flat_press already used → -15 instead of +3, so -20.
      final used = stateWith([
        ex(
          'Incline Bench',
          category: 'incline press',
          equipment: 'Barbell',
          movementGroup: 'flat_press',
        ),
      ]);
      final repeated = _scorer.scoreOf(
        fresh,
        _slot,
        used,
        ExperienceLevel.beginner,
      );
      // Barbell -5, repeated MG -15 = -20.
      expect(repeated, -20);
    });
  });

  group('scoreBeginnerEquipment (none/beginner only)', () {
    test('Smith Machine +8 under cap, -50 at cap', () {
      final smith = ex(
        'Smith Press',
        category: 'chest press',
        equipment: 'Smith Machine',
      );
      // No movement group → 0 diversity. Fresh build.
      expect(
        _scorer.scoreOf(smith, _slot, stateWith([]), ExperienceLevel.beginner),
        8,
      );
      // Two Smith machines already committed → soft-block -50.
      final saturated = stateWith([
        ex('Smith A', category: 'row', equipment: 'Smith Machine'),
        ex('Smith B', category: 'squat', equipment: 'Smith Machine'),
      ]);
      expect(
        _scorer.scoreOf(smith, _slot, saturated, ExperienceLevel.beginner),
        -50,
      );
    });

    test('Barbell -5 for beginners', () {
      final bb = ex('BB Curl', category: 'biceps', equipment: 'Barbell');
      expect(
        _scorer.scoreOf(bb, _slot, stateWith([]), ExperienceLevel.beginner),
        -5,
      );
    });

    test('does not apply at intermediate/advanced', () {
      final bb = ex('BB Curl', category: 'biceps', equipment: 'Barbell');
      // Intermediate: beginner rule off, advanced rule off (not advanced) → 0.
      expect(
        _scorer.scoreOf(bb, _slot, stateWith([]), ExperienceLevel.intermediate),
        0,
      );
    });
  });

  group('scoreAdvancedEquipment (advanced only)', () {
    test('free-weight compound +10, isolation +4', () {
      final compound = ex(
        'Bench',
        category: 'chest press',
        equipment: 'Barbell',
      );
      final iso = ex(
        'DB Fly',
        category: 'chest fly',
        equipment: 'Dumbbell',
        type: ExerciseType.isolation,
      );
      expect(
        _scorer.scoreOf(
          compound,
          _slot,
          stateWith([]),
          ExperienceLevel.advanced,
        ),
        10,
      );
      expect(
        _scorer.scoreOf(iso, _slot, stateWith([]), ExperienceLevel.advanced),
        4,
      );
    });

    test('free-weight diversity +5 when the missing type appears', () {
      final db = ex('DB Press', category: 'chest press', equipment: 'Dumbbell');
      // A barbell compound already present, no dumbbell yet → +10 (fw compound)
      // + 5 (diversity) = 15.
      final withBarbell = stateWith([
        ex('BB Press', category: 'chest press', equipment: 'Barbell'),
      ]);
      expect(
        _scorer.scoreOf(db, _slot, withBarbell, ExperienceLevel.advanced),
        15,
      );
    });

    test('machine compound -6, supported_row only -3', () {
      final machine = ex(
        'Machine Press',
        category: 'chest press',
        equipment: 'Machine',
      );
      final supportedRow = ex(
        'Chest Supported Row',
        category: 'row',
        equipment: 'Machine',
        movementGroup: 'supported_row',
      );
      // machine has no movement group → pure equipment score -6.
      expect(
        _scorer.scoreOf(
          machine,
          _slot,
          stateWith([]),
          ExperienceLevel.advanced,
        ),
        -6,
      );
      // supported_row carries a fresh movement group → -3 (equipment) + 3
      // (fresh-MG diversity) = 0. The softened row penalty is what keeps it
      // above the -6 a generic machine compound would get.
      expect(
        _scorer.scoreOf(
          supportedRow,
          _slot,
          stateWith([]),
          ExperienceLevel.advanced,
        ),
        0,
      );
    });

    test('machine/plate dominance guard -25 when ≥2 machines present', () {
      final machineIso = ex(
        'Machine Fly',
        category: 'chest fly',
        equipment: 'Machine',
        type: ExerciseType.isolation,
      );
      final twoMachines = stateWith([
        ex('M1', category: 'row', equipment: 'Machine'),
        ex('M2', category: 'quad', equipment: 'Plate-Loaded'),
      ]);
      // Isolation machine: no +10/+4/penalty for compound, but dominance -25.
      expect(
        _scorer.scoreOf(
          machineIso,
          _slot,
          twoMachines,
          ExperienceLevel.advanced,
        ),
        -25,
      );
    });
  });

  group('scoreShoulderCandidate (advanced only)', () {
    test('+12 free-weight press when none present, -10 machine', () {
      final dbPress = ex(
        'DB Shoulder Press',
        category: 'shoulder press',
        equipment: 'Dumbbell',
      );
      final machinePress = ex(
        'Machine Shoulder Press',
        category: 'shoulder press',
        equipment: 'Machine',
      );
      // Free-weight compound: +10 (advanced fw) +12 (shoulder) = 22.
      expect(
        _scorer.scoreOf(
          dbPress,
          _slot,
          stateWith([]),
          ExperienceLevel.advanced,
        ),
        22,
      );
      // Machine compound: -6 (machine compound) -10 (shoulder machine) = -16.
      expect(
        _scorer.scoreOf(
          machinePress,
          _slot,
          stateWith([]),
          ExperienceLevel.advanced,
        ),
        -16,
      );
    });

    test('no shoulder bonus once a free-weight press exists', () {
      final machinePress = ex(
        'Machine Shoulder Press',
        category: 'shoulder press',
        equipment: 'Machine',
      );
      final withFwPress = stateWith([
        ex('BB OHP', category: 'shoulder press', equipment: 'Barbell'),
      ]);
      // Machine compound -6, shoulder rule now returns 0 → -6.
      expect(
        _scorer.scoreOf(
          machinePress,
          _slot,
          withFwPress,
          ExperienceLevel.advanced,
        ),
        -6,
      );
    });
  });

  group('scoreDipsCandidate (advanced only, "Dips" only)', () {
    Exercise dips() => ex('Dips', category: 'triceps', equipment: 'Bodyweight');

    test('+10 premium bonus in a fresh build', () {
      expect(
        _scorer.scoreOf(dips(), _slot, stateWith([]), ExperienceLevel.advanced),
        10,
      );
    });

    test('-100 when 3 press movements already present', () {
      final threePresses = stateWith([
        ex('P1', category: 'chest press', equipment: 'Barbell'),
        ex('P2', category: 'incline press', equipment: 'Dumbbell'),
        ex('P3', category: 'shoulder press', equipment: 'Barbell'),
      ]);
      expect(
        _scorer.scoreOf(dips(), _slot, threePresses, ExperienceLevel.advanced),
        -100,
      );
    });

    test('-50 when Close Grip Bench Press already selected', () {
      final withCgbp = stateWith([
        ex(
          'Close Grip Bench Press',
          category: 'chest press',
          equipment: 'Barbell',
        ),
      ]);
      // Only 1 press (< 3), but CGBP overlap → -50.
      expect(
        _scorer.scoreOf(dips(), _slot, withCgbp, ExperienceLevel.advanced),
        -50,
      );
    });

    test('compound press is NOT counted as a press (matches prototype)', () {
      // Three "compound press" exercises should NOT trip the -100 guard.
      final threeCompound = stateWith([
        ex('C1', category: 'compound press', equipment: 'Barbell'),
        ex('C2', category: 'compound press', equipment: 'Dumbbell'),
        ex('C3', category: 'compound press', equipment: 'Cable'),
      ]);
      expect(
        _scorer.scoreOf(dips(), _slot, threeCompound, ExperienceLevel.advanced),
        10, // still the +10 bonus
      );
    });
  });

  group('legs near-duplicate soft caps (script.js:9341-9361)', () {
    Exercise legEx(String name, String category) => ex(
      name,
      category: category,
      equipment: 'Barbell',
      type: ExerciseType.isolation,
    );
    const legsSlot = GeneratorSlot(category: 'hip thrust');

    double delta(Exercise cand, List<Exercise> committed) {
      final withCommitted = stateWith(committed, split: 'Legs + Core');
      final fresh = BuildState('Legs + Core');
      return _scorer.scoreOf(
            cand,
            legsSlot,
            withCommitted,
            ExperienceLevel.advanced,
          ) -
          _scorer.scoreOf(cand, legsSlot, fresh, ExperienceLevel.advanced);
    }

    test('2nd hip thrust penalized -40 when one already committed', () {
      final cand = legEx('Dumbbell Hip Thrust', 'hip thrust');
      final committed = [legEx('Barbell Hip Thrust', 'hip thrust')];
      expect(delta(cand, committed), -40);
    });

    test('bridge counts as a hip-thrust duplicate', () {
      final cand = legEx('Glute Bridge', 'hip thrust');
      final committed = [legEx('Barbell Hip Thrust', 'hip thrust')];
      expect(delta(cand, committed), -40);
    });

    test('2nd leg-curl penalized -30 when one already committed', () {
      final cand = legEx('Lying Leg Curl', 'hamstring curl');
      final committed = [legEx('Seated Leg Curl', 'hamstring curl')];
      expect(delta(cand, committed), -30);
    });

    test('no penalty when no matching movement is committed', () {
      final cand = legEx('Barbell Hip Thrust', 'hip thrust');
      final committed = [legEx('Back Squat', 'squat')];
      expect(delta(cand, committed), 0);
    });

    test('unrelated leg exercise is unaffected', () {
      final cand = legEx('Leg Extension', 'quad');
      final committed = [legEx('Barbell Hip Thrust', 'hip thrust')];
      expect(delta(cand, committed), 0);
    });
  });
}
