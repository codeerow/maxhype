import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';
import 'package:collection/collection.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/battery_optimization.dart';
import '../../../core/rest_timer_notifications.dart';
import '../../../core/session_audio.dart';
import 'rest_bell_coordinator.dart';
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
    RestBell? bell,
    RestNotificationScheduler? scheduler,
  })  : _scheduler = scheduler ?? RestTimerNotifications.instance,
        super(const SessionIdle()) {
    _restBell = RestBellCoordinator(
      bell: bell,
      scheduler: _scheduler,
      onDeadlineElapsed: () => add(const CancelRestTimer()),
    );
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
    on<PrCacheLoaded>(_onPrCacheLoaded);
  }

  final WorkoutSessionRepository repository;
  final PersonalRecordRepository prRepository;
  final RestNotificationScheduler _scheduler;
  late final RestBellCoordinator _restBell;

  Timer? _persistDebounce;
  final _idRng = Random();

  /// Historical baseline per exerciseId, loaded once by `_loadPrsFor` from
  /// `prRepository.bestFor`. Survives any session mutation — only ever
  /// replaced when the cache loads or `_loadPrsFor` runs again.
  ///
  /// A `null` *value* (present key) means "history was loaded and there
  /// is no prior PR". A missing key means the cache hasn't loaded yet.
  final Map<String, PersonalRecord?> _historical = {};

  /// Last head we emitted to UI / signals per exerciseId. The
  /// recompute pass diffs against this to decide whether to fire
  /// `PrAchievedSignal` / `PrRevokedSignal` and to spot a no-op early.
  ///
  /// Stores the source set id (or `_baselineSetId` for historical) so
  /// we can tell PR-from-live-set from PR-from-history.
  final Map<String, _Head?> _lastHead = {};

  /// Sentinel for "head is the historical baseline" (no live set).
  static const String _baselineSetId = '__baseline__';

  /// True when the current head for [exerciseId] was produced by a
  /// live set in this session (not by the historical baseline).
  bool hasFreshPr(String exerciseId) {
    final head = _lastHead[exerciseId];
    return head != null && head.setId != _baselineSetId;
  }

  /// Side-channel for PR life-cycle events. Subscribers (logging
  /// screen) listen and animate without state-flag plumbing.
  final StreamController<PrSignal> _prSignals =
      StreamController<PrSignal>.broadcast();

  Stream<PrSignal> get prSignals => _prSignals.stream;

  /// Current best for [exerciseId]: max of historical baseline and every
  /// logged effective set on the exercise (warmups excluded). Null when
  /// neither source has a value.
  PersonalRecord? prFor(String exerciseId) {
    final head = _lastHead[exerciseId];
    return head?.record;
  }

  /// "Previous Best" for the PR header — the runner-up so users see what
  /// the new head just beat. Returns the second-highest record among
  /// `[historical, ...loggedSets]`. Null when there is no runner-up
  /// (e.g. the head IS the only known record).
  PersonalRecord? previousBestFor(String exerciseId) {
    final session = _current;
    if (session == null) return null;
    final ex = session.exercises
        .firstWhereOrNull((e) => e.exerciseId == exerciseId);
    if (ex == null) return null;
    final ranked = _rankedRecordsFor(exerciseId, ex);
    if (ranked.length < 2) return null;
    return ranked[1].record;
  }

  /// Build the full ranked list of candidate records for [exerciseId]:
  /// historical baseline (if any) plus one entry per logged effective
  /// set, sorted by `PersonalRecord` ordering (heaviest weight, reps
  /// tie-break). Used to compute head and runner-up in a single pass.
  List<_RankedRecord> _rankedRecordsFor(String exerciseId, SessionExercise ex) {
    final out = <_RankedRecord>[];
    final base = _historical[exerciseId];
    if (base != null) {
      out.add(_RankedRecord(setId: _baselineSetId, record: base));
    }
    for (final s in ex.sets) {
      if (!s.isLogged || s.weight == null || s.reps == null) continue;
      out.add(_RankedRecord(
        setId: s.id,
        record: PersonalRecord(
          exerciseId: exerciseId,
          weight: s.weight!,
          reps: s.reps!,
          achievedAt: s.loggedAt!,
        ),
      ));
    }
    out.sort(_compareRecordsDesc);
    return out;
  }

  /// Recompute the PR head for [exerciseId] from the current session,
  /// diff against the last emitted head, and broadcast signals on
  /// change. Idempotent — a no-op when nothing moved.
  void _recomputeFor(String exerciseId) {
    final session = _current;
    if (session == null) return;
    final ex = session.exercises
        .firstWhereOrNull((e) => e.exerciseId == exerciseId);
    if (ex == null) {
      // Exercise gone (DeleteExercise / ReplaceExercise) — drop head.
      // No revoke signal: the row itself is gone, nothing to un-paint.
      _lastHead.remove(exerciseId);
      return;
    }
    final ranked = _rankedRecordsFor(exerciseId, ex);
    final newHead = ranked.isEmpty ? null : _Head.from(ranked.first);
    final oldHead = _lastHead[exerciseId];

    if (_headsEqual(oldHead, newHead)) return;
    _lastHead[exerciseId] = newHead;

    // Revoke first when the old head was a live set and either it's
    // gone or has been displaced. The set may still exist (just no
    // longer head) — UI still needs to drop its PR pill.
    //
    // Same workout-level gate as the achieve branch below: if there is
    // no historical baseline, the live PR pill never appeared in the
    // first place, so there is nothing to revoke. Suppressing the
    // signal keeps subscriber bookkeeping consistent with what the user
    // actually saw on screen during the first workout.
    if (oldHead != null &&
        oldHead.setId != _baselineSetId &&
        _historical[exerciseId] != null) {
      _prSignals.add(PrRevokedSignal(
        exerciseId: exerciseId,
        setId: oldHead.setId,
      ));
    }
    // Achieve only when the new head is *strictly better* than the old:
    //   - new head must exist and be a live set,
    //   - the old head must have existed (silent-baseline rule when oldHead == null),
    //   - and oldHead.record must actually be beaten by newHead.record.
    // Plus the workout-level baseline rule: PR animations never fire on
    // an exercise's first-ever workout. They start firing only once a
    // prior finished workout has produced a historical baseline. Inside
    // that first workout we still tracked the live head (so the PR
    // header can show the current best), we just suppress the signal.
    // This guards against celebrating a regression (e.g. user deletes
    // their 110-set; head falls back to a still-live 100-set — that's
    // a revoke, not an achievement).
    if (newHead != null &&
        newHead.setId != _baselineSetId &&
        oldHead != null &&
        _historical[exerciseId] != null &&
        oldHead.record.isBeatenBy(
          weight: newHead.record.weight,
          reps: newHead.record.reps,
        )) {
      _prSignals.add(PrAchievedSignal(
        exerciseId: exerciseId,
        setId: newHead.setId,
        weight: newHead.record.weight,
        reps: newHead.record.reps,
      ));
    }
  }

  static int _compareRecordsDesc(_RankedRecord a, _RankedRecord b) {
    if (a.record.weight != b.record.weight) {
      return b.record.weight.compareTo(a.record.weight);
    }
    if (a.record.reps != b.record.reps) {
      return b.record.reps.compareTo(a.record.reps);
    }
    // Final tie-break: newer achievement wins, so chronologically the
    // "latest" equal-best set is treated as head.
    return b.record.achievedAt.compareTo(a.record.achievedAt);
  }

  static bool _headsEqual(_Head? a, _Head? b) {
    if (identical(a, b)) return true;
    if (a == null || b == null) return false;
    return a.setId == b.setId &&
        a.record.weight == b.record.weight &&
        a.record.reps == b.record.reps;
  }

  String _newId([String prefix = 'id']) {
    final t = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final r = _idRng.nextInt(1 << 32).toRadixString(36);
    return '${prefix}_${t}_$r';
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _restBell.onLifecycleChange(
      foreground: state == AppLifecycleState.resumed,
      currentDeadline: _current?.activeRestEndsAt,
    );
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
    _restBell.onDeadlineChange(cur.activeRestEndsAt, next.activeRestEndsAt);
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
    unawaited(_scheduler.requestPermission());
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
            restored.activeRestEndsAt!.isBefore(clock.now()))
        ? restored.copyWith(activeRestEndsAt: null)
        : restored;
    emit(SessionActive(cleaned));
    unawaited(_loadPrsFor(cleaned));
  }

  /// Load historical baseline-PR per exercise from `prRepository` into
  /// [_historical]. Looked up in parallel — they're independent. After
  /// every exercise resolves we recompute its head so the UI rebuilds
  /// with the freshly-loaded baseline.
  Future<void> _loadPrsFor(WorkoutSession session) async {
    final futures = session.exercises.map((ex) async {
      final pr = await prRepository.bestFor(ex.exerciseId);
      _historical[ex.exerciseId] = pr;
      _recomputeFor(ex.exerciseId);
    });
    await Future.wait(futures);
    // Tickle BlocConsumer subscribers so PrHeader rebuilds and picks
    // up the freshly-loaded baselines — otherwise the header stays
    // empty until the next state-changing event.
    if (_current != null) add(const PrCacheLoaded());
  }

  void _onPrCacheLoaded(
    PrCacheLoaded event,
    Emitter<WorkoutSessionState> emit,
  ) {
    final cur = _current;
    if (cur != null) emit(SessionActive(cur));
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

    // Warmups never participate in PR computation — _recomputeFor only
    // reads effective sets — so we can skip the call when isWarmup.
    if (!event.isWarmup) {
      // Head was null before this set went in: the new head exists but
      // there's no prior to compare against, so _recomputeFor stays
      // silent (correct — silent-baseline rule). Re-emit SessionActive
      // anyway so PrHeader (gated on `currentPr != null`) appears.
      final hadHeadBefore = _lastHead[event.exerciseId] != null;
      _recomputeFor(event.exerciseId);
      if (!hadHeadBefore && _lastHead[event.exerciseId] != null) {
        add(const PrCacheLoaded());
      }
    }
  }

  Future<void> _onUpdateSetDraft(
    UpdateSetDraft event,
    Emitter<WorkoutSessionState> emit,
  ) async {
    final cur = _current;
    final beforeSet = cur?.exercises
        .firstWhereOrNull((e) => e.exerciseId == event.exerciseId)
        ?.sets
        .firstWhereOrNull((s) => s.id == event.setId);
    final wasLogged = beforeSet?.isLogged ?? false;

    await _mutate(emit, (cur) {
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

    // Editing an already-logged effective set changes its contribution
    // to the PR ranking — recompute. Drafts on unlogged sets or on the
    // warmup row never enter the ranking, so we skip the work there.
    if (!event.isWarmup && wasLogged) {
      _recomputeFor(event.exerciseId);
    }
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
    // DeleteSet never marks the exercise complete on its own. When the
    // user swipes off the last unlogged effective set, every remaining
    // set is already logged — isAwaitingDoneConfirmation flips true and
    // the bottom button shows "Done", so the user can finish manually.
    // Auto-completing here would also pop the logging screen out from
    // under them via the completed-flag listener, which is exactly the
    // surprise we want to avoid.
    final next = await _mutate(emit, (cur) {
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
    if (next != null && !event.isWarmup) {
      _recomputeFor(event.exerciseId);
    }
  }

  Future<void> _onDeleteExercise(
    DeleteExercise event,
    Emitter<WorkoutSessionState> emit,
  ) async {
    await _mutate(emit, (cur) {
      return cur.copyWith(
        exercises: cur.exercises
            .where((e) => e.exerciseId != event.exerciseId)
            .toList(),
        activeExerciseId: cur.activeExerciseId == event.exerciseId
            ? null
            : cur.activeExerciseId,
      );
    });
    // The exercise card is gone — drop the head & historical baseline
    // so a future re-add (via Replace, say) doesn't resurrect stale state.
    _historical.remove(event.exerciseId);
    _lastHead.remove(event.exerciseId);
  }

  Future<void> _onReplaceExercise(
    ReplaceExercise event,
    Emitter<WorkoutSessionState> emit,
  ) async {
    await _mutate(emit, (cur) {
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
    // The old exerciseId is gone — drop its state. The new id starts
    // fresh; its first logged set will become the silent baseline.
    _historical.remove(event.oldExerciseId);
    _lastHead.remove(event.oldExerciseId);
    // Load historical baseline for the new id (may be non-null if the
    // user did this exercise before in a prior session) and recompute.
    final newPr = await prRepository.bestFor(event.newExercise.id);
    _historical[event.newExercise.id] = newPr;
    _recomputeFor(event.newExercise.id);
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
        activeRestEndsAt: clock.now().add(dur),
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
      if (shifted.isBefore(clock.now())) {
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
    await _restBell.cancelNotification();
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

    // Guard against finishing a workout with zero logged sets across all
    // exercises. Archiving such a session would pollute the history file
    // (and therefore the PR baseline scan) with an empty completion.
    // Bounce back to SessionActive so the screen stays put while the UI
    // shows a validation toast.
    final hasAnyLoggedSet =
        cur.exercises.any((ex) => ex.hasAnyLoggedSet);
    if (!hasAnyLoggedSet) {
      emit(const SessionFinishBlockedEmpty());
      emit(SessionActive(cur));
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
    await _restBell.cancelNotification();
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
    _restBell.dispose();
    _prSignals.close();
    return super.close();
  }
}

/// Snapshot of "the current head" used to diff between recomputes and
/// decide whether a signal should fire. [setId] is `_baselineSetId`
/// when the head is the historical baseline.
class _Head {
  final String setId;
  final PersonalRecord record;

  const _Head({required this.setId, required this.record});

  factory _Head.from(_RankedRecord r) =>
      _Head(setId: r.setId, record: r.record);
}

/// One candidate record in the per-exercise ranking. The setId is the
/// live SessionSet id, or `WorkoutSessionBloc._baselineSetId` when it
/// stands in for the historical baseline.
class _RankedRecord {
  final String setId;
  final PersonalRecord record;

  const _RankedRecord({required this.setId, required this.record});
}
