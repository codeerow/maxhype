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

/// Active session — pure snapshot of session data. Animation triggers
/// (`exercise just completed`, `set just logged`, `exercise screen should
/// close now`) are NOT stored here; they flow through
/// `WorkoutSessionBloc.events`, a side-channel `Stream<SessionEvent>` that
/// each subscriber consumes once and forgets.
class SessionActive extends WorkoutSessionState {
  final WorkoutSession session;

  const SessionActive(this.session);
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
