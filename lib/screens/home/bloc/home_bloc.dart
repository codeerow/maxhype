import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/generator/fitness_plan.dart';
import '../../../models/workout.dart';
import '../../../repositories/workout_completion_repository.dart';
import '../../../repositories/workout_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final WorkoutRepository repository;
  final WorkoutCompletionRepository? completionRepository;

  /// Reactive display unit. When it changes (KG/LB toggled on the Plan screen)
  /// the bloc re-reads monthly data and stats so their volume reflects the new
  /// unit. Optional — tests that don't exercise units can omit it.
  final ValueListenable<WeightUnit>? unitsListenable;

  StreamSubscription<List<Workout>>? _workoutsSub;
  VoidCallback? _unitsListener;

  HomeBloc({
    required this.repository,
    this.completionRepository,
    this.unitsListenable,
  }) : super(const HomeLoading()) {
    on<HomeInitial>(_onInitial);
    on<RefreshCompletions>(_onRefreshCompletions);
    on<RefreshWorkouts>(_onRefreshWorkouts);
    on<WorkoutsUpdated>(_onWorkoutsUpdated);
    on<UnitsChanged>(_onUnitsChanged);

    // Follow live workout updates (plan regeneration, Replace mutations) so the
    // carousel stays in sync without manual reload events. Static-data
    // repositories return an empty stream, so this is a no-op for them.
    _workoutsSub = repository.watchWorkouts().listen(
      (workouts) => add(WorkoutsUpdated(workouts)),
    );

    // Re-read the stats when the weight unit toggles.
    final units = unitsListenable;
    if (units != null) {
      _unitsListener = () => add(const UnitsChanged());
      units.addListener(_unitsListener!);
    }
  }

  Future<void> _onInitial(HomeInitial event, Emitter<HomeState> emit) async {
    emit(const HomeLoading());

    try {
      final workouts = await repository.getWorkouts();
      final monthlyData = await repository.getMonthlyData();
      final allTimeStats = await repository.getAllTimeStats();
      final completions = await completionRepository?.loadAll() ?? const {};

      emit(
        HomeSuccess(
          workouts: workouts,
          monthlyData: monthlyData,
          allTimeStats: allTimeStats,
          completions: completions,
        ),
      );
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  /// Live workout-list update from [WorkoutRepository.watchWorkouts]. Swaps the
  /// carousel's workouts in place, preserving the already-loaded stats and
  /// completion map. Ignored until the initial load has produced [HomeSuccess].
  Future<void> _onWorkoutsUpdated(
    WorkoutsUpdated event,
    Emitter<HomeState> emit,
  ) async {
    final cur = state;
    if (cur is! HomeSuccess) return;
    emit(
      HomeSuccess(
        workouts: event.workouts,
        monthlyData: cur.monthlyData,
        allTimeStats: cur.allTimeStats,
        completions: cur.completions,
      ),
    );
  }

  /// Re-reads monthly data and all-time stats after a weight-unit toggle,
  /// preserving the current workouts and completion map. The repository
  /// converts volume to the new unit at its data boundary.
  Future<void> _onUnitsChanged(
    UnitsChanged event,
    Emitter<HomeState> emit,
  ) async {
    final cur = state;
    if (cur is! HomeSuccess) return;
    final monthlyData = await repository.getMonthlyData();
    final allTimeStats = await repository.getAllTimeStats();
    emit(
      HomeSuccess(
        workouts: cur.workouts,
        monthlyData: monthlyData,
        allTimeStats: allTimeStats,
        completions: cur.completions,
      ),
    );
  }

  @override
  Future<void> close() {
    _workoutsSub?.cancel();
    if (_unitsListener != null) {
      unitsListenable?.removeListener(_unitsListener!);
    }
    return super.close();
  }

  /// Re-reads the workout list on foreground/return-to-Home. The generated
  /// repository self-invalidates on an ISO-week rollover (guarded by any active
  /// session) and pushes the rebuilt list on its `watchWorkouts()` stream, which
  /// [_onWorkoutsUpdated] applies — so this handler just needs to poke the read.
  /// It also emits directly in case the repository's stream doesn't (e.g. the
  /// list is unchanged), keeping the completion map intact.
  Future<void> _onRefreshWorkouts(
    RefreshWorkouts event,
    Emitter<HomeState> emit,
  ) async {
    final cur = state;
    if (cur is! HomeSuccess) return;
    final workouts = await repository.getWorkouts();
    emit(
      HomeSuccess(
        workouts: workouts,
        monthlyData: cur.monthlyData,
        allTimeStats: cur.allTimeStats,
        completions: cur.completions,
      ),
    );
  }

  Future<void> _onRefreshCompletions(
    RefreshCompletions event,
    Emitter<HomeState> emit,
  ) async {
    final cur = state;
    if (cur is! HomeSuccess) return;
    final completions = await completionRepository?.loadAll() ?? const {};
    emit(
      HomeSuccess(
        workouts: cur.workouts,
        monthlyData: cur.monthlyData,
        allTimeStats: cur.allTimeStats,
        completions: completions,
      ),
    );
  }
}
