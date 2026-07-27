import 'package:flutter/foundation.dart';

import '../models/generator/fitness_plan.dart';

/// Persistence for the user's [FitnessPlan]. A single plan exists at a time;
/// [load] always returns a usable plan (defaults when none is stored yet).
abstract class FitnessPlanRepository {
  /// Loads the stored plan, or [FitnessPlan.defaults] when none exists.
  Future<FitnessPlan> load();

  /// Persists [plan], surviving app restarts.
  Future<void> save(FitnessPlan plan);

  /// The user's current display [WeightUnit], as a reactive value so any screen
  /// that renders a weight can rebuild the moment the unit toggles on the Plan
  /// screen — without loading the whole plan or wiring a bespoke event. Seeded
  /// from the stored plan and updated on every [save]. Listen with a
  /// `ValueListenableBuilder`; read `.value` for a one-shot.
  ValueListenable<WeightUnit> get units;
}
