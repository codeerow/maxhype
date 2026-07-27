import 'package:flutter_test/flutter_test.dart';
import 'package:maxhype/core/weight_units.dart';
import 'package:maxhype/models/all_time_stats.dart';
import 'package:maxhype/models/generator/fitness_plan.dart';
import 'package:maxhype/models/monthly_data.dart';

void main() {
  group('WeightUnitConversion', () {
    test('lb is a pass-through (canonical unit)', () {
      expect(WeightUnit.lb.fromPounds(100), 100);
      expect(WeightUnit.lb.toPounds(100), 100);
      expect(WeightUnit.lb.formatWeight(45), '45');
      expect(WeightUnit.lb.formatWeightWithUnit(45), '45 lb');
    });

    test('kg converts from and to pounds and round-trips', () {
      // 220.462 lb ≈ 100 kg.
      expect(WeightUnit.kg.fromPounds(220.462), closeTo(100, 0.001));
      expect(WeightUnit.kg.toPounds(100), closeTo(220.462, 0.001));
      // Round-trip a value through kg and back to lb.
      expect(
        WeightUnit.kg.toPounds(WeightUnit.kg.fromPounds(135)),
        closeTo(135, 0.0001),
      );
    });

    test('formatWeight rounds to the nearest 0.5 and trims trailing .0', () {
      // 45 lb = 20.41 kg → nearest 0.5 = 20.5.
      expect(WeightUnit.kg.formatWeight(45), '20.5');
      // 44 lb = 19.96 kg → nearest 0.5 = 20.0 → trimmed to "20".
      expect(WeightUnit.kg.formatWeight(44), '20');
      expect(WeightUnit.kg.formatWeightWithUnit(45), '20.5 kg');
    });

    test('convertMonthly scales volume and stamps the unit label', () {
      final months = [
        MonthlyData(
          monthName: 'Jan',
          year: 2026,
          completionPercentage: 0.5,
          totalKcal: 1000,
          dailyData: [
            DailyData(day: 1, kcal: 100, volume: 220.462, isWorkoutDay: true),
          ],
        ),
      ];

      final converted = WeightUnit.kg.convertMonthly(months);
      expect(converted.single.weightUnitLabel, 'kg');
      expect(converted.single.dailyData.single.volume, closeTo(100, 0.001));
      // Non-weight fields are preserved.
      expect(converted.single.dailyData.single.kcal, 100);
      expect(converted.single.totalKcal, 1000);

      // lb leaves the numbers untouched.
      final asLb = WeightUnit.lb.convertMonthly(months);
      expect(asLb.single.weightUnitLabel, 'lb');
      expect(asLb.single.dailyData.single.volume, 220.462);
    });

    test('convertStats scales totalVolume and stamps the unit label', () {
      final stats = AllTimeStats(
        totalWorkouts: 12,
        totalKcal: 5000,
        totalVolume: 220.462,
        currentStreak: 3,
        longestStreak: 7,
      );

      final kg = WeightUnit.kg.convertStats(stats);
      expect(kg.weightUnitLabel, 'kg');
      expect(kg.totalVolume, closeTo(100, 0.001));
      // Non-weight fields are preserved.
      expect(kg.totalWorkouts, 12);
      expect(kg.currentStreak, 3);
      expect(kg.longestStreak, 7);

      final lb = WeightUnit.lb.convertStats(stats);
      expect(lb.weightUnitLabel, 'lb');
      expect(lb.totalVolume, 220.462);
    });
  });
}
