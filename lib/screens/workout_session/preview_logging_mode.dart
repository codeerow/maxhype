import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../main.dart' show MyApp;
import '../../models/exercise.dart';
import '../../models/muscle_group.dart';
import '../../models/session/preview_draft.dart';
import '../../models/session/session_exercise.dart';
import '../../models/session/session_set.dart';
import '../../models/workout.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../workout_detail/bloc/workout_detail_bloc.dart';
import '../workout_detail/bloc/workout_detail_event.dart'
    as detail_event;
import '../workout_detail/bloc/workout_preview_bloc.dart';
import 'bloc/workout_session_bloc.dart';
import 'bloc/workout_session_event.dart';
import 'bloc/workout_session_state.dart';
import 'exercise_logging_screen.dart';
import 'logging_mode.dart';
import 'workout_session_screen.dart';

/// [LoggingMode] backed by [WorkoutPreviewBloc]. Used before the user
/// taps Start Workout — mutations stay local to the preview cubit, no
/// session exists yet (brief Phase 3 Part 3 §6: "Previewing must not
/// create an active workout session").
///
/// The bottom button reads "Start Workout"; tapping it merges the
/// captured drafts into [StartSession] and replaces the preview route
/// with the live session screen.
class PreviewLoggingMode extends LoggingMode {
  PreviewLoggingMode({
    required this.workout,
    required this.exerciseId,
    required this.previewBloc,
    required this.sessionBloc,
  });

  final Workout workout;
  final String exerciseId;
  final WorkoutPreviewBloc previewBloc;
  final WorkoutSessionBloc sessionBloc;

  @override
  bool get isPreview => true;

  /// Project the preview draft onto the same [SessionExercise] shape
  /// the scaffold knows how to render. Equipment, muscle groups, and
  /// name come from the workout template; rows come from the draft.
  @override
  SessionExercise get exerciseSnapshot {
    final ex = workout.exercises.firstWhere(
      (e) => e.id == exerciseId,
      orElse: () => throw StateError(
        'Preview opened for unknown exerciseId $exerciseId',
      ),
    );
    final draft = previewBloc.draftFor(exerciseId);
    final sets = draft.sets.isNotEmpty
        ? draft.sets
        : List<SessionSet>.generate(
            ex.sets,
            (i) => SessionSet(id: 'preview_seed_${ex.id}_$i'),
          );
    return SessionExercise(
      exerciseId: ex.id,
      name: ex.name,
      equipment: ex.equipmentType,
      muscleGroups: ex.muscleGroups.isEmpty
          ? const <MuscleGroup>[MuscleGroup.chest]
          : ex.muscleGroups,
      targetSets: sets.length,
      sets: sets,
      warmups: draft.warmups,
      dropSets: draft.dropSets,
      notes: draft.notes,
    );
  }

  @override
  int get restSecondsHint {
    // Preview reads the workout-level default. We don't have a
    // per-exercise rest field on Exercise (yet) — use 120s, matching
    // WorkoutSession.restDurationSeconds default, so the pill reads
    // "Rest 2:00" out of the box.
    return 120;
  }

  @override
  String get bottomLabel => 'Start Workout';

  @override
  bool get bottomEnabled => true;

  @override
  void onBottomTap(BuildContext context) {
    final cur = sessionBloc.state;
    if (cur is SessionActive && cur.session.workoutId != workout.id) {
      // Brief §4 — block second-workout starts with the premium
      // toast. Preview mode reaches Start via the same guard so a
      // user who previews another workout mid-session can't bypass
      // the rule.
      AppToast.showPremium(
        context,
        'Finish your current workout first',
        accent: AppTheme.primaryOrange,
        // Same lift as the detail-screen Start blocker so the home
        // tab row stays readable.
        bottomOffset: 64,
      );
      return;
    }
    final drafts =
        Map<String, PreviewExerciseDraft>.from(previewBloc.state.drafts);
    sessionBloc.add(StartSession(workout, previewDrafts: drafts));
    // Keep the user on the same exercise they were previewing — the
    // brief calls it out: starting a workout from the logging
    // (preview) screen must leave the user on that exercise's
    // logging screen, not bounce them to the session list. We
    // rebuild the route stack to:
    //
    //   [root → WorkoutSessionScreen.restored() → live logging]
    //
    // so a subsequent back tap pops to the session's exercise list
    // (natural flow) rather than back into the now-stale preview.
    final nav = Navigator.of(context);
    nav.pushAndRemoveUntil(
      CupertinoPageRoute<void>(
        builder: (_) => WorkoutSessionScreen.restored(),
      ),
      (route) => route.isFirst,
    );
    nav.push(
      CupertinoPageRoute<void>(
        builder: (_) => ExerciseLoggingScreen.live(
          exerciseId: exerciseId,
          bloc: sessionBloc,
        ),
      ),
    );
  }

  @override
  void onAddRow(SetKind kind) {
    previewBloc.addRow(exerciseId, kind);
  }

  @override
  void onDeleteRow(String setId, SetKind kind) {
    previewBloc.removeRow(exerciseId, setId, kind);
  }

  @override
  void onWeightChanged({
    required String setId,
    required SetKind kind,
    required double? weight,
  }) {
    previewBloc.setWeight(
      exerciseId: exerciseId,
      setId: setId,
      kind: kind,
      weight: weight,
      clear: weight == null,
    );
  }

  @override
  void onRepsChanged({
    required String setId,
    required SetKind kind,
    required int? reps,
  }) {
    previewBloc.setReps(
      exerciseId: exerciseId,
      setId: setId,
      kind: kind,
      reps: reps,
      clear: reps == null,
    );
  }

  @override
  void onNotesChanged(String notes) {
    // Preview notes carry over into the live session via the draft —
    // [StartSession] reads `draft.notes` for each prefilled exercise.
    previewBloc.setNotes(exerciseId, notes);
  }

  @override
  void onReplaceExercise(
    BuildContext context,
    String oldExerciseId,
    Exercise newExercise,
  ) {
    // Replace from preview behaves the same as Replace from the
    // workout-detail screen: pop the preview so the user lands
    // back on the detail screen, then dispatch the mutation to
    // WorkoutDetailBloc which persists the swap via
    // WorkoutRepository (clarification 6.17). The toast lives on
    // the detail route so it survives the pop.
    final detailBloc = context.read<WorkoutDetailBloc>();
    Navigator.of(context).pop();
    detailBloc.add(
      detail_event.ReplaceExercise(
        workoutId: workout.id,
        oldExerciseId: oldExerciseId,
        newExercise: newExercise,
        // Preview replace must not mutate the shared workout template
        // — the swap stays inside this detail bloc's state and only
        // carries into the live session if the user taps Start.
        persistToTemplate: false,
      ),
    );
    // Drop the obsolete draft so it doesn't ride into the next
    // StartSession on the old exerciseId.
    previewBloc.dropDraft(oldExerciseId);
    // The preview screen has just popped — the detail screen is
    // the topmost route. Show the same confirmation toast the
    // detail-screen Replace flow shows, on the root overlay so it
    // doesn't get torn down with the popped route.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final overlay = MyApp.rootNavKey.currentState?.overlay;
      if (overlay == null) return;
      AppToast.showOnOverlay(
        overlay,
        'Replaced with ${newExercise.name}',
      );
    });
  }
}
