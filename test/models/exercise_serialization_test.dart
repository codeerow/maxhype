import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/muscle_group.dart';
import 'package:maxhype/models/generator/exercise_taxonomy.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/generator_metadata.dart';

void main() {
  group('Exercise JSON', () {
    test('round-trips a plain exercise (no generator metadata)', () {
      final ex = Exercise(
        id: 'ex_001',
        name: 'Barbell Bench Press',
        sets: 4,
        reps: 8,
        weight: 80,
        muscleGroups: const [MuscleGroup.chest, MuscleGroup.triceps],
        equipmentType: EquipmentType.barbell,
        rating: 5000,
      );
      final decoded = Exercise.fromJson(ex.toJson());
      expect(decoded.id, ex.id);
      expect(decoded.name, ex.name);
      expect(decoded.muscleGroups, ex.muscleGroups);
      expect(decoded.equipmentType, EquipmentType.barbell);
      expect(decoded.generatorMeta, isNull);
    });

    test('round-trips generator metadata', () {
      final ex = Exercise(
        id: 'ex_010',
        name: 'Incline Press',
        sets: 3,
        reps: 10,
        weight: 0,
        muscleGroups: const [MuscleGroup.chest],
        equipmentType: EquipmentType.machine,
        rating: 0,
        generatorMeta: const GeneratorMetadata(
          category: 'incline press',
          bodyPart: BodyPart('Chest'),
          equipment: GeneratorEquipment('Smith Machine'),
          type: ExerciseType.compound,
          tier: ExerciseTier.a,
          minExperience: ExperienceLevel.intermediate,
          movementGroup: 'incline_press',
          primaryMuscle: 'chest',
          secondaryMuscles: ['front_delt', 'triceps'],
          movementPattern: 'incline_press',
          region: 'chest_upper',
          jointPattern: 'press',
          stimulusType: 'compound',
          hypertrophyRole: 'secondary_compound',
          stable: true,
        ),
      );
      final decoded = Exercise.fromJson(ex.toJson());
      final meta = decoded.generatorMeta!;
      expect(meta.category, 'incline press');
      expect(meta.equipment.label, 'Smith Machine');
      expect(meta.type, ExerciseType.compound);
      expect(meta.tier, ExerciseTier.a);
      expect(meta.minExperience, ExperienceLevel.intermediate);
      expect(meta.movementGroup, 'incline_press');
      expect(meta.primaryMuscle, 'chest');
      expect(meta.secondaryMuscles, ['front_delt', 'triceps']);
      expect(meta.movementPattern, 'incline_press');
      expect(meta.region, 'chest_upper');
      expect(meta.hypertrophyRole, 'secondary_compound');
      expect(meta.stable, isTrue);
      expect(meta.replaceOnly, isFalse);
    });

    test('copyWith preserves generatorMeta when not overridden', () {
      final ex = Exercise(
        id: 'ex_1',
        name: 'A',
        sets: 3,
        reps: 10,
        weight: 0,
        muscleGroups: const [MuscleGroup.back],
        equipmentType: EquipmentType.cable,
        rating: 0,
        generatorMeta: const GeneratorMetadata(
          category: 'row',
          bodyPart: BodyPart('Back'),
          equipment: GeneratorEquipment('Cable'),
          type: ExerciseType.compound,
          tier: ExerciseTier.b,
          minExperience: ExperienceLevel.none,
        ),
      );
      final copy = ex.copyWith(name: 'B');
      expect(copy.name, 'B');
      expect(copy.generatorMeta, isNotNull);
      expect(copy.generatorMeta!.category, 'row');
    });
  });

  group('GeneratorMetadata.isGeneratableAt', () {
    GeneratorMetadata meta({
      ExperienceLevel min = ExperienceLevel.none,
      bool replaceOnly = false,
      bool generatorExclude = false,
    }) =>
        GeneratorMetadata(
          category: 'row',
          bodyPart: const BodyPart('Back'),
          equipment: const GeneratorEquipment('Barbell'),
          type: ExerciseType.compound,
          tier: ExerciseTier.a,
          minExperience: min,
          replaceOnly: replaceOnly,
          generatorExclude: generatorExclude,
        );

    test('respects minimum experience', () {
      final m = meta(min: ExperienceLevel.intermediate);
      expect(m.isGeneratableAt(ExperienceLevel.beginner), isFalse);
      expect(m.isGeneratableAt(ExperienceLevel.intermediate), isTrue);
      expect(m.isGeneratableAt(ExperienceLevel.advanced), isTrue);
    });

    test('replaceOnly and generatorExclude are never generatable', () {
      expect(meta(replaceOnly: true).isGeneratableAt(ExperienceLevel.advanced),
          isFalse);
      expect(
          meta(generatorExclude: true).isGeneratableAt(ExperienceLevel.advanced),
          isFalse);
    });
  });
}
