import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/generator/exercise_taxonomy.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/generator_metadata.dart';
import 'package:maxhype/services/generator/replacement_ranker.dart';

/// Builds a generator-metadata-bearing Exercise for ranker tests.
Exercise ex(
  String name, {
  String bodyPart = 'chest',
  String category = 'chest press',
  String? movementPattern,
  String? primaryMuscle,
  String? jointPattern,
  String? stimulusType,
  String equipment = 'Barbell',
  ExperienceLevel minExperience = ExperienceLevel.beginner,
  bool stable = false,
  bool replaceOnly = false,
  bool generatorExclude = false,
}) {
  return Exercise(
    id: name.toLowerCase().replaceAll(' ', '_'),
    name: name,
    sets: 3,
    reps: 10,
    weight: 0,
    muscleGroups: const [],
    equipmentType: EquipmentType.barbell,
    rating: 0,
    generatorMeta: GeneratorMetadata(
      category: category,
      bodyPart: BodyPart(bodyPart),
      equipment: GeneratorEquipment(equipment),
      type: ExerciseType.compound,
      tier: ExerciseTier.a,
      minExperience: minExperience,
      movementPattern: movementPattern,
      primaryMuscle: primaryMuscle,
      jointPattern: jointPattern,
      stimulusType: stimulusType,
      stable: stable,
      replaceOnly: replaceOnly,
      generatorExclude: generatorExclude,
    ),
  );
}

void main() {
  const ranker = ReplacementRanker();

  List<String> names(List<Exercise> xs) => xs.map((e) => e.name).toList();

  test('pool is scoped to the original body part', () {
    final orig = ex('Barbell Bench Press', bodyPart: 'chest');
    final result = ranker.rank(
      orig,
      universe: [
        orig,
        ex('Incline Dumbbell Press', bodyPart: 'chest'),
        ex('Barbell Row', bodyPart: 'back'), // different body part → excluded
      ],
      alreadyUsed: const {},
      experience: ExperienceLevel.advanced,
    );
    expect(names(result), ['Incline Dumbbell Press']);
  });

  test('excludes self and already-used exercises', () {
    final orig = ex('Barbell Bench Press');
    final result = ranker.rank(
      orig,
      universe: [
        orig,
        ex('Incline Dumbbell Press'),
        ex('Cable Fly'),
      ],
      alreadyUsed: {'Cable Fly'},
      experience: ExperienceLevel.advanced,
    );
    expect(names(result), ['Incline Dumbbell Press']);
  });

  test('movement-pattern match (100) outranks category match (60)', () {
    final orig = ex(
      'Barbell Bench Press',
      category: 'chest press',
      movementPattern: 'flat_press',
      primaryMuscle: 'chest',
    );
    final samePattern = ex(
      'Dumbbell Bench Press',
      category: 'other', // different category, but same pattern → 100
      movementPattern: 'flat_press',
      primaryMuscle: 'chest',
    );
    final sameCategory = ex(
      'Incline Press',
      category: 'chest press', // same category → 60
      movementPattern: 'incline_press',
      primaryMuscle: 'chest',
    );
    final result = ranker.rank(
      orig,
      universe: [orig, sameCategory, samePattern],
      alreadyUsed: const {},
      experience: ExperienceLevel.advanced,
    );
    expect(names(result), ['Dumbbell Bench Press', 'Incline Press']);
  });

  test('equipment continuity breaks affinity ties (same equipment first)', () {
    // Two candidates with identical affinity (same category), differing only
    // in equipment: the one matching the original's equipment sorts first.
    final orig = ex(
      'Barbell Bench Press',
      category: 'chest press',
      equipment: 'Barbell',
    );
    final sameEquip = ex(
      'Barbell Floor Press',
      category: 'chest press',
      equipment: 'Barbell',
    ); // continuity 50
    final diffFamily = ex(
      'Machine Chest Press',
      category: 'chest press',
      equipment: 'Machine',
    ); // continuity 0
    final result = ranker.rank(
      orig,
      universe: [orig, diffFamily, sameEquip],
      alreadyUsed: const {},
      experience: ExperienceLevel.advanced,
    );
    expect(names(result), ['Barbell Floor Press', 'Machine Chest Press']);
  });

  test('history frequency wins over affinity', () {
    final orig = ex(
      'Barbell Bench Press',
      category: 'chest press',
      movementPattern: 'flat_press',
    );
    final highAffinity = ex(
      'Dumbbell Bench Press',
      category: 'chest press',
      movementPattern: 'flat_press',
    ); // 100
    final popular = ex(
      'Cable Fly',
      category: 'chest fly',
      movementPattern: 'fly',
    ); // 0 affinity but used a lot
    final result = ranker.rank(
      orig,
      universe: [orig, highAffinity, popular],
      alreadyUsed: const {},
      experience: ExperienceLevel.advanced,
      historyFrequency: {'Cable Fly': 5},
    );
    expect(names(result), ['Cable Fly', 'Dumbbell Bench Press']);
  });

  test(
    'generatorExclude without replaceOnly is blocked; replaceOnly allowed',
    () {
      final orig = ex('Barbell Bench Press');
      final blocked = ex('Bench Dips', generatorExclude: true);
      final allowed = ex(
        'Wall Press',
        generatorExclude: true,
        replaceOnly: true,
      );
      final result = ranker.rank(
        orig,
        universe: [orig, blocked, allowed],
        alreadyUsed: const {},
        experience: ExperienceLevel.advanced,
      );
      expect(names(result), ['Wall Press']);
    },
  );

  test('experience gates candidates above the user level', () {
    final orig = ex('Barbell Bench Press');
    final advancedOnly = ex(
      'Weighted Dips',
      minExperience: ExperienceLevel.advanced,
    );
    final beginnerOk = ex('Push Up', minExperience: ExperienceLevel.beginner);
    final result = ranker.rank(
      orig,
      universe: [orig, advancedOnly, beginnerOk],
      alreadyUsed: const {},
      experience: ExperienceLevel.beginner,
    );
    expect(names(result), ['Push Up']);
  });

  test('stable-first then alphabetical break remaining ties', () {
    // All same affinity + equipment; only stable flag and name differ.
    final orig = ex('Barbell Bench Press', category: 'chest press');
    final zStable = ex('Zebra Press', category: 'chest press', stable: true);
    final aUnstable = ex('Alpha Press', category: 'chest press');
    final bUnstable = ex('Beta Press', category: 'chest press');
    final result = ranker.rank(
      orig,
      universe: [orig, aUnstable, bUnstable, zStable],
      alreadyUsed: const {},
      experience: ExperienceLevel.advanced,
    );
    // Stable wins first, then the two unstables alphabetically.
    expect(names(result), ['Zebra Press', 'Alpha Press', 'Beta Press']);
  });
}
