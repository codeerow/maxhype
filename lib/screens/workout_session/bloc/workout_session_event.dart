import '../../../models/exercise.dart';
import '../../../models/session/preview_draft.dart';
import '../../../models/session/session_set.dart';
import '../../../models/session/session_warmup_type.dart';
import '../../../models/workout.dart';

sealed class WorkoutSessionEvent {
  const WorkoutSessionEvent();
}

class StartSession extends WorkoutSessionEvent {
  final Workout workout;

  /// Drafts captured on the preview screen before Start was pressed.
  /// Keys are exerciseIds matching [Workout.exercises]; missing keys
  /// mean "no preview edits for that exercise — use the default set
  /// layout from the workout template". When provided, the bloc takes
  /// the draft's effective sets, warmups, and drop sets verbatim so
  /// the user's pre-typed weight/reps and added rows appear in the
  /// live session (brief Phase 3 Part 3 §6, clarifications 6.15,
  /// 6.18).
  final Map<String, PreviewExerciseDraft> previewDrafts;

  const StartSession(this.workout, {this.previewDrafts = const {}});
}

class RestoreSession extends WorkoutSessionEvent {
  const RestoreSession();
}

class LogSet extends WorkoutSessionEvent {
  final String exerciseId;
  final String setId;
  final double weight;
  final int reps;
  final SetKind kind;
  const LogSet({
    required this.exerciseId,
    required this.setId,
    required this.weight,
    required this.reps,
    this.kind = SetKind.effective,
  });
}

class UpdateSetDraft extends WorkoutSessionEvent {
  final String exerciseId;
  final String setId;
  final double? weight;
  final int? reps;
  final SetKind kind;
  final bool clearWeight;
  final bool clearReps;
  const UpdateSetDraft({
    required this.exerciseId,
    required this.setId,
    this.weight,
    this.reps,
    this.kind = SetKind.effective,
    this.clearWeight = false,
    this.clearReps = false,
  });
}

class MarkExerciseDone extends WorkoutSessionEvent {
  final String exerciseId;
  const MarkExerciseDone(this.exerciseId);
}

class AddSet extends WorkoutSessionEvent {
  final String exerciseId;
  final SetKind kind;
  const AddSet(this.exerciseId, {this.kind = SetKind.effective});
}

class DeleteSet extends WorkoutSessionEvent {
  final String exerciseId;
  final String setId;
  final SetKind kind;
  const DeleteSet({
    required this.exerciseId,
    required this.setId,
    this.kind = SetKind.effective,
  });
}

class DeleteExercise extends WorkoutSessionEvent {
  final String exerciseId;
  const DeleteExercise(this.exerciseId);
}

class ReplaceExercise extends WorkoutSessionEvent {
  final String oldExerciseId;
  final Exercise newExercise;
  const ReplaceExercise({
    required this.oldExerciseId,
    required this.newExercise,
  });
}

class UpdateNotes extends WorkoutSessionEvent {
  final String exerciseId;
  final String notes;
  const UpdateNotes({required this.exerciseId, required this.notes});
}

class SetWarmup extends WorkoutSessionEvent {
  final WarmupType warmup;
  const SetWarmup(this.warmup);
}

class StartRestTimer extends WorkoutSessionEvent {
  /// Optional override. When null the bloc uses the session-configured
  /// `restDurationSeconds`, which is the single source of truth.
  final Duration? duration;
  const StartRestTimer({this.duration});
}

class CancelRestTimer extends WorkoutSessionEvent {
  const CancelRestTimer();
}

/// Shift the active rest end-time by [delta] (positive or negative). If the
/// resulting end-time is in the past, the timer is cancelled.
class AdjustRestTimer extends WorkoutSessionEvent {
  final Duration delta;
  const AdjustRestTimer(this.delta);
}

class CancelWorkout extends WorkoutSessionEvent {
  const CancelWorkout();
}

class FinishWorkout extends WorkoutSessionEvent {
  const FinishWorkout();
}

/// Internal: emitted by the bloc itself when the async PR-cache load
/// (`_loadPrsFor`) finishes, so UI bound via BlocConsumer rebuilds and
/// the PR header shows up without waiting for the next user action.
class PrCacheLoaded extends WorkoutSessionEvent {
  const PrCacheLoaded();
}
