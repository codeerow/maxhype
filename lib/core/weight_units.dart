import '../models/all_time_stats.dart';
import '../models/generator/fitness_plan.dart';
import '../models/monthly_data.dart';

/// Weight-unit conversion + display formatting.
///
/// Canonical storage is **pounds**: every persisted weight (logged set weights,
/// PRs, bodyweight, planned prescriptions) is a raw `double` in lb, unit-tagged
/// nowhere. The user's chosen [WeightUnit] is a *display* concern — screens
/// convert lb → the chosen unit on the way out and the chosen unit → lb on the
/// way in (set logging). This keeps historical data intact when the unit
/// toggles: nothing stored is rewritten.
extension WeightUnitConversion on WeightUnit {
  /// Exact pounds-per-kilogram factor.
  static const double _lbPerKg = 2.2046226218;

  /// Converts a canonical (lb) weight into this unit, for display.
  double fromPounds(double lb) => this == WeightUnit.kg ? lb / _lbPerKg : lb;

  /// Converts a value entered in this unit back to canonical pounds, for
  /// storage.
  double toPounds(double value) =>
      this == WeightUnit.kg ? value * _lbPerKg : value;

  /// Formats a canonical (lb) weight for display in this unit: converted, then
  /// rounded to the nearest 0.5, with a trailing `.0` trimmed (e.g. `20.5`,
  /// `45`). Returns just the number — callers append the unit label.
  String formatWeight(double lb) {
    final converted = fromPounds(lb);
    final halved = (converted * 2).round() / 2;
    // Drop a trailing `.0` so whole numbers read as "45", not "45.0".
    return halved == halved.roundToDouble()
        ? halved.toInt().toString()
        : halved.toStringAsFixed(1);
  }

  /// Formats a canonical (lb) weight with the unit label appended, e.g.
  /// `20.5 kg` / `45 lb`.
  String formatWeightWithUnit(double lb) => '${formatWeight(lb)} $displayName';

  /// Converts a list of monthly stats (whose [DailyData.volume] is canonical
  /// pounds) into this unit, stamping [MonthlyData.weightUnitLabel] so chart
  /// views render values and label as-is. This is the single data-boundary the
  /// repositories call — views stay unit-agnostic.
  List<MonthlyData> convertMonthly(List<MonthlyData> months) => months
      .map(
        (m) => MonthlyData(
          monthName: m.monthName,
          year: m.year,
          completionPercentage: m.completionPercentage,
          totalKcal: m.totalKcal,
          weightUnitLabel: displayName,
          dailyData: m.dailyData
              .map(
                (d) => DailyData(
                  day: d.day,
                  kcal: d.kcal,
                  volume: fromPounds(d.volume),
                  isWorkoutDay: d.isWorkoutDay,
                ),
              )
              .toList(),
        ),
      )
      .toList();

  /// Converts all-time stats (whose [AllTimeStats.totalVolume] is canonical
  /// pounds) into this unit. Same data-boundary role as [convertMonthly].
  AllTimeStats convertStats(AllTimeStats stats) => AllTimeStats(
        totalWorkouts: stats.totalWorkouts,
        totalKcal: stats.totalKcal,
        totalVolume: fromPounds(stats.totalVolume),
        currentStreak: stats.currentStreak,
        longestStreak: stats.longestStreak,
        weightUnitLabel: displayName,
      );
}
