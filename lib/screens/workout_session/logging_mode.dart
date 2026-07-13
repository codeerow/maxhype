import 'package:flutter/material.dart';

import '../../models/exercise.dart';
import '../../models/session/session_exercise.dart';
import '../../models/session/session_set.dart';

/// Abstracts the two ways the exercise logging screen can run:
///
///   - [LiveLoggingMode] — backed by `WorkoutSessionBloc`. Mutations
///     fire LogSet / DeleteSet / UpdateSetDraft / AddSet on the bloc,
///     bottom button toggles between Log Set / Done.
///   - [PreviewLoggingMode] — backed by `WorkoutPreviewBloc`. No
///     active session exists yet; the screen lets the user preview
///     the exercise, edit weight/reps as a draft, and add/delete
///     rows. Bottom button reads "Start Workout" and creates the
///     session with the drafts merged in (brief Phase 3 Part 3 §6).
///
/// The two modes share the exact same scaffold widget — UI, focus
/// chain, swipe-to-delete, three-dot menu — and differ only in which
/// store they read/write.
abstract class LoggingMode {
  bool get isPreview;

  /// The current row layout shown on screen. In live mode this is the
  /// matching [SessionExercise] from `SessionActive.session`; in
  /// preview mode it's a snapshot derived from the preview draft.
  SessionExercise get exerciseSnapshot;

  /// Seconds shown in the Rest pill. In live mode this is the active
  /// session's `restDurationSeconds`; in preview the workout-default
  /// (120 unless overridden). The pill is informational in preview —
  /// no timer ticks until Start Workout flips the screen into live.
  int get restSecondsHint;

  /// Planned weight/reps for the current exercise, used as the muted
  /// placeholder on empty rows when there's no logged/history value yet.
  /// Sourced from the workout's exercise (its `weight` / `reps`), so it's
  /// correct for generated and hand-curated workouts alike. Null when the
  /// exercise carries no planned prescription.
  double? get plannedWeight;
  int? get plannedReps;

  /// Bottom-button label.
  String get bottomLabel;

  /// True when the bottom button should be enabled given the current
  /// draft / logged state.
  bool get bottomEnabled;

  void onBottomTap(BuildContext context);

  void onAddRow(SetKind kind);

  void onDeleteRow(String setId, SetKind kind);

  void onWeightChanged({
    required String setId,
    required SetKind kind,
    required double? weight,
  });

  void onRepsChanged({
    required String setId,
    required SetKind kind,
    required int? reps,
  });

  void onNotesChanged(String notes);

  /// Swap the currently displayed exercise for [newExercise]. Live
  /// mode dispatches to WorkoutSessionBloc.ReplaceExercise (preserves
  /// logged sets, notes, warmups, drops, rest timer). Preview mode
  /// dispatches to WorkoutDetailBloc.ReplaceExercise with
  /// `persistToTemplate: false` — the swap stays local to the detail
  /// bloc's state and never mutates the shared workout template.
  void onReplaceExercise(
    BuildContext context,
    String oldExerciseId,
    Exercise newExercise,
  );
}
