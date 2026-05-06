import '../../../models/session/workout_session.dart';

sealed class WorkoutSessionState {
  const WorkoutSessionState();
}

class SessionIdle extends WorkoutSessionState {
  const SessionIdle();
}

class SessionLoading extends WorkoutSessionState {
  const SessionLoading();
}

class SessionActive extends WorkoutSessionState {
  final WorkoutSession session;

  /// Transient: id of an exercise that just had a set logged this turn.
  /// Consumed by the UI to fire a one-shot glow pulse, then cleared.
  final String? justLoggedExerciseId;

  /// Transient: id of an exercise that just transitioned to completed.
  /// Consumed by the UI to fire the scale-in checkmark animation.
  final String? justCompletedExerciseId;

  /// Transient: true after a successful FinishWorkout/CancelWorkout cleanup
  /// step that should pop the screen. Cleared after listener handles it.
  final bool shouldPopAfterFinish;

  /// Transient: true when MarkExerciseDone fires; UI listens to navigate back.
  final bool exerciseJustClosed;

  const SessionActive(
    this.session, {
    this.justLoggedExerciseId,
    this.justCompletedExerciseId,
    this.shouldPopAfterFinish = false,
    this.exerciseJustClosed = false,
  });

  SessionActive copyWith({
    WorkoutSession? session,
    Object? justLoggedExerciseId = _sentinel,
    Object? justCompletedExerciseId = _sentinel,
    bool? shouldPopAfterFinish,
    bool? exerciseJustClosed,
  }) {
    return SessionActive(
      session ?? this.session,
      justLoggedExerciseId: identical(justLoggedExerciseId, _sentinel)
          ? this.justLoggedExerciseId
          : justLoggedExerciseId as String?,
      justCompletedExerciseId: identical(justCompletedExerciseId, _sentinel)
          ? this.justCompletedExerciseId
          : justCompletedExerciseId as String?,
      shouldPopAfterFinish: shouldPopAfterFinish ?? this.shouldPopAfterFinish,
      exerciseJustClosed: exerciseJustClosed ?? this.exerciseJustClosed,
    );
  }
}

class SessionFinishing extends WorkoutSessionState {
  const SessionFinishing();
}

class SessionFinished extends WorkoutSessionState {
  const SessionFinished();
}

class SessionCancelled extends WorkoutSessionState {
  const SessionCancelled();
}

const Object _sentinel = Object();
