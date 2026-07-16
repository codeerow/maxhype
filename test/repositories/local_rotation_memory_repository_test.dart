import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/generator/exercise_taxonomy.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/generator_metadata.dart';
import 'package:maxhype/repositories/local_rotation_memory_repository.dart';

Exercise ex(String name, String category) => Exercise(
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
        equipment: const GeneratorEquipment('Barbell'),
        type: ExerciseType.compound,
        tier: ExerciseTier.a,
        minExperience: ExperienceLevel.none,
      ),
    );

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('rotmem_test');
  });
  tearDown(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  LocalRotationMemoryRepository repo() => LocalRotationMemoryRepository(
        directoryResolver: () async => tempDir,
      );

  test('load on a fresh store returns empty memory', () async {
    final m = await repo().load();
    expect(m.recentFor('Push Day', 'chest_compound'), isEmpty);
  });

  test('recordCompletion persists and survives a reload', () async {
    final r = repo();
    await r.recordCompletion(
      'Push Day',
      [ex('Bench', 'chest press'), ex('Fly', 'chest fly')],
      completionKey: 'w1',
    );
    // A brand-new repo instance pointed at the same dir sees the write.
    final reloaded = await repo().load();
    expect(reloaded.recentFor('Push Day', 'chest_compound'), ['Bench']);
    expect(reloaded.recentFor('Push Day', 'chest_iso'), ['Fly']);
  });

  test('duplicate completionKey does not double-record', () async {
    final r = repo();
    await r.recordCompletion('Push Day', [ex('Bench', 'chest press')],
        completionKey: 'same');
    await r.recordCompletion('Push Day', [ex('Bench', 'chest press')],
        completionKey: 'same');
    final m = await repo().load();
    // Recorded once, not twice (dedup by key), so a single entry.
    expect(m.recentFor('Push Day', 'chest_compound'), ['Bench']);
  });

  test('different completionKeys both apply', () async {
    final r = repo();
    await r.recordCompletion('Push Day', [ex('Bench', 'chest press')],
        completionKey: 'k1');
    await r.recordCompletion('Push Day', [ex('Incline', 'chest press')],
        completionKey: 'k2');
    final m = await repo().load();
    expect(m.recentFor('Push Day', 'chest_compound'), ['Bench', 'Incline']);
  });

  test('a corrupt store is cleared and treated as empty', () async {
    final file = File('${tempDir.path}/rotation_memory.json');
    await file.writeAsString('{ this is not valid json');
    final m = await repo().load();
    expect(m.recentFor('Push Day', 'chest_compound'), isEmpty);
    // The corrupt file was deleted by the defensive clear.
    expect(file.existsSync(), isFalse);
  });
}
