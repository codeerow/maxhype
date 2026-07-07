import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';
import 'haptic_manager.dart';
import '../repositories/workout_repository.dart';
import '../repositories/mock_workout_repository.dart';
import '../repositories/exercise_repository.dart';
import '../repositories/mock_exercise_repository.dart';
import '../repositories/asset_exercise_repository.dart';
import '../repositories/fitness_plan_repository.dart';
import '../repositories/local_fitness_plan_repository.dart';
import '../repositories/workout_session_repository.dart';
import '../repositories/local_workout_session_repository.dart';
import '../repositories/personal_record_repository.dart';
import '../repositories/local_personal_record_repository.dart';
import '../repositories/workout_completion_repository.dart';
import '../repositories/local_workout_completion_repository.dart';
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

  // Generator library (Phase 4 Part 1). Registered under its concrete type so
  // it coexists with the hand-curated MockExerciseRepository (which the home
  // workouts depend on). The JSON asset is loaded eagerly below so lookups are
  // synchronous. Part 2's generator reads exercises, metadata tables, and PPL
  // templates from here.
  getIt.registerLazySingleton<AssetExerciseRepository>(
    () => AssetExerciseRepository(),
  );

  // Persistent user fitness plan (split, days/week, duration, experience,
  // units, sex, age, weight). Survives restarts via fitness_plan.json.
  getIt.registerLazySingleton<FitnessPlanRepository>(
    () => LocalFitnessPlanRepository(),
  );

  getIt.registerLazySingleton<WorkoutSessionRepository>(
    () => LocalWorkoutSessionRepository(
      onArchive: () => getIt<PersonalRecordRepository>().invalidate(),
    ),
  );

  // Personal records — derived from the same workout_history.jsonl the
  // session repository writes to. Cache invalidation is wired through the
  // session repo's onArchive callback so a freshly finished workout shows
  // up the next time the user opens the logging screen.
  getIt.registerLazySingleton<PersonalRecordRepository>(
    () => LocalPersonalRecordRepository(),
  );

  // Per-workout completion state, drives the "Completed · N mins"
  // home-card variant (Phase 3 Part 3, Item 1). Persisted in
  // `workout_completion.json` next to the active session and history.
  getIt.registerLazySingleton<WorkoutCompletionRepository>(
    () => LocalWorkoutCompletionRepository(),
  );

  // Shared RouteObserver — wired into MaterialApp.navigatorObservers and
  // subscribed by RouteAware widgets that need to react to becoming-visible
  // again after a child route is popped (e.g., the session screen pulses
  // the active exercise card on pop-back from the logging screen).
  getIt.registerLazySingleton<RouteObserver<PageRoute<dynamic>>>(
    () => RouteObserver<PageRoute<dynamic>>(),
  );

  // Centralized haptic feedback. UI code calls `getIt<HapticManager>().*`
  // instead of HapticFeedback directly so intensity tiers are consistent
  // and easy to mute / swap.
  getIt.registerLazySingleton<HapticManager>(
    () => DefaultHapticManager(),
  );

  // Register BLoCs
  // Using registerFactory means a new instance is created each time
  // This is appropriate for BLoCs that should be fresh for each screen
  getIt.registerFactory<HomeBloc>(
    () => HomeBloc(
      repository: getIt<WorkoutRepository>(),
      completionRepository: getIt<WorkoutCompletionRepository>(),
    ),
  );

  getIt.registerFactory<WorkoutDetailBloc>(
    () => WorkoutDetailBloc(
      workoutRepository: getIt<WorkoutRepository>(),
      completionRepository: getIt<WorkoutCompletionRepository>(),
    ),
  );

  // WorkoutSessionBloc is a LazySingleton because the session main screen
  // and the exercise logging screen edit the same session graph and must
  // share an instance. Disposed manually after a finish/cancel, which is
  // handled by the bloc itself returning to SessionIdle.
  getIt.registerLazySingleton<WorkoutSessionBloc>(
    () => WorkoutSessionBloc(
      repository: getIt<WorkoutSessionRepository>(),
      prRepository: getIt<PersonalRecordRepository>(),
      completionRepository: getIt<WorkoutCompletionRepository>(),
    ),
  );

  // Eagerly load the generator library asset so its queries are synchronous
  // once the app is running. Cheap (one bundled JSON read) and keeps Part 2's
  // generator free of async plumbing on every lookup.
  await getIt<AssetExerciseRepository>().load();
}
