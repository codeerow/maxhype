import 'dart:async';
import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../models/session/session_exercise.dart';
import '../../../models/session/session_set.dart';
import '../../../models/session/workout_session.dart';
import '../../../repositories/workout_session_repository.dart';
import 'workout_session_event.dart';
import 'workout_session_state.dart';

/// Single source of truth for the active workout session.
///
/// Persistence strategy:
/// - Mutations call `_schedulePersist()`, which debounces saves by 1.5s so we
///   never write on every keystroke while editing weight/reps.
/// - Critical events (LogSet, MarkExerciseDone, CancelWorkout, FinishWorkout)
///   call `_flushPersist()` to write immediately — these are the moments worth
///   never losing.
class WorkoutSessionBloc
    extends Bloc<WorkoutSessionEvent, WorkoutSessionState> {
  WorkoutSessionBloc({required this.repository}) : super(const SessionIdle()) {
    on<StartSession>(_onStartSession);
    on<RestoreSession>(_onRestoreSession);
    on<LogSet>(_onLogSet);
    on<UpdateSetDraft>(_onUpdateSetDraft);
    on<MarkExerciseDone>(_onMarkExerciseDone);
    on<AddSet>(_onAddSet);
    on<DeleteSet>(_onDeleteSet);
    on<DeleteExercise>(_onDeleteExercise);
    on<ReplaceExercise>(_onReplaceExercise);
    on<UpdateNotes>(_onUpdateNotes);
    on<SetWarmup>(_onSetWarmup);
    on<StartRestTimer>(_onStartRestTimer);
    on<CancelRestTimer>(_onCancelRestTimer);
    on<AdjustRestTimer>(_onAdjustRestTimer);
    on<CancelWorkout>(_onCancelWorkout);
    on<FinishWorkout>(_onFinishWorkout);
  }

  final WorkoutSessionRepository repository;

  Timer? _persistDebounce;
  final _idRng = Random();

  String _newId([String prefix = 'id']) {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = _idRng.nextInt(1 << 32).toRadixString(36);
    return '${prefix}_${t}_$r';
  }

  void _schedulePersist(WorkoutSession session) {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 1500), () {
      repository.save(session);
    });
  }

  Future<void> _flushPersist(WorkoutSession session) async {
    _persistDebounce?.cancel();
    _persistDebounce = null;
    await repository.save(session);
  }

  WorkoutSession? get _current {
    final s = state;
    return s is SessionActive ? s.session : null;
  }

  /// Common shape of mutating handlers: read current session, build the next
  /// one, emit, persist (debounced or immediate). Returns the updated
  /// session for handlers that need to chain follow-up logic.
  Future<WorkoutSession?> _mutate(
    Emitter<WorkoutSessionState> emit,
    WorkoutSession Function(WorkoutSession) update, {
    bool flush = false,
  }) async {
    final cur = _current;
    if (cur == null) return null;
    final next = update(cur);
    emit(SessionActive(next));
    if (flush) {
      await _flushPersist(next);
    } else {
      _schedulePersist(next);
    }
    return next;
  }

  // ----- Handlers -----

  Future<void> _onStartSession(
    StartSession event,
    Emitter<WorkoutSessionState> emit,
  ) async {
    final w = event.workout;
    final exercises = w.exercises
        .map(
          (ex) => SessionExercise(
            exerciseId: ex.id,
            name: ex.name,
            equipment: ex.equipmentType,
            muscleGroups: ex.muscleGroups,
            targetSets: ex.sets,
            sets: List.generate(
              ex.sets,
              (_) => SessionSet(id: _newId('set')),
            ),
            warmupSet: SessionSet(id: _newId('wset')),
            notes: '',
          ),
        )
        .toList();

    final session = WorkoutSession(
      id: _newId('session'),
      workoutId: w.id,
      workoutName: w.title,
      startedAt: DateTime.now(),
      exercises: exercises,
    );

    emit(SessionActive(session));
    await _flushPersist(session);
  }

  Future<void> _onRestoreSession(
    RestoreSession event,
    Emitter<WorkoutSessionState> emit,
  ) async {
    emit(const SessionLoading());
    final restored = await repository.loadActive();
    if (restored == null || restored.status != SessionStatus.active) {
      emit(const SessionIdle());
      return;
    }
    // Drop expired rest-end if past.
    final cleaned = (restored.activeRestEndsAt != null &&
            restored.activeRestEndsAt!.isBefore(DateTime.now()))
        ? restored.copyWith(activeRestEndsAt: null)
        : restored;
    emit(SessionActive(cleaned));
  }

  Future<void> _onLogSet(LogSet event, Emitter<WorkoutSessionState> emit) {
    return _mutate(emit, (cur) {
      final next = _mutateExercise(cur, event.exerciseId, (ex) {
        if (event.isWarmup) {
          return ex.copyWith(
            warmupSet:
                (ex.warmupSet ?? SessionSet(id: _newId('wset'))).copyWith(
              weight: event.weight,
              reps: event.reps,
              loggedAt: DateTime.now(),
            ),
          );
        }
        final newSets = ex.sets
            .map((s) => s.id == event.setId
                ? s.copyWith(
                    weight: event.weight,
                    reps: event.reps,
                    loggedAt: DateTime.now(),
                  )
                : s)
            .toList();
        return ex.copyWith(sets: newSets);
      });
      return next.copyWith(activeExerciseId: event.exerciseId);
    }, flush: true);
  }

  Future<void> _onUpdateSetDraft(
    UpdateSetDraft event,
    Emitter<WorkoutSessionState> emit,
  ) {
    return _mutate(emit, (cur) {
      return _mutateExercise(cur, event.exerciseId, (ex) {
        SessionSet apply(SessionSet s) {
          return s.copyWith(
            weight: event.clearWeight ? null : (event.weight ?? s.weight),
            reps: event.clearReps ? null : (event.reps ?? s.reps),
          );
        }

        if (event.isWarmup) {
          final w = ex.warmupSet ?? SessionSet(id: _newId('wset'));
          return ex.copyWith(warmupSet: apply(w));
        }
        final newSets = ex.sets
            .map((s) => s.id == event.setId ? apply(s) : s)
            .toList();
        return ex.copyWith(sets: newSets);
      });
    });
  }

  Future<void> _onMarkExerciseDone(
    MarkExerciseDone event,
    Emitter<WorkoutSessionState> emit,
  ) {
    return _mutate(emit, (cur) {
      return _mutateExercise(cur, event.exerciseId, (ex) {
        return ex.copyWith(completed: true);
      }).copyWith(
        activeExerciseId: cur.activeExerciseId == event.exerciseId
            ? null
            : cur.activeExerciseId,
        activeRestEndsAt: null,
      );
    }, flush: true);
  }

  Future<void> _onAddSet(AddSet event, Emitter<WorkoutSessionState> emit) {
    return _mutate(emit, (cur) {
      return _mutateExercise(cur, event.exerciseId, (ex) {
        return ex.copyWith(
          sets: [...ex.sets, SessionSet(id: _newId('set'))],
          targetSets: ex.targetSets + 1,
        );
      });
    });
  }

  Future<void> _onDeleteSet(
    DeleteSet event,
    Emitter<WorkoutSessionState> emit,
  ) {
    return _mutate(emit, (cur) {
      return _mutateExercise(cur, event.exerciseId, (ex) {
        if (event.isWarmup) {
          return ex.copyWith(warmupSet: null);
        }
        final newSets = ex.sets.where((s) => s.id != event.setId).toList();
        return ex.copyWith(
          sets: newSets,
          targetSets: max(0, ex.targetSets - 1),
        );
      });
    });
  }

  Future<void> _onDeleteExercise(
    DeleteExercise event,
    Emitter<WorkoutSessionState> emit,
  ) {
    return _mutate(emit, (cur) {
      return cur.copyWith(
        exercises: cur.exercises
            .where((e) => e.exerciseId != event.exerciseId)
            .toList(),
        activeExerciseId: cur.activeExerciseId == event.exerciseId
            ? null
            : cur.activeExerciseId,
      );
    });
  }

  Future<void> _onReplaceExercise(
    ReplaceExercise event,
    Emitter<WorkoutSessionState> emit,
  ) {
    return _mutate(emit, (cur) {
      final newEx = event.newExercise;
      final newList = cur.exercises.map((ex) {
        if (ex.exerciseId != event.oldExerciseId) return ex;
        // Carry sets, warmupSet, notes; bump targetSets to new exercise's
        // plan but keep extra logged sets so user doesn't lose work.
        final keptSets = ex.sets;
        final targetSets = max(newEx.sets, keptSets.length);
        return SessionExercise(
          exerciseId: newEx.id,
          name: newEx.name,
          equipment: newEx.equipmentType,
          muscleGroups: newEx.muscleGroups,
          targetSets: targetSets,
          sets: keptSets,
          warmupSet: ex.warmupSet,
          notes: ex.notes,
          completed: ex.completed,
        );
      }).toList();

      return cur.copyWith(
        exercises: newList,
        activeExerciseId: cur.activeExerciseId == event.oldExerciseId
            ? newEx.id
            : cur.activeExerciseId,
      );
    });
  }

  Future<void> _onUpdateNotes(
    UpdateNotes event,
    Emitter<WorkoutSessionState> emit,
  ) {
    return _mutate(emit, (cur) {
      return _mutateExercise(cur, event.exerciseId, (ex) {
        return ex.copyWith(notes: event.notes);
      });
    });
  }

  Future<void> _onSetWarmup(
    SetWarmup event,
    Emitter<WorkoutSessionState> emit,
  ) {
    return _mutate(emit, (cur) => cur.copyWith(warmup: event.warmup));
  }

  Future<void> _onStartRestTimer(
    StartRestTimer event,
    Emitter<WorkoutSessionState> emit,
  ) {
    return _mutate(emit, (cur) {
      // If event omits a duration, fall back to the session-configured one
      // (default 120s). Single source of truth lives on the session model.
      final dur = event.duration ?? Duration(seconds: cur.restDurationSeconds);
      return cur.copyWith(
        activeRestEndsAt: DateTime.now().add(dur),
        restDurationSeconds: dur.inSeconds,
      );
    });
  }

  Future<void> _onCancelRestTimer(
    CancelRestTimer event,
    Emitter<WorkoutSessionState> emit,
  ) {
    return _mutate(emit, (cur) => cur.copyWith(activeRestEndsAt: null));
  }

  Future<void> _onAdjustRestTimer(
    AdjustRestTimer event,
    Emitter<WorkoutSessionState> emit,
  ) {
    return _mutate(emit, (cur) {
      final ends = cur.activeRestEndsAt;
      if (ends == null) return cur; // no active timer to adjust
      final shifted = ends.add(event.delta);
      // If the user trimmed the timer past zero, cancel cleanly.
      if (shifted.isBefore(DateTime.now())) {
        return cur.copyWith(activeRestEndsAt: null);
      }
      return cur.copyWith(activeRestEndsAt: shifted);
    });
  }

  Future<void> _onCancelWorkout(
    CancelWorkout event,
    Emitter<WorkoutSessionState> emit,
  ) async {
    _persistDebounce?.cancel();
    await repository.clearActive();
    emit(const SessionCancelled());
    emit(const SessionIdle());
  }

  Future<void> _onFinishWorkout(
    FinishWorkout event,
    Emitter<WorkoutSessionState> emit,
  ) async {
    final cur = _current;
    if (cur == null) {
      emit(const SessionIdle());
      return;
    }
    emit(const SessionFinishing());
    final finished = cur.copyWith(
      status: SessionStatus.finished,
      finishedAt: DateTime.now(),
      activeRestEndsAt: null,
      activeExerciseId: null,
    );
    _persistDebounce?.cancel();
    await repository.archiveFinished(finished);
    await repository.clearActive();
    emit(const SessionFinished());
    emit(const SessionIdle());
  }

  // ----- Helpers -----

  WorkoutSession _mutateExercise(
    WorkoutSession session,
    String exerciseId,
    SessionExercise Function(SessionExercise) fn,
  ) {
    final list = session.exercises
        .map((ex) => ex.exerciseId == exerciseId ? fn(ex) : ex)
        .toList();
    return session.copyWith(exercises: list);
  }

  @override
  Future<void> close() {
    _persistDebounce?.cancel();
    return super.close();
  }
}
