import '../../../models/exercise.dart';
import '../../../models/session/session_warmup_type.dart';
import '../../../models/workout.dart';

sealed class WorkoutSessionEvent {
  const WorkoutSessionEvent();
}

class StartSession extends WorkoutSessionEvent {
  final Workout workout;
  const StartSession(this.workout);
}

class RestoreSession extends WorkoutSessionEvent {
  const RestoreSession();
}

class LogSet extends WorkoutSessionEvent {
  final String exerciseId;
  final String setId;
  final double weight;
  final int reps;
  final bool isWarmup;
  const LogSet({
    required this.exerciseId,
    required this.setId,
    required this.weight,
    required this.reps,
    this.isWarmup = false,
  });
}

class UpdateSetDraft extends WorkoutSessionEvent {
  final String exerciseId;
  final String setId;
  final double? weight;
  final int? reps;
  final bool isWarmup;
  final bool clearWeight;
  final bool clearReps;
  const UpdateSetDraft({
    required this.exerciseId,
    required this.setId,
    this.weight,
    this.reps,
    this.isWarmup = false,
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
  const AddSet(this.exerciseId);
}

class DeleteSet extends WorkoutSessionEvent {
  final String exerciseId;
  final String setId;
  final bool isWarmup;
  const DeleteSet({
    required this.exerciseId,
    required this.setId,
    this.isWarmup = false,
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
  final Duration duration;
  const StartRestTimer({this.duration = const Duration(seconds: 120)});
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

