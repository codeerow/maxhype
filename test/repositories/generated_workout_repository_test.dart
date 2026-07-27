import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/core/demo_clock.dart';
import 'package:maxhype/models/exercise.dart';
import 'package:maxhype/models/equipment_type.dart';
import 'package:maxhype/models/muscle_group.dart';
import 'package:maxhype/models/generator/fitness_plan.dart';
import 'package:maxhype/models/workout.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/repositories/fitness_plan_repository.dart';
import 'package:maxhype/repositories/generated_workout_repository.dart';
import 'package:maxhype/services/generator/workout_assembler.dart';
import 'package:maxhype/services/generator/workout_generator_service.dart';

/// In-memory plan repo so tests can vary the plan without touching disk.
class _FakePlanRepo implements FitnessPlanRepository {
  FitnessPlan plan;
  _FakePlanRepo(this.plan) : units = ValueNotifier(plan.units);
  @override
  final ValueNotifier<WeightUnit> units;
  @override
  Future<FitnessPlan> load() async => plan;
  @override
  Future<void> save(FitnessPlan p) async {
    plan = p;
    units.value = p.units;
  }
}

/// A [WeekClock] the test drives directly, to force ISO-week rollovers.
class _FixedWeekClock implements WeekClock {
  DateTime value;
  _FixedWeekClock(this.value);
  @override
  DateTime now() => value;
}

Future<GeneratedWorkoutRepository> repoFor(FitnessPlan plan) async {
  final assetRepo = AssetExerciseRepository(
    jsonLoader: () async =>
        File('assets/data/exercise_library.json').readAsString(),
  );
  await assetRepo.load();
  final generator = AssetWorkoutGeneratorService(assetRepo);
  return GeneratedWorkoutRepository(
    planRepository: _FakePlanRepo(plan),
    assembler: WorkoutAssembler(generator),
  );
}

