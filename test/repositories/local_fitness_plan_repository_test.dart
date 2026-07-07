import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/models/generator/experience_level.dart';
import 'package:maxhype/models/generator/fitness_plan.dart';
import 'package:maxhype/models/generator/split_type.dart';
import 'package:maxhype/repositories/local_fitness_plan_repository.dart';

void main() {
  late Directory tmp;
  late File planFile;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('mh_plan_repo_test_');
    planFile = File('${tmp.path}/fitness_plan.json');
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  LocalFitnessPlanRepository newRepo() =>
      LocalFitnessPlanRepository(directoryResolver: () async => tmp);

  group('load — no stored plan', () {
    test('returns defaults when file is missing', () async {
      final plan = await newRepo().load();
      final defaults = FitnessPlan.defaults();
      expect(plan.split, defaults.split);
      expect(plan.daysPerWeek, defaults.daysPerWeek);
      expect(plan.durationMinutes, defaults.durationMinutes);
      expect(plan.experience, defaults.experience);
    });

    test('returns defaults for an empty file', () async {
      planFile.writeAsStringSync('');
      final plan = await newRepo().load();
      expect(plan.split, FitnessPlan.defaults().split);
    });

    test('resets to defaults on a corrupt file (and removes it)', () async {
      planFile.writeAsStringSync('{ not json');
      final plan = await newRepo().load();
      expect(plan.split, FitnessPlan.defaults().split);
      expect(planFile.existsSync(), isFalse);
    });
  });

  group('save + reload — survives restart', () {
    test('round-trips every field through a fresh repo instance', () async {
      const plan = FitnessPlan(
        split: SplitType.pplUpperLower,
        daysPerWeek: 5,
        durationMinutes: 90,
        experience: ExperienceLevel.advanced,
        units: WeightUnit.kg,
        sex: Sex.female,
        age: 27,
        weight: 68.5,
      );

      await newRepo().save(plan);

      // A brand-new repo (simulating an app restart) must read it back.
      final reloaded = await newRepo().load();
      expect(reloaded.split, SplitType.pplUpperLower);
      expect(reloaded.daysPerWeek, 5);
      expect(reloaded.durationMinutes, 90);
      expect(reloaded.experience, ExperienceLevel.advanced);
      expect(reloaded.units, WeightUnit.kg);
      expect(reloaded.sex, Sex.female);
      expect(reloaded.age, 27);
      expect(reloaded.weight, 68.5);
    });

    test('last save wins', () async {
      final repo = newRepo();
      await repo.save(FitnessPlan.defaults());
      await repo.save(
        FitnessPlan.defaults().copyWith(durationMinutes: 120, daysPerWeek: 6),
      );
      final reloaded = await newRepo().load();
      expect(reloaded.durationMinutes, 120);
      expect(reloaded.daysPerWeek, 6);
    });

    test('writes atomically (no leftover .tmp file)', () async {
      await newRepo().save(FitnessPlan.defaults());
      expect(File('${planFile.path}.tmp').existsSync(), isFalse);
      expect(planFile.existsSync(), isTrue);
    });
  });

  group('FitnessPlan JSON', () {
    test('fromJson tolerates missing fields with defaults', () {
      final plan = FitnessPlan.fromJson({'split': 'full_body'});
      expect(plan.split, SplitType.fullBody);
      expect(plan.daysPerWeek, FitnessPlan.defaults().daysPerWeek);
      expect(plan.weight, FitnessPlan.defaults().weight);
    });

    test('toJson/fromJson is a stable round-trip', () {
      final plan = FitnessPlan.defaults()
          .copyWith(split: SplitType.upperLower, age: 40);
      final decoded = FitnessPlan.fromJson(
          jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>);
      expect(decoded.split, SplitType.upperLower);
      expect(decoded.age, 40);
    });
  });
}
