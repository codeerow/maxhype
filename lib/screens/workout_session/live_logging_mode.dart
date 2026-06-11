import 'package:flutter/widgets.dart';

import '../../models/exercise.dart';
import '../../models/session/session_exercise.dart';
import '../../models/session/session_set.dart';
import 'bloc/workout_session_bloc.dart';
import 'bloc/workout_session_event.dart';
import 'bloc/workout_session_state.dart';
import 'logging_mode.dart';

/// [LoggingMode] backed by `WorkoutSessionBloc`. Mutations fire events
/// on the bloc; the bottom button toggles between Log Set / Done and
/// (when tapped) either logs the current target row or confirms
/// completion of the exercise.
class LiveLoggingMode extends LoggingMode {
  LiveLoggingMode({
    required this.bloc,
    required this.exercise,
    required this.focusWeight,
  });

  final WorkoutSessionBloc bloc;
  final SessionExercise exercise;
  final void Function(String setId) focusWeight;

  @override
  bool get isPreview => false;

  @override
  SessionExercise get exerciseSnapshot => exercise;

  @override
  int get restSecondsHint => bloc.state is SessionActive
      ? (bloc.state as SessionActive).session.restDurationSeconds
      : 120;

  @override
  String get bottomLabel =>
      exercise.isAwaitingDoneConfirmation ? 'Done' : 'Log Set';

  @override
  bool get bottomEnabled =>
      exercise.isAwaitingDoneConfirmation ||
      (exercise.currentTarget?.isFilled ?? false);

  @override
  void onBottomTap(BuildContext context) {
    if (exercise.isAwaitingDoneConfirmation) {
      bloc.add(MarkExerciseDone(exercise.slotId));
      return;
    }
    final target = exercise.currentTarget;
    if (target == null || !target.isFilled) return;

    bloc.add(LogSet(
      exerciseId: exercise.slotId,
      setId: target.id,
      weight: target.weight!,
      reps: target.reps!,
      kind: target.kind,
    ));

    // Pick the next row to chain into, in the same priority order as
    // [SessionExercise.currentTarget]. Skip the row we just logged
    // because the state mutation hasn't been observed by this build
    // yet.
    SessionSet? pickNext(Iterable<SessionSet> rows) {
      for (final s in rows) {
        if (!s.isLogged && s.id != target.id) return s;
      }
      return null;
    }

    final nextTarget = pickNext(exercise.warmups) ??
        pickNext(exercise.sets) ??
        pickNext(exercise.dropSets);
    bloc.add(const StartRestTimer());
    if (nextTarget != null) {
      final key = switch (nextTarget.kind) {
        SetKind.warmup => 'warmup_${nextTarget.id}',
        SetKind.dropSet => 'drop_${nextTarget.id}',
        SetKind.effective => nextTarget.id,
      };
      focusWeight(key);
    }
  }

  @override
  void onAddRow(SetKind kind) {
    bloc.add(AddSet(exercise.slotId, kind: kind));
  }

  @override
  void onDeleteRow(String setId, SetKind kind) {
    bloc.add(DeleteSet(
      exerciseId: exercise.slotId,
      setId: setId,
      kind: kind,
    ));
  }

  @override
  void onWeightChanged({
    required String setId,
    required SetKind kind,
    required double? weight,
  }) {
    bloc.add(UpdateSetDraft(
      exerciseId: exercise.slotId,
      setId: setId,
      weight: weight,
      kind: kind,
      clearWeight: weight == null,
    ));
  }

  @override
  void onRepsChanged({
    required String setId,
    required SetKind kind,
    required int? reps,
  }) {
    bloc.add(UpdateSetDraft(
      exerciseId: exercise.slotId,
      setId: setId,
      reps: reps,
      kind: kind,
      clearReps: reps == null,
    ));
  }

  @override
  void onNotesChanged(String notes) {
    bloc.add(UpdateNotes(
      exerciseId: exercise.slotId,
      notes: notes,
    ));
  }

  @override
  void onReplaceExercise(
    BuildContext context,
    String oldExerciseId,
    Exercise newExercise,
  ) {
    bloc.add(ReplaceExercise(
      oldExerciseId: oldExerciseId,
      newExercise: newExercise,
    ));
  }
}
