import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../repositories/workout_completion_repository.dart';
import '../../../repositories/workout_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final WorkoutRepository repository;
  final WorkoutCompletionRepository? completionRepository;

  HomeBloc({
    required this.repository,
    this.completionRepository,
  }) : super(const HomeLoading()) {
    on<HomeInitial>(_onInitial);
    on<RefreshCompletions>(_onRefreshCompletions);
  }

  Future<void> _onInitial(HomeInitial event, Emitter<HomeState> emit) async {
    emit(const HomeLoading());

    try {
      final workouts = await repository.getWorkouts();
      final monthlyData = await repository.getMonthlyData();
      final allTimeStats = await repository.getAllTimeStats();
      final completions =
          await completionRepository?.loadAll() ?? const {};

      emit(HomeSuccess(
        workouts: workouts,
        monthlyData: monthlyData,
        allTimeStats: allTimeStats,
        completions: completions,
      ));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }

  Future<void> _onRefreshCompletions(
    RefreshCompletions event,
    Emitter<HomeState> emit,
  ) async {
    final cur = state;
    if (cur is! HomeSuccess) return;
    final completions =
        await completionRepository?.loadAll() ?? const {};
    emit(HomeSuccess(
      workouts: cur.workouts,
      monthlyData: cur.monthlyData,
      allTimeStats: cur.allTimeStats,
      completions: completions,
    ));
  }
}
