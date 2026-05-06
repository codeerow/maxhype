import 'package:get_it/get_it.dart';
import '../repositories/workout_repository.dart';
import '../repositories/mock_workout_repository.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/mock_exercise_repository.dart';
import '../repositories/workout_session_repository.dart';
import '../repositories/local_workout_session_repository.dart';
import '../screens/home/bloc/home_bloc.dart';
import '../screens/workout_detail/bloc/workout_detail_bloc.dart';
import '../screens/workout_session/bloc/workout_session_bloc.dart';

/// Global instance of GetIt for dependency injection
final getIt = GetIt.instance;

/// Sets up all dependencies
/// Call this once at app startup
Future<void> setupDependencies() async {
  // Register repositories
  // Using registerLazySingleton means the instance is created only when first accessed
  // and then reused. For repositories that maintain state or connections, this is ideal.
  getIt.registerLazySingleton<WorkoutRepository>(
    () => MockWorkoutRepository(),
  );

  getIt.registerLazySingleton<ExerciseRepository>(
    () => MockExerciseRepository(),
  );

  getIt.registerLazySingleton<WorkoutSessionRepository>(
    () => LocalWorkoutSessionRepository(),
  );

  // Register BLoCs
  // Using registerFactory means a new instance is created each time
  // This is appropriate for BLoCs that should be fresh for each screen
  getIt.registerFactory<HomeBloc>(
    () => HomeBloc(repository: getIt<WorkoutRepository>()),
  );

  getIt.registerFactory<WorkoutDetailBloc>(
    () => WorkoutDetailBloc(workoutRepository: getIt<WorkoutRepository>()),
  );

  // WorkoutSessionBloc is a LazySingleton because the session main screen
  // and the exercise logging screen edit the same session graph and must
  // share an instance. Disposed manually after a finish/cancel, which is
  // handled by the bloc itself returning to SessionIdle.
  getIt.registerLazySingleton<WorkoutSessionBloc>(
    () => WorkoutSessionBloc(
      repository: getIt<WorkoutSessionRepository>(),
    ),
  );
}
