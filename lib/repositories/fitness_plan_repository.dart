import '../models/generator/fitness_plan.dart';

/// Persistence for the user's [FitnessPlan]. A single plan exists at a time;
/// [load] always returns a usable plan (defaults when none is stored yet).
abstract class FitnessPlanRepository {
  /// Loads the stored plan, or [FitnessPlan.defaults] when none exists.
  Future<FitnessPlan> load();

  /// Persists [plan], surviving app restarts.
  Future<void> save(FitnessPlan plan);
}
