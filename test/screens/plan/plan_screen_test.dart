import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/core/demo_clock.dart';
import 'package:maxhype/core/haptic_manager.dart';
import 'package:maxhype/core/service_locator.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/fitness_plan.dart';
import 'package:maxhype/repositories/asset_exercise_repository.dart';
import 'package:maxhype/repositories/fitness_plan_repository.dart';
import 'package:maxhype/repositories/generated_workout_repository.dart';
import 'package:maxhype/repositories/workout_repository.dart';
import 'package:maxhype/screens/plan/plan_screen.dart';
import 'package:maxhype/services/generator/workout_assembler.dart';
import 'package:maxhype/services/generator/workout_generator_service.dart';

class _FakePlanRepo implements FitnessPlanRepository {
  FitnessPlan plan = FitnessPlan.defaults();
  int saves = 0;
  @override
  final ValueNotifier<WeightUnit> units =
      ValueNotifier(FitnessPlan.defaults().units);
  @override
  Future<FitnessPlan> load() async => plan;
  @override
  Future<void> save(FitnessPlan p) async {
    plan = p;
    units.value = p.units;
    saves++;
  }
}

void main() {
  late _FakePlanRepo planRepo;
  late GeneratedWorkoutRepository workoutRepo;

  setUp(() async {
    await getIt.reset();
    final assetRepo = AssetExerciseRepository(
      jsonLoader: () async =>
          File('assets/data/exercise_library.json').readAsString(),
    );
    await assetRepo.load();
    planRepo = _FakePlanRepo();
    workoutRepo = GeneratedWorkoutRepository(
      planRepository: planRepo,
      assembler: WorkoutAssembler(AssetWorkoutGeneratorService(assetRepo)),
    );
    getIt.registerSingleton<FitnessPlanRepository>(planRepo);
    getIt.registerSingleton<WorkoutRepository>(workoutRepo);
    // Menu rows tap through TapScale, which fires getIt<HapticManager>().
    getIt.registerSingleton<HapticManager>(DefaultHapticManager());
    // The Plan screen reads the week clock; the real clock keeps the debug
    // demo-week section hidden (it only shows for a DemoWeekClock).
    getIt.registerSingleton<WeekClock>(const RealWeekClock());
  });

  tearDown(getIt.reset);

  testWidgets('renders current plan and auto-saves an edit', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PlanScreen()));
    await tester.pumpAndSettle();

    // Loaded state shows the section headings.
    expect(find.text('Fitness Plan'), findsOneWidget);
    expect(find.text('Weekly Goal'), findsOneWidget);
    expect(find.text('Experience'), findsOneWidget);

    // Change experience to Advanced: tap the Experience menu row to open the
    // picker sub-screen, then tap the Advanced option there. Picking the option
    // auto-saves and regenerates — there is no explicit save button.
    await tester.tap(find.text('Experience'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(ExperienceLevel.advanced.displayName));
    // The edit is async (save + regenerate); pump a few frames for it to
    // complete. We avoid pumpAndSettle because the success toast schedules a
    // 2.5s auto-dismiss timer that would otherwise keep the tree from settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(planRepo.saves, greaterThan(0));
    expect(planRepo.plan.experience, ExperienceLevel.advanced);

    // Drain the toast's auto-dismiss timer so it doesn't outlive the test.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('editing a setting regenerates the workout cards',
      (tester) async {
    // Prime the cache at the default (3-day) plan.
    final before = await workoutRepo.getWorkouts();
    expect(before.length, 3);

    await tester.pumpWidget(const MaterialApp(home: PlanScreen()));
    await tester.pumpAndSettle();

    // Switch to a 5-day plan: open the Weekly Goal picker, pick 5. Picking
    // the option auto-saves and regenerates — there is no explicit save button.
    await tester.tap(find.text('Weekly Goal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('5 days per week'));
    // The edit is async (save + regenerate); pump a few frames for it to
    // complete. We avoid pumpAndSettle because the success toast schedules a
    // 2.5s auto-dismiss timer that would otherwise keep the tree from settling.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final after = await workoutRepo.getWorkouts();
    expect(after.length, 5);

    // Drain the toast's auto-dismiss timer so it doesn't outlive the test.
    await tester.pump(const Duration(seconds: 3));
  });
}
