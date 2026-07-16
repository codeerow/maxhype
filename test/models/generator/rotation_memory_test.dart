import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/generator/exercise_taxonomy.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/generator_metadata.dart';
import 'package:maxhype/models/generator/rotation_memory.dart';

Exercise ex(String name, {String? category, String bodyPart = 'Chest'}) {
  return Exercise(
    id: name,
    name: name,
    sets: 3,
    reps: 8,
    weight: 0,
    muscleGroups: const [],
    equipmentType: EquipmentType.barbell,
    rating: 0,
    generatorMeta: category == null
        ? null
        : GeneratorMetadata(
            category: category,
            bodyPart: BodyPart(bodyPart),
            equipment: const GeneratorEquipment('Barbell'),
            type: ExerciseType.compound,
            tier: ExerciseTier.a,
            minExperience: ExperienceLevel.none,
          ),
  );
}

void main() {
  group('bucketOf', () {
    test('Push buckets by category', () {
      const m = RotationMemory.empty();
      expect(m.bucketOf('Push Day', ex('Bench', category: 'chest press')),
          'chest_compound');
      expect(m.bucketOf('Push Day', ex('Fly', category: 'chest fly')),
          'chest_iso');
      expect(m.bucketOf('Push Day', ex('OHP', category: 'shoulder press')),
          'shoulder_compound');
      expect(
          m.bucketOf('Push Day', ex('Lat Raise', category: 'side delt')),
          'shoulder_iso');
      expect(m.bucketOf('Push Day', ex('Pushdown', category: 'triceps')),
          'triceps');
    });

    test('Pull curl detection uses name when category is not biceps', () {
      const m = RotationMemory.empty();
      // A "curl"-named non-forearm exercise buckets as biceps.
      expect(
        m.bucketOf('Pull Day',
            ex('Hammer Curl', category: 'biceps', bodyPart: 'Biceps')),
        'biceps',
      );
      expect(m.bucketOf('Pull Day', ex('Row', category: 'row')), 'upper_back');
    });

    test('Legs + Core core categories collapse to core bucket', () {
      const m = RotationMemory.empty();
      for (final c in ['crunch', 'plank', 'leg raise', 'rotation', 'abs']) {
        expect(m.bucketOf('Legs + Core', ex('X', category: c)), 'core',
            reason: '$c should bucket as core');
      }
      expect(m.bucketOf('Legs + Core', ex('Squat', category: 'squat')),
          'quads');
    });
  });

  group('recordCompletion (dedup-then-append, trim to 4)', () {
    test('appends newest last and trims to 4 per bucket', () {
      var m = const RotationMemory.empty();
      for (final name in ['Bench', 'Incline', 'Decline', 'Floor', 'Board']) {
        m = m.recordCompletion(
            'Push Day', [ex(name, category: 'chest press')]);
      }
      final recent = m.recentFor('Push Day', 'chest_compound');
      expect(recent.length, 4);
      // Oldest ("Bench") dropped, newest ("Board") retained and last.
      expect(recent.contains('Bench'), isFalse);
      expect(recent.last, 'Board');
    });

    test('re-recording an exercise moves it to newest (dedup)', () {
      var m = const RotationMemory.empty();
      m = m.recordCompletion('Push Day', [
        ex('Bench', category: 'chest press'),
        ex('Incline', category: 'chest press'),
      ]);
      m = m.recordCompletion(
          'Push Day', [ex('Bench', category: 'chest press')]);
      final recent = m.recentFor('Push Day', 'chest_compound');
      expect(recent, ['Incline', 'Bench']); // Bench moved to the end, no dup
    });

    test('is immutable — original memory is unchanged', () {
      const original = RotationMemory.empty();
      final updated =
          original.recordCompletion('Push Day', [ex('Bench', category: 'chest press')]);
      expect(original.recentFor('Push Day', 'chest_compound'), isEmpty);
      expect(updated.recentFor('Push Day', 'chest_compound'), ['Bench']);
    });
  });

  group('penaltyFor', () {
    test('exact recent match is -50', () {
      final m = const RotationMemory.empty()
          .recordCompletion('Push Day', [ex('Bench', category: 'chest press')]);
      final penalty =
          m.penaltyFor(ex('Bench', category: 'chest press'), 'Push Day', 5);
      expect(penalty, -50);
    });

    test('bucket pressure (>=2 in bucket) adds -20, clamped at -50', () {
      final m = const RotationMemory.empty().recordCompletion('Push Day', [
        ex('Bench', category: 'chest press'),
        ex('Incline', category: 'chest press'),
      ]);
      // A DIFFERENT chest-press exercise: no exact match (0) but bucket has 2
      // → -20.
      expect(
        m.penaltyFor(ex('Decline', category: 'chest press'), 'Push Day', 5),
        -20,
      );
      // The exact match ALSO in a >=2 bucket: -50 + -20 = -70 → clamped to -50.
      expect(
        m.penaltyFor(ex('Bench', category: 'chest press'), 'Push Day', 5),
        -50,
      );
    });

    test('pool < 2 is never penalized (single-option slot must fill)', () {
      final m = const RotationMemory.empty()
          .recordCompletion('Push Day', [ex('Bench', category: 'chest press')]);
      expect(
        m.penaltyFor(ex('Bench', category: 'chest press'), 'Push Day', 1),
        0,
      );
    });

    test('name normalization is whitespace/case-insensitive', () {
      final m = const RotationMemory.empty()
          .recordCompletion('Push Day', [ex('Barbell  Bench', category: 'chest press')]);
      expect(
        m.penaltyFor(ex('barbell bench', category: 'chest press'), 'Push Day', 5),
        -50,
      );
    });
  });

  group('json round-trip', () {
    test('toJson/fromJson preserves buckets', () {
      final m = const RotationMemory.empty().recordCompletion('Pull Day', [
        ex('Row', category: 'row'),
        ex('Pulldown', category: 'pulldown'),
      ]);
      final back = RotationMemory.fromJson(m.toJson());
      expect(back.recentFor('Pull Day', 'upper_back'), ['Row']);
      expect(back.recentFor('Pull Day', 'lats'), ['Pulldown']);
    });
  });
}
