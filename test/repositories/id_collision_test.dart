import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/repositories/mock_exercise_repository.dart';

/// Guards the id-collision hazard behind the session-screen "wrong exercise"
/// bug: generated exercises use ids ex_001..187 (asset library order), which
/// overlap the hand-curated mock catalog's ex_001..047. Any UI that resolves a
/// session exercise by *id* against the mock repo will surface the wrong
/// exercise for generated workouts — it must resolve by *name* against the
/// asset library instead.
void main() {
  test('asset and mock repos share ids that map to different exercises', () async {
    final asset = AssetExerciseRepository(
      jsonLoader: () async =>
          File('assets/data/exercise_library.json').readAsString(),
    );
    await asset.load();
    final mock = MockExerciseRepository();

    // Find at least one id present in both repos with a different name — that's
    // the collision that broke the session screen (e.g. ex_037 = a chest press
    // in the asset library but "Romanian Deadlift" in the mock catalog).
    var collisions = 0;
    for (final m in mock.getAllExercises()) {
      final a = asset.getExerciseById(m.id);
      if (a != null && a.name != m.name) collisions++;
    }
    expect(
      collisions,
      greaterThan(0),
      reason: 'expected overlapping ids to prove the hazard is real',
    );
  });

  test(
    'asset library resolves generated exercises by name (the fix path)',
    () async {
      final asset = AssetExerciseRepository(
        jsonLoader: () async =>
            File('assets/data/exercise_library.json').readAsString(),
      );
      await asset.load();

      // Name lookup returns the correct exercise regardless of id collisions.
      final byName = asset.getExerciseByName('Cable Lateral Raise');
      expect(byName, isNotNull);
      expect(byName!.name, 'Cable Lateral Raise');
      expect(byName.generatorMeta?.category, 'side delt');
    },
  );
}