void main() {
  test('getWorkouts returns generated cards matching the plan', () async {
    final repo = await repoFor(FitnessPlan.defaults().copyWith(daysPerWeek: 3));
    final cards = await repo.getWorkouts();
    expect(cards.length, 3);
    expect(cards.map((c) => c.title).toList(), ['Push', 'Pull', 'Legs + Core']);
    for (final c in cards) {
      expect(c.exercises, isNotEmpty);
    }
  });

  test('cards are stable across reads (identity preserved)', () async {
    final repo = await repoFor(FitnessPlan.defaults());
    final first = await repo.getWorkouts();
    final second = await repo.getWorkouts();
    for (var i = 0; i < first.length; i++) {
      expect(first[i].id, second[i].id);
      expect(
        first[i].exercises.map((e) => e.name),
        second[i].exercises.map((e) => e.name),
      );
    }
  });

  test('bumping generation re-rolls the selection for the same settings',
      () async {
    final plan = FitnessPlan.defaults();
    final base = await (await repoFor(plan)).getWorkouts();
    final regenerated =
        await (await repoFor(plan.copyWith(generation: 1))).getWorkouts();

    // Same settings ⇒ same structure (titles/count), but the exercise
    // selection differs because the generation counter feeds the seed.
    expect(
      regenerated.map((c) => c.title),
      base.map((c) => c.title),
    );
    final baseNames =
        base.expand((c) => c.exercises.map((e) => e.name)).toList();
    final regenNames =
        regenerated.expand((c) => c.exercises.map((e) => e.name)).toList();
    expect(regenNames, isNot(equals(baseNames)));
  });

  test('same generation reproduces the same selection', () async {
    final plan = FitnessPlan.defaults().copyWith(generation: 5);
    final first = await (await repoFor(plan)).getWorkouts();
    final second = await (await repoFor(plan)).getWorkouts();
    expect(
      second.expand((c) => c.exercises.map((e) => e.name)),
      first.expand((c) => c.exercises.map((e) => e.name)),
    );
  });

  test('replaceExercise mutation persists across subsequent reads', () async {
    final repo = await repoFor(FitnessPlan.defaults());
    final cards = await repo.getWorkouts();
    final target = cards.first;
    final oldEx = target.exercises.first;
    final replacement = Exercise(
      id: 'custom_x',
      name: 'My Custom Lift',
      sets: 4,
      reps: 8,
      weight: 50,
      muscleGroups: const [MuscleGroup.chest],
      equipmentType: EquipmentType.barbell,
      rating: 0,
    );

    await repo.replaceExercise(
      workoutId: target.id,
      oldExerciseId: oldEx.id,
      newExercise: replacement,
    );

    final after = await repo.getWorkouts();
    final mutated = after.firstWhere((w) => w.id == target.id);
    expect(mutated.exercises.first.name, 'My Custom Lift');
  });

  test('regenerate rebuilds after a plan change', () async {
    final assetRepo = AssetExerciseRepository(
      jsonLoader: () async =>
          File('assets/data/exercise_library.json').readAsString(),
    );
    await assetRepo.load();
    final planRepo = _FakePlanRepo(
      FitnessPlan.defaults().copyWith(daysPerWeek: 3),
    );
    final repo = GeneratedWorkoutRepository(
      planRepository: planRepo,
      assembler: WorkoutAssembler(AssetWorkoutGeneratorService(assetRepo)),
    );

    expect((await repo.getWorkouts()).length, 3);
    planRepo.plan = planRepo.plan.copyWith(daysPerWeek: 5);
    final after = await repo.regenerate();
    expect(after.length, 5);
  });

  test(
    'same plan yields the same cards across repo instances (restart-stable)',
    () async {
      final plan = FitnessPlan.defaults().copyWith(durationMinutes: 75);
      final a = await (await repoFor(plan)).getWorkouts();
      final b = await (await repoFor(plan)).getWorkouts();
      for (var i = 0; i < a.length; i++) {
        expect(
          a[i].exercises.map((e) => e.name),
          b[i].exercises.map((e) => e.name),
        );
      }
    },
  );

  group('reactive watchWorkouts', () {
    test('replays the current list to a new listener', () async {
      final repo = await repoFor(
        FitnessPlan.defaults().copyWith(daysPerWeek: 3),
      );
      final first = await repo.watchWorkouts().first;
      expect(first.length, 3);
    });

    test('emits a fresh list after a plan change + regenerate', () async {
      final assetRepo = AssetExerciseRepository(
        jsonLoader: () async =>
            File('assets/data/exercise_library.json').readAsString(),
      );
      await assetRepo.load();
      final planRepo = _FakePlanRepo(
        FitnessPlan.defaults().copyWith(daysPerWeek: 3),
      );
      final repo = GeneratedWorkoutRepository(
        planRepository: planRepo,
        assembler: WorkoutAssembler(AssetWorkoutGeneratorService(assetRepo)),
      );

      // Collect emissions: initial replay (3 cards), then post-regenerate (5).
      final seen = <int>[];
      final sub = repo.watchWorkouts().listen((w) => seen.add(w.length));
      await Future<void>.delayed(Duration.zero); // let the replay land

      planRepo.plan = planRepo.plan.copyWith(daysPerWeek: 5);
      await repo.regenerate();
      await Future<void>.delayed(Duration.zero); // let the update land

      await sub.cancel();
      expect(seen, containsAllInOrder([3, 5]));
    });

    test('emits after a Replace mutation', () async {
      final repo = await repoFor(FitnessPlan.defaults());
      final cards = await repo.getWorkouts();

      final emissions = <List<Workout>>[];
      final sub = repo.watchWorkouts().listen(emissions.add);
      await Future<void>.delayed(Duration.zero);

      final target = cards.first;
      await repo.replaceExercise(
        workoutId: target.id,
        oldExerciseId: target.exercises.first.id,
        newExercise: target.exercises.first.copyWith(name: 'Swapped Lift'),
      );
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      // The latest emission reflects the swap.
      expect(emissions.last.first.exercises.first.name, 'Swapped Lift');
    });
  });

  group('ISO-week rollover regeneration', () {
    Future<GeneratedWorkoutRepository> repoWith({
      required WeekClock clock,
      Future<bool> Function()? hasActiveSession,
    }) async {
      final assetRepo = AssetExerciseRepository(
        jsonLoader: () async =>
            File('assets/data/exercise_library.json').readAsString(),
      );
      await assetRepo.load();
      return GeneratedWorkoutRepository(
        // Advanced 90/3-day: rotation memory has enough headroom to shift picks.
        planRepository: _FakePlanRepo(
          FitnessPlan.defaults().copyWith(daysPerWeek: 3),
        ),
        assembler: WorkoutAssembler(AssetWorkoutGeneratorService(assetRepo)),
        weekClock: clock,
        hasActiveSession: hasActiveSession,
      );
    }

    test('same week → cards stay identical (no rebuild)', () async {
      final clock = _FixedWeekClock(DateTime(2026, 7, 22));
      final repo = await repoWith(clock: clock);
      final a = await repo.getWorkouts();
      // Advance a few days but stay in the same ISO week.
      clock.value = DateTime(2026, 7, 24);
      final b = await repo.getWorkouts();
      for (var i = 0; i < a.length; i++) {
        expect(a[i].id, b[i].id);
      }
    });

    test('new ISO week → regenerates (fresh generation runs)', () async {
      final clock = _FixedWeekClock(DateTime(2026, 7, 22));
      final repo = await repoWith(clock: clock);
      final before = await repo.getWorkouts();

      // Mutate a card, then cross into the next ISO week: a rebuild must
      // discard the in-memory mutation (proving generation re-ran).
      await repo.replaceExercise(
        workoutId: before.first.id,
        oldExerciseId: before.first.exercises.first.id,
        newExercise: before.first.exercises.first.copyWith(
          name: 'Sentinel Lift',
        ),
      );
      clock.value = DateTime(2026, 7, 29); // +1 week

      final after = await repo.getWorkouts();
      expect(
        after.first.exercises.map((e) => e.name),
        isNot(contains('Sentinel Lift')),
      );
    });

    test('new ISO week but session active → does NOT regenerate', () async {
      final clock = _FixedWeekClock(DateTime(2026, 7, 22));
      final repo = await repoWith(
        clock: clock,
        hasActiveSession: () async => true,
      );
      final before = await repo.getWorkouts();
      // A live mutation stands in for "the workout the user is training".
      await repo.replaceExercise(
        workoutId: before.first.id,
        oldExerciseId: before.first.exercises.first.id,
        newExercise: before.first.exercises.first.copyWith(
          name: 'Sentinel Lift',
        ),
      );

      clock.value = DateTime(2026, 7, 29); // +1 week, but a session is active
      final after = await repo.getWorkouts();
      // The mutation survives → no rebuild happened under the active session.
      expect(
        after.first.exercises.map((e) => e.name),
        contains('Sentinel Lift'),
      );
    });

    test('week rebuild resumes once the session ends', () async {
      final clock = _FixedWeekClock(DateTime(2026, 7, 22));
      var active = true;
      final repo = await repoWith(
        clock: clock,
        hasActiveSession: () async => active,
      );
      final before = await repo.getWorkouts();
      await repo.replaceExercise(
        workoutId: before.first.id,
        oldExerciseId: before.first.exercises.first.id,
        newExercise: before.first.exercises.first.copyWith(
          name: 'Sentinel Lift',
        ),
      );
      clock.value = DateTime(2026, 7, 29);

      // Still active: no rebuild.
      var after = await repo.getWorkouts();
      expect(
        after.first.exercises.map((e) => e.name),
        contains('Sentinel Lift'),
      );

      // Session ends → next read rebuilds for the new week.
      active = false;
      after = await repo.getWorkouts();
      expect(
        after.first.exercises.map((e) => e.name),
        isNot(contains('Sentinel Lift')),
      );
    });
  });
}
