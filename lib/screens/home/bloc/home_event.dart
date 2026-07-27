import '../../../models/workout.dart';

sealed class HomeEvent {
  const HomeEvent();
}

/// Initial event to load data
class HomeInitial extends HomeEvent {
  const HomeInitial();
}

/// Triggered when external state (e.g., a workout was just finished)
/// invalidates the completion map cached in [HomeSuccess]. The bloc
/// re-reads the completion store without re-running the full workout /
/// monthly-data load.
class RefreshCompletions extends HomeEvent {
  const RefreshCompletions();
}

/// Fired when the app returns to the foreground on Home (tab re-selected or
/// resumed from background). Re-reads the workout repository so a cross-week
/// rebuild (rotation memory for the new ISO week) is picked up without a manual
/// plan save. The repository only rebuilds if the plan or ISO week actually
/// changed, so this is cheap when nothing has.
class RefreshWorkouts extends HomeEvent {
  const RefreshWorkouts();
}

/// Internal event fired when the workout repository pushes a new list on its
/// `watchWorkouts()` stream (e.g. after the plan is saved and the generator
/// rebuilds the cards, or after a Replace mutation). Carries the fresh list so
/// the carousel updates without a full reload flash.
class WorkoutsUpdated extends HomeEvent {
  final List<Workout> workouts;
  const WorkoutsUpdated(this.workouts);
}

/// Internal event fired when the user toggles the weight unit (KG/LB) on the
/// Plan screen. Re-reads monthly data and all-time stats so their volume
/// figures (converted at the repository boundary) reflect the new unit, keeping
/// the workout list and completion map intact.
class UnitsChanged extends HomeEvent {
  const UnitsChanged();
}
