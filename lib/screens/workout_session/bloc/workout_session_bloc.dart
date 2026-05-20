import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/battery_optimization.dart';
import '../../../core/rest_timer_notifications.dart';
import '../../../core/session_audio.dart';
import '../../../models/session/personal_record.dart';
import '../../../models/session/session_exercise.dart';
import '../../../models/session/session_set.dart';
import '../../../models/session/workout_session.dart';
import '../../../repositories/personal_record_repository.dart';
import '../../../repositories/workout_session_repository.dart';
import 'pr_signal.dart';
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
    extends Bloc<WorkoutSessionEvent, WorkoutSessionState>
    with WidgetsBindingObserver {
  WorkoutSessionBloc({
    required this.repository,
    required this.prRepository,
  }) : super(const SessionIdle()) {
    WidgetsBinding.instance.addObserver(this);
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
  final PersonalRecordRepository prRepository;

  Timer? _persistDebounce;
  Timer? _restBellTimer;
  bool _appInForeground = true;
  final _idRng = Random();

  /// Per-exercise PR snapshot loaded at session start. Updated in place
  /// when a logged set beats the previous best.
  final Map<String, PersonalRecord?> _prByExerciseId = {};

  /// Snapshot of the previous best for each exercise that was beaten
  /// during the current session — keeps the value around so the UI can
  /// render "Previous Best: ..." next to the just-set "New Best".
  final Map<String, PersonalRecord> _prevBestByExerciseId = {};

  /// Exercise ids for which a PR was set in the current session.
  /// Drives the persistent "PERSONAL RECORD" pill on the session card.
  final Set<String> _prAchievedThisSession = {};

  /// True when the user has set a PR for [exerciseId] in this session.
  bool hasFreshPr(String exerciseId) =>
      _prAchievedThisSession.contains(exerciseId);

  /// Side-channel for one-shot PR celebrations. Subscribers (logging
  /// screen) listen and animate without state-flag plumbing.
  final StreamController<PrAchievedSignal> _prSignals =
      StreamController<PrAchievedSignal>.broadcast();

  Stream<PrAchievedSignal> get prSignals => _prSignals.stream;

  /// Current best for [exerciseId]. Null when the cache hasn't loaded
  /// yet or the exercise has no history.
  PersonalRecord? prFor(String exerciseId) => _prByExerciseId[exerciseId];

  /// Best at the moment we started the current session (or before the
  /// most recent PR overwrite this session). Used to render "Previous
  /// Best" under the "New Best" line.
  PersonalRecord? previousBestFor(String exerciseId) =>
      _prevBestByExerciseId[exerciseId];

  String _newId([String prefix = 'id']) {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = _idRng.nextInt(1 << 32).toRadixString(36);
    return '${prefix}_${t}_$r';
  }

  /// Rest deadline ↔ side-effects.
  ///
  /// Exactly one bell rings per deadline. The architecture enforces this
  /// by making sure only one source is armed at any time:
  ///
  ///   * **Foreground**: a Dart Timer fires the in-app bell via
  ///     [SessionAudio]. The OS notification is NOT scheduled — it could
  ///     race with the in-app timer.
  ///   * **Background**: the OS notification is the only source. The
  ///     Dart Timer is cancelled the moment we leave foreground.
  ///
  /// Lifecycle transitions ([didChangeAppLifecycleState]) swap the
  /// source: leaving foreground → schedule notification, cancel timer;
  /// returning to foreground → cancel notification, re-arm timer.
  ///
  /// Deadline already elapsed while we were backgrounded: the OS
  /// notification has already played, and the re-arm path detects the
  /// negative remaining and refuses to fire a second bell.
  void _syncRestNotification(WorkoutSession before, WorkoutSession after) {
    if (before.activeRestEndsAt == after.activeRestEndsAt) return;
    final ends = after.activeRestEndsAt;
    _restBellTimer?.cancel();
    _restBellTimer = null;
    if (ends == null) {
      RestTimerNotifications.instance.cancel();
      return;
    }
    if (_appInForeground) {
      // Foreground owns the bell — no OS notification scheduled.
      RestTimerNotifications.instance.cancel();
      _armForegroundBell(ends);
    } else {
      // Background owns the bell — OS notification handles it.
      RestTimerNotifications.instance.schedule(ends);
    }
  }

  void _armForegroundBell(DateTime ends) {
    _restBellTimer?.cancel();
    final remaining = ends.difference(DateTime.now());
    if (remaining.isNegative) return;
    _restBellTimer = Timer(remaining, () {
      _restBellTimer = null;
      SessionAudio.instance.playRestComplete();
      // Bloc owns the deadline lifecycle: clear `activeRestEndsAt`
      // ourselves so the rest card stops rendering. Critically, we do
      // NOT rely on the widget's `onCompleted` to do this — the widget
      // ticks on its own 1s clock and can race ahead of this Timer,
      // dispatching CancelRestTimer (which would cancel _restBellTimer)
      // before we ever fire. That race is exactly the
      // "silent-on-logging-screen" bug, since the logging screen is the
      // only place RestTimerCard is mounted.
      add(const CancelRestTimer());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _appInForeground) return;
    _appInForeground = foreground;
    final ends = _current?.activeRestEndsAt;
    if (ends == null) return;
    if (foreground) {
      // Returning to foreground: cancel the OS notification, re-arm the
      // Dart timer. If the deadline elapsed while we were backgrounded,
      // _armForegroundBell sees a negative remaining and does nothing —
      // the OS notification already rang.
      RestTimerNotifications.instance.cancel();
      _armForegroundBell(ends);
    } else {
      // Leaving foreground: hand the bell to the OS notification.
      _restBellTimer?.cancel();
      _restBellTimer = null;
      RestTimerNotifications.instance.schedule(ends);
    }
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
    _syncRestNotification(cur, next);
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
    unawaited(_loadPrsFor(session));
    // Best-effort: ask for notification permission when the user starts
    // their first workout. If they say no, the foreground rest-timer card
    // still works, just no background bell.
    unawaited(RestTimerNotifications.instance.requestPermission());
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
    unawaited(_loadPrsFor(cleaned));
  }

  /// Load best-PR per exercise from history into [_prByExerciseId]. The
  /// look-up is async per exercise, so we run them in parallel and let the
  /// UI re-render through `prFor` reads as data lands.
  Future<void> _loadPrsFor(WorkoutSession session) async {
    final futures = session.exercises.map((ex) async {
      final pr = await prRepository.bestFor(ex.exerciseId);
      _prByExerciseId[ex.exerciseId] = pr;
    });
    await Future.wait(futures);
    // Nothing to emit — `prFor()` is read directly by UI listeners.
  }

  Future<void> _onLogSet(LogSet event, Emitter<WorkoutSessionState> emit) async {
    await _mutate(emit, (cur) {
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

    // PR check happens after the state mutation: warmups don't count
    // (they're light-weight prep), so only effective sets are eligible.
    if (!event.isWarmup) {
      _maybeEmitPr(event);
    }
  }

  /// Compare the just-logged set against the cached best for its
  /// exercise. If it beats the previous PR (or there's no previous PR),
  /// update the cache and broadcast a `PrAchievedSignal` so the logging
  /// screen can celebrate.
  void _maybeEmitPr(LogSet event) {
    final existing = _prByExerciseId[event.exerciseId];
    final beats = existing == null ||
        existing.isBeatenBy(weight: event.weight, reps: event.reps);
    if (!beats) return;
    // Stash the prior best before overwriting so the UI can render
    // "Previous Best" alongside the new "New Best". Only set on the
    // first PR per exercise per session — chained PRs keep the very
    // first "previous" as their baseline so the user always sees what
    // they came in with.
    if (existing != null) {
      _prevBestByExerciseId.putIfAbsent(event.exerciseId, () => existing);
    }
    final fresh = PersonalRecord(
      exerciseId: event.exerciseId,
      weight: event.weight,
      reps: event.reps,
      achievedAt: DateTime.now(),
    );
    _prByExerciseId[event.exerciseId] = fresh;
    _prAchievedThisSession.add(event.exerciseId);
    _prSignals.add(
      PrAchievedSignal(
        exerciseId: event.exerciseId,
        setId: event.setId,
        weight: event.weight,
        reps: event.reps,
      ),
    );
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
  ) async {
    var autoComplete = false;
    final next = await _mutate(emit, (cur) {
      return _mutateExercise(cur, event.exerciseId, (ex) {
        if (event.isWarmup) {
          return ex.copyWith(warmupSet: null);
        }
        final newSets = ex.sets.where((s) => s.id != event.setId).toList();
        final warmupPending = ex.warmupSet != null && !ex.warmupSet!.isLogged;
        // If the user deleted the last *unlogged* effective set while at least
        // one set is already logged, treat the exercise as done — otherwise
        // there's no way to finish it (Log Set button has nothing to target).
        final shouldComplete = !ex.completed &&
            !warmupPending &&
            newSets.isNotEmpty &&
            newSets.every((s) => s.isLogged);
        if (shouldComplete) autoComplete = true;
        return ex.copyWith(
          sets: newSets,
          targetSets: max(0, ex.targetSets - 1),
          completed: shouldComplete ? true : null,
        );
      });
    });
    if (!autoComplete || next == null) return;
    await _mutate(emit, (cur) {
      return cur.copyWith(
        activeExerciseId: cur.activeExerciseId == event.exerciseId
            ? null
            : cur.activeExerciseId,
        activeRestEndsAt: null,
      );
    }, flush: true);
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
    await RestTimerNotifications.instance.cancel();
    await BatteryOptimization.instance.stopForegroundService();
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
    await RestTimerNotifications.instance.cancel();
    await BatteryOptimization.instance.stopForegroundService();
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
    WidgetsBinding.instance.removeObserver(this);
    _persistDebounce?.cancel();
    _restBellTimer?.cancel();
    _prSignals.close();
    return super.close();
  }
}
