import 'package:get_it/get_it.dart';
import '../repositories/workout_repository.dart';
import '../repositories/mock_workout_repository.dart';
import '../screens/home/bloc/home_bloc.dart';

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

  // Register BLoCs
  // Using registerFactory means a new instance is created each time
  // This is appropriate for BLoCs that should be fresh for each screen
  getIt.registerFactory<HomeBloc>(
    () => HomeBloc(repository: getIt<WorkoutRepository>()),
  );
}
