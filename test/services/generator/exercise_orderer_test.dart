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

  group('Legs + Core block order', () {
    test('quads → hamstrings → glutes → calves → core last', () {
      final input = [
        _ex('Crunch', category: 'abs', type: ExerciseType.isolation),
        _ex('Calf Raise', category: 'calf raise', type: ExerciseType.isolation),
        _ex('Leg Extension', category: 'quad', type: ExerciseType.isolation),
        _ex('Hip Thrust', category: 'hip thrust', type: ExerciseType.compound),
        _ex(
          'Ham Curl',
          category: 'hamstring curl',
          type: ExerciseType.isolation,
        ),
        _ex('Deadlift', category: 'hinge', type: ExerciseType.compound),
        _ex('Squat', category: 'squat', type: ExerciseType.compound),
      ];
      final out = _names(orderer.order('Legs + Core', input));
      expect(out, [
        'Squat', // quads: compound first
        'Leg Extension',
        'Deadlift', // hamstrings: compound first
        'Ham Curl',
        'Hip Thrust',
        'Calf Raise',
        'Crunch', // core strictly last
      ]);
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
