import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../repositories/workout_repository.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final WorkoutRepository repository;

  HomeBloc({required this.repository}) : super(const HomeLoading()) {
    on<HomeInitial>(_onInitial);
  }

  Future<void> _onInitial(HomeInitial event, Emitter<HomeState> emit) async {
    emit(const HomeLoading());

    try {
      final workouts = await repository.getWorkouts();
      final monthlyData = await repository.getMonthlyData();

      emit(HomeSuccess(
        workouts: workouts,
        monthlyData: monthlyData,
      ));
    } catch (e) {
      emit(HomeError(e.toString()));
    }
  }
}
