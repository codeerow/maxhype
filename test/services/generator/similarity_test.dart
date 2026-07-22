import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/generator/exercise_taxonomy.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/generator_metadata.dart';
import 'package:maxhype/models/generator/generator_slot.dart';
import 'package:maxhype/services/generator/build_state.dart';
import 'package:maxhype/services/generator/similarity.dart';

const _sim = Similarity();
const _isoSlot = GeneratorSlot(slotType: 's', role: SlotRole.isolation);
const _primarySlot =
    GeneratorSlot(slotType: 'p', role: SlotRole.primaryCompound);

Exercise ex(
  String name, {
  required String primaryMuscle,
  required String movementPattern,
  String stimulusType = 'mid_range',
}) =>
    Exercise(
      id: name,
      name: name,
      sets: 3,
      reps: 8,
      weight: 0,
      muscleGroups: const [],
      equipmentType: EquipmentType.dumbbell,
      rating: 0,
      generatorMeta: GeneratorMetadata(
        category: 'x',
        bodyPart: const BodyPart('Shoulders'),
        equipment: const GeneratorEquipment('Dumbbell'),
        type: ExerciseType.isolation,
        tier: ExerciseTier.c,
        minExperience: ExperienceLevel.none,
        primaryMuscle: primaryMuscle,
        movementPattern: movementPattern,
        stimulusType: stimulusType,
      ),
    );

BuildState stateWith(List<Exercise> committed) {
  final s = BuildState('Push Day');
  for (final e in committed) {
    s.commit(e, movementGroup: e.generatorMeta?.movementGroup);
  }
  return s;
}

void main() {
  group('biomechanical-axis cascade', () {
    test('three-axis match → -10', () {
      final a = ex('Dumbbell Lateral Raise',
          primaryMuscle: 'shoulders',
          movementPattern: 'lateral_raise',
          stimulusType: 'mid_range');
      final b = ex('Cable Lateral Raise',
          primaryMuscle: 'shoulders',
          movementPattern: 'lateral_raise',
          stimulusType: 'mid_range');
      expect(_sim.penaltyFor(b, _isoSlot, stateWith([a])), -10);
    });

    test('two-axis match (muscle+pattern, different stimulus) → -7', () {
      final a = ex('Machine Lateral Raise',
          primaryMuscle: 'shoulders',
          movementPattern: 'lateral_raise',
          stimulusType: 'shortened_biased');
      final b = ex('Dumbbell Lateral Raise',
          primaryMuscle: 'shoulders',
          movementPattern: 'lateral_raise',
          stimulusType: 'mid_range');
      expect(_sim.penaltyFor(b, _isoSlot, stateWith([a])), -7);
    });

    test('one-axis match (muscle+stimulus, different pattern) → -4', () {
      final a = ex('Front Raise',
          primaryMuscle: 'shoulders',
          movementPattern: 'front_raise',
          stimulusType: 'mid_range');
      final b = ex('Lateral Raise',
          primaryMuscle: 'shoulders',
          movementPattern: 'lateral_raise',
          stimulusType: 'mid_range');
      expect(_sim.penaltyFor(b, _isoSlot, stateWith([a])), -4);
    });

    test('no shared axis → 0', () {
      final a = ex('Bench', primaryMuscle: 'chest', movementPattern: 'flat_press');
      final b = ex('Curl', primaryMuscle: 'biceps', movementPattern: 'elbow_curl');
      expect(_sim.penaltyFor(b, _isoSlot, stateWith([a])), 0);
    });
  });

  group('the cascade subsumes the prototype pair-rules', () {
    test('two lunges (shared quads+lunge) are penalized without a lunge rule',
        () {
      final a = ex('Barbell Lunge',
          primaryMuscle: 'quads',
          movementPattern: 'lunge',
          stimulusType: 'compound');
      final b = ex('Dumbbell Lunge',
          primaryMuscle: 'quads',
          movementPattern: 'lunge',
          stimulusType: 'compound');
      expect(_sim.penaltyFor(b, _isoSlot, stateWith([a])), -10);
    });

    test('biceps grip is encoded in movementPattern: same grip penalized, '
        'different grip not', () {
      final supinated = ex('Barbell Curl',
          primaryMuscle: 'biceps',
          movementPattern: 'elbow_curl',
          stimulusType: 'mid_range');
      final sameGrip = ex('Dumbbell Curl',
          primaryMuscle: 'biceps',
          movementPattern: 'elbow_curl',
          stimulusType: 'mid_range');
      final hammer = ex('Hammer Curl',
          primaryMuscle: 'biceps',
          movementPattern: 'elbow_curl_neutral',
          stimulusType: 'mid_range');
      final base = stateWith([supinated]);
      // Same grip → three-axis match → -10.
      expect(_sim.penaltyFor(sameGrip, _isoSlot, base), -10);
      // Different grip (neutral) → same muscle+stimulus only → -4.
      expect(_sim.penaltyFor(hammer, _isoSlot, base), -4);
    });

    test('mixing lateral + front delt (different pattern) is not a full echo',
        () {
      final lateral = ex('Lateral Raise',
          primaryMuscle: 'shoulders',
          movementPattern: 'lateral_raise',
          stimulusType: 'mid_range');
      final front = ex('Front Raise',
          primaryMuscle: 'shoulders',
          movementPattern: 'front_raise',
          stimulusType: 'mid_range');
      // Same muscle+stimulus, different pattern → mild -4, not -7/-10.
      expect(_sim.penaltyFor(front, _isoSlot, stateWith([lateral])), -4);
    });
  });

  group('CGBP + flat-press outlier', () {
    test('close-grip bench + flat bench penalized despite no shared axis', () {
      final cgbp = ex('Close Grip Bench Press',
          primaryMuscle: 'triceps',
          movementPattern: 'triceps_press',
          stimulusType: 'compound');
      final flat = ex('Barbell Bench Press',
          primaryMuscle: 'chest',
          movementPattern: 'flat_press',
          stimulusType: 'compound');
      // No shared axis → cascade gives 0, but the explicit pair rule → -10.
      expect(_sim.penaltyFor(cgbp, _isoSlot, stateWith([flat])), -10);
      // Symmetric.
      expect(_sim.penaltyFor(flat, _isoSlot, stateWith([cgbp])), -10);
    });
  });

  group('Rule 3 family echo and anchor cap', () {
    test('a 3rd full-axis match escalates to -14', () {
      final a = ex('A',
          primaryMuscle: 'shoulders',
          movementPattern: 'lateral_raise',
          stimulusType: 'mid_range');
      final b = ex('B',
          primaryMuscle: 'shoulders',
          movementPattern: 'lateral_raise',
          stimulusType: 'mid_range');
      final c = ex('C',
          primaryMuscle: 'shoulders',
          movementPattern: 'lateral_raise',
          stimulusType: 'mid_range');
      // Two full-axis matches already committed → the 3rd is extreme.
      expect(_sim.penaltyFor(c, _isoSlot, stateWith([a, b])), -14);
    });

    test('primary_compound slot caps the penalty at -6', () {
      final a = ex('Bench 1',
          primaryMuscle: 'chest',
          movementPattern: 'flat_press',
          stimulusType: 'compound');
      final b = ex('Bench 2',
          primaryMuscle: 'chest',
          movementPattern: 'flat_press',
          stimulusType: 'compound');
      // Would be -10 (three-axis) but the anchor cap holds it at -6.
      expect(_sim.penaltyFor(b, _primarySlot, stateWith([a])), -6);
    });
  });
}
