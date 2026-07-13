import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../models/workout.dart';
import '../../../repositories/workout_completion_repository.dart';
import '../../../repositories/workout_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final WorkoutRepository repository;
  final WorkoutCompletionRepository? completionRepository;

  StreamSubscription<List<Workout>>? _workoutsSub;

  HomeBloc({
    required this.repository,
    this.completionRepository,
  }) : super(const HomeLoading()) {
    on<HomeInitial>(_onInitial);
    on<RefreshCompletions>(_onRefreshCompletions);
    on<WorkoutsUpdated>(_onWorkoutsUpdated);

    // Follow live workout updates (plan regeneration, Replace mutations) so the
    // carousel stays in sync without manual reload events. Static-data
    // repositories return an empty stream, so this is a no-op for them.
    _workoutsSub = repository.watchWorkouts().listen(
      (workouts) => add(WorkoutsUpdated(workouts)),
    );
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

  @override
  Future<void> close() {
    _workoutsSub?.cancel();
    return super.close();
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
