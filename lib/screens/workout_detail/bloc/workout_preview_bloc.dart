import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/session/preview_draft.dart';
import '../../../models/session/session_set.dart';

/// Holds preview-screen drafts before the user taps Start Workout
/// (milestone Phase 3 Part 3, Item 6).
///
/// Lifetime: one per workout-detail screen instance. Cleared when the
/// user starts the workout (drafts get merged into the new session by
/// WorkoutSessionBloc.StartSession) or when they back out without
/// starting.
class WorkoutPreviewBloc extends Cubit<WorkoutPreviewState> {
  WorkoutPreviewBloc() : super(const WorkoutPreviewState());

  final _rng = Random();

  String _newId(String prefix) {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = _rng.nextInt(1 << 32).toRadixString(36);
    return '${prefix}_${t}_$r';
  }

  PreviewExerciseDraft draftFor(String exerciseId) {
    return state.drafts[exerciseId] ??
        PreviewExerciseDraft(exerciseId: exerciseId);
  }

  void setWeight({
    required String exerciseId,
    required String setId,
    required SetKind kind,
    required double? weight,
    required bool clear,
  }) {
    _mutateRow(exerciseId, setId, kind, (s) {
      return s.copyWith(weight: clear ? null : (weight ?? s.weight));
    });
  }

  void setReps({
    required String exerciseId,
    required String setId,
    required SetKind kind,
    required int? reps,
    required bool clear,
  }) {
    _mutateRow(exerciseId, setId, kind, (s) {
      return s.copyWith(reps: clear ? null : (reps ?? s.reps));
    });
  }

  /// Add a row of [kind] to the preview draft. Returns the new id so
  /// callers can focus it (matches the live-session flow on Add Set).
  String addRow(String exerciseId, SetKind kind) {
    final draft = draftFor(exerciseId);
    final id = _newId(switch (kind) {
      SetKind.effective => 'pset',
      SetKind.warmup => 'pwset',
      SetKind.dropSet => 'pdset',
    });
    final row = SessionSet(id: id, kind: kind);
    final next = switch (kind) {
      SetKind.effective => draft.copyWith(sets: [...draft.sets, row]),
      SetKind.warmup => draft.copyWith(warmups: [...draft.warmups, row]),
      SetKind.dropSet =>
        draft.copyWith(dropSets: [...draft.dropSets, row]),
    };
    _storeDraft(next);
    return id;
  }

  void removeRow(String exerciseId, String setId, SetKind kind) {
    final draft = draftFor(exerciseId);
    final next = switch (kind) {
      SetKind.effective => draft.copyWith(
          sets: draft.sets.where((s) => s.id != setId).toList(),
        ),
      SetKind.warmup => draft.copyWith(
          warmups: draft.warmups.where((s) => s.id != setId).toList(),
        ),
      SetKind.dropSet => draft.copyWith(
          dropSets: draft.dropSets.where((s) => s.id != setId).toList(),
        ),
    };
    _storeDraft(next);
  }

  /// Seed an effective-sets list from the workout template the first
  /// time the user opens the exercise in preview. Idempotent — only
  /// runs when the draft has no rows yet.
  void seedEffectiveSets(String exerciseId, int targetSets) {
    final existing = state.drafts[exerciseId];
    if (existing != null && existing.sets.isNotEmpty) return;
    final seed = PreviewExerciseDraft(
      exerciseId: exerciseId,
      sets: List.generate(
        targetSets,
        (_) => SessionSet(id: _newId('pset')),
      ),
      warmups: existing?.warmups ?? const [],
      dropSets: existing?.dropSets ?? const [],
      notes: existing?.notes ?? '',
    );
    _storeDraft(seed);
  }

  void clear() => emit(const WorkoutPreviewState());

  /// Forget any draft for [exerciseId] — used when the exercise is
  /// replaced via the three-dot menu so the obsolete draft doesn't
  /// ride into the next StartSession.
  void dropDraft(String exerciseId) {
    if (!state.drafts.containsKey(exerciseId)) return;
    final next = Map<String, PreviewExerciseDraft>.from(state.drafts)
      ..remove(exerciseId);
    emit(WorkoutPreviewState(drafts: next));
  }

  void setNotes(String exerciseId, String notes) {
    _storeDraft(draftFor(exerciseId).copyWith(notes: notes));
  }

  void _storeDraft(PreviewExerciseDraft draft) {
    final next = Map<String, PreviewExerciseDraft>.from(state.drafts);
    next[draft.exerciseId] = draft;
    emit(WorkoutPreviewState(drafts: next));
  }

  void _mutateRow(
    String exerciseId,
    String setId,
    SetKind kind,
    SessionSet Function(SessionSet) fn,
  ) {
    final draft = draftFor(exerciseId);
    final next = switch (kind) {
      SetKind.effective => draft.copyWith(
          sets: draft.sets.map((s) => s.id == setId ? fn(s) : s).toList(),
        ),
      SetKind.warmup => draft.copyWith(
          warmups: draft.warmups
              .map((s) => s.id == setId ? fn(s) : s)
              .toList(),
        ),
      SetKind.dropSet => draft.copyWith(
          dropSets: draft.dropSets
              .map((s) => s.id == setId ? fn(s) : s)
              .toList(),
        ),
    };
    _storeDraft(next);
  }
}

class WorkoutPreviewState {
  /// Map keyed by exerciseId. Empty when the user hasn't touched any
  /// exercise in preview yet.
  final Map<String, PreviewExerciseDraft> drafts;

  const WorkoutPreviewState({this.drafts = const {}});
}
