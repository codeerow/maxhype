import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/haptic_manager.dart';
import '../../core/service_locator.dart';
import '../../models/exercise.dart';
import '../../models/session/personal_record.dart';
import '../../models/session/session_exercise.dart';
import '../../models/session/session_set.dart';
import '../../models/session/workout_session.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/workout_session_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/tap_scale.dart';
import 'bloc/pr_signal.dart';
import 'bloc/workout_session_bloc.dart';
import 'bloc/workout_session_event.dart';
import 'bloc/workout_session_state.dart';
import '../../models/workout.dart';
import '../workout_detail/bloc/workout_detail_bloc.dart';
import '../workout_detail/bloc/workout_detail_state.dart';
import '../workout_detail/bloc/workout_preview_bloc.dart';
import '../workout_detail/widgets/exercise_navigation.dart';
import 'live_logging_mode.dart';
import 'logging_mode.dart';
import 'preview_logging_mode.dart';
import 'widgets/action_chip_row.dart';
import 'widgets/add_set_button.dart';
import 'widgets/effective_set_row.dart';
import 'widgets/log_set_button.dart';
import 'widgets/notes_card.dart';
import 'widgets/pr_celebration.dart';
import 'widgets/pr_header.dart';
import 'widgets/pr_new_label.dart';
import 'widgets/rest_timer_card.dart';
import 'widgets/swipe_to_delete.dart';

/// (weight, reps) pre-fill values shown in pill placeholders before the user
/// types anything. Resolved via session → history → catalog plan.
typedef _Prefill = ({double? weight, int? reps});

// Visual height of the rest-timer pill (single-row card with 10px
// vertical padding + ~30px content). Used as bottom padding for the
// ListView so the last rows can scroll under the floating timer.
const double _kRestCardReserve = 60;

/// Logging screen for a single exercise. Operates in one of two modes:
///
///   - `ExerciseLoggingScreen.live(...)` — backed by `WorkoutSessionBloc`,
///     used during an active session. Logs sets, drives PR celebrations,
///     bottom button toggles Log Set / Done.
///   - `ExerciseLoggingScreen.preview(...)` — backed by
///     [WorkoutPreviewBloc], used from the workout-detail screen before
///     the user has tapped Start. Lets the user pre-fill weight/reps,
///     add/delete rows, and replace the exercise; bottom button reads
///     "Start Workout" and creates the session with the drafts merged
///     in (brief Phase 3 Part 3 §6).
class ExerciseLoggingScreen extends StatelessWidget {
  final String exerciseId;
  final WorkoutSessionBloc bloc;
  final bool previewMode;
  final Workout? previewWorkout;
  final WorkoutPreviewBloc? previewBloc;
  final WorkoutDetailBloc? detailBloc;

  const ExerciseLoggingScreen._({
    required this.exerciseId,
    required this.bloc,
    this.previewMode = false,
    this.previewWorkout,
    this.previewBloc,
    this.detailBloc,
  });

  factory ExerciseLoggingScreen.live({
    required String exerciseId,
    required WorkoutSessionBloc bloc,
  }) =>
      ExerciseLoggingScreen._(exerciseId: exerciseId, bloc: bloc);

  factory ExerciseLoggingScreen.preview({
    required String exerciseId,
    required Workout workout,
    required WorkoutPreviewBloc previewBloc,
    required WorkoutSessionBloc sessionBloc,
    required WorkoutDetailBloc detailBloc,
  }) =>
      ExerciseLoggingScreen._(
        exerciseId: exerciseId,
        bloc: sessionBloc,
        previewMode: true,
        previewWorkout: workout,
        previewBloc: previewBloc,
        detailBloc: detailBloc,
      );

  @override
  Widget build(BuildContext context) {
    Widget view = _LoggingView(
      exerciseId: exerciseId,
      previewMode: previewMode,
      previewWorkout: previewWorkout,
    );
    // Re-expose the workout-detail bloc on the new route so the
    // three-dot Replace flow (which dispatches detail_event.ReplaceExercise)
    // can find it via context.read. Without this, the modal sheet's
    // context — pushed even deeper than the preview route — would
    // hit ProviderNotFoundException.
    if (detailBloc != null) {
      view = BlocProvider<WorkoutDetailBloc>.value(
        value: detailBloc!,
        child: view,
      );
    }
    return BlocProvider<WorkoutSessionBloc>.value(
      value: bloc,
      child: previewBloc == null
          ? view
          : BlocProvider<WorkoutPreviewBloc>.value(
              value: previewBloc!,
              child: view,
            ),
    );
  }
}

class _LoggingView extends StatefulWidget {
  final String exerciseId;
  final bool previewMode;
  final Workout? previewWorkout;

  const _LoggingView({
    required this.exerciseId,
    this.previewMode = false,
    this.previewWorkout,
  });

  @override
  State<_LoggingView> createState() => _LoggingViewState();
}

class _LoggingViewState extends State<_LoggingView>
    with TickerProviderStateMixin {
  /// The slotId the screen is currently rendering. Starts at the
  /// widget's exerciseId (in live mode the caller passes a slotId via
  /// this parameter — same name, slot semantics; in preview mode the
  /// slot identity is the catalog exerciseId because preview has one
  /// slot per template exercise). Survives Replace because the slot
  /// keeps its id — only the underlying catalog exerciseId changes.
  late String _currentSlotId = widget.exerciseId;
  late Future<SessionSet?> _historyFuture;

  /// Stable FocusNodes for WEIGHT / REPS fields keyed by `setId`
  /// (or `'warmup'`). Owned here so we can chain focus to the next
  /// row's WEIGHT after Log Set. Auto-scroll on focus is handled by
  /// Flutter itself via [TextField.scrollPadding] inside the row, so
  /// no GlobalKeys / ScrollController plumbing is needed at this
  /// level.
  final Map<String, FocusNode> _weightFocusNodes = {};
  final Map<String, FocusNode> _repsFocusNodes = {};

  FocusNode _weightFocusFor(String key) =>
      _weightFocusNodes.putIfAbsent(key, FocusNode.new);
  FocusNode _repsFocusFor(String key) =>
      _repsFocusNodes.putIfAbsent(key, FocusNode.new);

  /// Set ids that have been flagged as PR during this logging session —
  /// drives the orange pill colouring on their row.
  final Set<String> _prSetIds = {};

  /// One-shot celebration controllers keyed by setId. Created on first
  /// PR for the set, runs once, stays parked at value=1.0 afterwards
  /// (the celebration painter renders nothing once `t >= 1`).
  final Map<String, AnimationController> _celebrationCtrls = {};

  AnimationController celebrationFor(String setId) =>
      _celebrationCtrls.putIfAbsent(
        setId,
        () => AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 900),
        ),
      );

  StreamSubscription<PrSignal>? _prSub;

  @override
  void initState() {
    super.initState();
    _historyFuture =
        getIt<WorkoutSessionRepository>().lastLogFor(_currentSlotId);

    final bloc = context.read<WorkoutSessionBloc>();
    _prSub = bloc.prSignals.listen(_onPrSignal);
  }

  /// Switch the screen onto a newly replaced exercise. Re-fetches the
  /// history future so the prefill pills reflect *this* exercise's
  /// last logged set, and forces a rebuild so the rest of the body
  /// reads from the freshly-resolved [_currentSlotId].
  void _switchExerciseId(String newId) {
    if (!mounted) return;
    setState(() {
      _currentSlotId = newId;
      _historyFuture =
          getIt<WorkoutSessionRepository>().lastLogFor(newId);
    });
  }

  void _onPrSignal(PrSignal signal) {
    switch (signal) {
      case PrAchievedSignal():
        _onPrAchieved(signal);
      case PrRevokedSignal():
        _onPrRevoked(signal);
    }
  }

  /// Catalog exerciseId of the slot currently rendered, or null when
  /// the slot is no longer in the session (just popped, mid-replace).
  /// PR signals key by catalog exerciseId — slot identity is local.
  String? _currentCatalogExerciseId(BuildContext context) {
    final state = context.read<WorkoutSessionBloc>().state;
    if (state is! SessionActive) return null;
    return state.session.exercises
        .firstWhereOrNull((e) => e.slotId == _currentSlotId)
        ?.exerciseId;
  }

  void _onPrAchieved(PrAchievedSignal signal) {
    if (!mounted) return;
    if (signal.exerciseId != _currentCatalogExerciseId(context)) return;
    setState(() => _prSetIds.add(signal.setId));
    celebrationFor(signal.setId).forward(from: 0);
    getIt<HapticManager>().strongest();
    PrNewLabel.show(context);
  }

  void _onPrRevoked(PrRevokedSignal signal) {
    if (!mounted) return;
    if (signal.exerciseId != _currentCatalogExerciseId(context)) return;
    if (!_prSetIds.contains(signal.setId)) return;
    setState(() => _prSetIds.remove(signal.setId));
    // Park the celebration controller back to 0 so any future re-PR on a
    // different set doesn't share an already-completed controller.
    _celebrationCtrls[signal.setId]?.value = 0;
  }

  @override
  void dispose() {
    _prSub?.cancel();
    for (final n in _repsFocusNodes.values) {
      n.dispose();
    }
    for (final n in _weightFocusNodes.values) {
      n.dispose();
    }
    for (final c in _celebrationCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool _completedFor(WorkoutSessionState s) {
    if (s is! SessionActive) return false;
    final ex = s.session.exercises.firstWhereOrNull(
      (e) => e.slotId == _currentSlotId,
    );
    return ex?.completed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previewMode) {
      return _buildPreview(context);
    }
    return _buildLive(context);
  }

  Widget _buildLive(BuildContext context) {
    return BlocConsumer<WorkoutSessionBloc, WorkoutSessionState>(
      // Listen for the exercise's `completed` flag flipping false → true.
      // That's the single source of truth: when the exercise is done, we
      // pop the logging screen.
      listenWhen: (prev, next) =>
          !_completedFor(prev) && _completedFor(next),
      listener: (context, state) {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      },
      builder: (context, state) {
        if (state is! SessionActive) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: SizedBox.shrink(),
          );
        }
        final ex = state.session.exercises.firstWhereOrNull(
          (e) => e.slotId == _currentSlotId,
        );
        if (ex == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          });
          return const Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: SizedBox.shrink(),
          );
        }
        final bloc = context.read<WorkoutSessionBloc>();
        return FutureBuilder<SessionSet?>(
          future: _historyFuture,
          builder: (context, snapshot) {
            final mode = LiveLoggingMode(
              bloc: bloc,
              exercise: ex,
              focusWeight: (id) => _weightFocusFor(id).requestFocus(),
            );
            return _LoggingScaffold(
              exercise: ex,
              session: state.session,
              historyLastLog: snapshot.data,
              weightFocusFor: _weightFocusFor,
              repsFocusFor: _repsFocusFor,
              celebrationFor: celebrationFor,
              prSetIds: _prSetIds,
              currentPr: bloc.hasFreshPr(ex.exerciseId)
                  ? bloc.prFor(ex.exerciseId)
                  : null,
              previousBest: bloc.previousBestFor(ex.exerciseId),
              isFreshPr: _prSetIds.isNotEmpty,
              mode: mode,
              onExerciseReplaced: _switchExerciseId,
            );
          },
        );
      },
    );
  }

  Widget _buildPreview(BuildContext context) {
    final sessionBloc = context.read<WorkoutSessionBloc>();
    final previewBloc = context.read<WorkoutPreviewBloc>();
    // Read completion flag off the workout-detail bloc so the
    // preview's Start Workout CTA stays locked when the user drills
    // into an exercise of a workout already finished this week.
    // Without this, the lock added by fix #7 (detail-screen Start
    // pill) could be bypassed by tapping any exercise card first.
    final detailState = context.read<WorkoutDetailBloc>().state;
    final isCompletedThisWeek = detailState is WorkoutDetailSuccess &&
        detailState.completionThisWeek != null;
    // Preview screen pops itself the moment the user picks Replace
    // (mirrors workout-detail's flow), so we don't need to subscribe
    // to WorkoutDetailBloc for live template updates — the workout
    // snapshot captured at open time is enough for the screen's
    // lifetime.
    final workout = widget.previewWorkout!;

    return BlocBuilder<WorkoutPreviewBloc, WorkoutPreviewState>(
      builder: (context, _) {
        // Seed the preview draft for the current exercise. Idempotent —
        // only sows rows when nothing yet exists for this exerciseId.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final ex = workout.exercises.firstWhere(
            (e) => e.id == _currentSlotId,
            orElse: () => workout.exercises.first,
          );
          previewBloc.seedEffectiveSets(_currentSlotId, ex.sets);
        });

        final mode = PreviewLoggingMode(
          workout: workout,
          exerciseId: _currentSlotId,
          previewBloc: previewBloc,
          sessionBloc: sessionBloc,
          isCompletedThisWeek: isCompletedThisWeek,
        );
        final ex = mode.exerciseSnapshot;
        return FutureBuilder<SessionSet?>(
          future: _historyFuture,
          builder: (context, snapshot) {
            return _LoggingScaffold(
              exercise: ex,
              session: null,
              historyLastLog: snapshot.data,
              weightFocusFor: _weightFocusFor,
              repsFocusFor: _repsFocusFor,
              celebrationFor: celebrationFor,
              prSetIds: _prSetIds,
              currentPr: null,
              previousBest: null,
              isFreshPr: false,
              mode: mode,
              onExerciseReplaced: _switchExerciseId,
            );
          },
        );
      },
    );
  }
}

class _LoggingScaffold extends StatefulWidget {
  final SessionExercise exercise;
  final WorkoutSession? session;
  final SessionSet? historyLastLog;
  final FocusNode Function(String key) weightFocusFor;
  final FocusNode Function(String key) repsFocusFor;
  final AnimationController Function(String setId) celebrationFor;
  final Set<String> prSetIds;
  final PersonalRecord? currentPr;
  final PersonalRecord? previousBest;
  final bool isFreshPr;
  final LoggingMode mode;
  final ValueChanged<String> onExerciseReplaced;

  const _LoggingScaffold({
    required this.exercise,
    required this.session,
    required this.historyLastLog,
    required this.weightFocusFor,
    required this.repsFocusFor,
    required this.celebrationFor,
    required this.prSetIds,
    required this.currentPr,
    required this.previousBest,
    required this.isFreshPr,
    required this.mode,
    required this.onExerciseReplaced,
  });

  @override
  State<_LoggingScaffold> createState() => _LoggingScaffoldState();
}

class _LoggingScaffoldState extends State<_LoggingScaffold> {
  // Field shorthands so the existing helper methods (_buildSetRows,
  // _onLogSetTap, etc.) can keep using bare names instead of `widget.x`.
  SessionExercise get exercise => widget.exercise;
  WorkoutSession? get session => widget.session;
  SessionSet? get historyLastLog => widget.historyLastLog;
  FocusNode Function(String key) get weightFocusFor => widget.weightFocusFor;
  FocusNode Function(String key) get repsFocusFor => widget.repsFocusFor;
  AnimationController Function(String setId) get celebrationFor =>
      widget.celebrationFor;
  Set<String> get prSetIds => widget.prSetIds;
  PersonalRecord? get currentPr => widget.currentPr;
  PersonalRecord? get previousBest => widget.previousBest;
  bool get isFreshPr => widget.isFreshPr;

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final prefill = _resolvePrefill(exercise);
    final firstUnlogged = exercise.firstUnloggedSet;

    final s = session;
    final restActive = s != null &&
        s.activeRestEndsAt != null &&
        s.activeRestEndsAt!.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                ListView(
                  padding: EdgeInsets.fromLTRB(
                    0,
                    8,
                    0,
                    (restActive ? _kRestCardReserve : 0) + 16,
                  ),
                  children: [
                    if (currentPr != null && !mode.isPreview)
                      PrHeader(
                        pr: currentPr!,
                        previousBest: previousBest,
                        isFresh: isFreshPr,
                      ),
                    // ActionChipRow is shown in both modes so the
                    // preview screen mirrors the live layout. In preview
                    // the rest label is a static hint ("Rest 2:00") —
                    // no timer ticks until Start Workout flips the
                    // screen into live mode.
                    ActionChipRow(
                      restSeconds: mode.restSecondsHint,
                      onRestTap: () => AppToast.show(
                          context, 'Rest timer adjusts in card'),
                      onInstructionTap: () => AppToast.show(
                          context, 'Instructions — coming in Part 2'),
                      onAnalyticsTap: () => AppToast.show(
                          context, 'Analytics — coming in Part 2'),
                    ),
                    if (exercise.warmups.isNotEmpty) ...[
                      const SizedBox(height: 18),
                      const _Hp(child: _SectionTitle(text: 'Warmup')),
                      const SizedBox(height: 8),
                      const _Hp(child: _Headers()),
                      const SizedBox(height: 4),
                      ..._buildWarmupRows(context, prefill),
                    ],
                    const SizedBox(height: 18),
                    if (exercise.warmups.isNotEmpty || exercise.sets.isNotEmpty)
                      const _Hp(child: _SectionTitle(text: 'Sets')),
                    const SizedBox(height: 8),
                    const _Hp(child: _Headers()),
                    const SizedBox(height: 4),
                    ..._buildSetRows(context, prefill, firstUnlogged?.id),
                    // Drop sets flow inline directly after the effective
                    // rows — no section title, no repeated WEIGHT/REPS
                    // header, just the D-marker rows so the visual feels
                    // like a continuation of the same table.
                    if (exercise.dropSets.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      ..._buildDropSetRows(context, prefill),
                    ],
                    // Add Set is available in both modes. In preview it
                    // mutates the WorkoutPreviewBloc draft (no session
                    // exists yet); the rows carry into the live session
                    // when the user taps Start Workout.
                    //
                    // KeyedSubtree pins the wrapper itself so the
                    // AddSetButton's selector state survives the list
                    // rebuild that fires when the user adds their first
                    // drop set: the drop-set section pops in above and
                    // shifts every following child's index. Putting the
                    // key on the AddSetButton alone wouldn't help —
                    // Flutter matches the outer _Hp by position first
                    // and re-mounts everything below it.
                    const SizedBox(height: 8),
                    KeyedSubtree(
                      key: const ValueKey('add_set_button'),
                      child: _Hp(
                        child: AddSetButton(
                          onAddSet: (kind) => mode.onAddRow(kind),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Hp(
                      child: NotesCard(
                        initialValue: exercise.notes,
                        onChanged: mode.onNotesChanged,
                        readOnly: mode.isPreview,
                      ),
                    ),
                  ],
                ),
                if (restActive)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 12,
                    child: RestTimerCard(
                      endsAt: s.activeRestEndsAt!,
                      totalSeconds: s.restDurationSeconds,
                      onCancel: () => context
                          .read<WorkoutSessionBloc>()
                          .add(const CancelRestTimer()),
                      onAdjust: (delta) => context
                          .read<WorkoutSessionBloc>()
                          .add(AdjustRestTimer(delta)),
                    ),
                  ),
              ],
            ),
          ),
          LogSetButton(
            label: mode.bottomLabel,
            enabled: mode.bottomEnabled,
            isAwaitingDoneConfirmation:
                !mode.isPreview && exercise.isAwaitingDoneConfirmation,
            onTap: () => mode.onBottomTap(context),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: TapScale(
        scaleDown: TapScalePreset.icon.scale,
        onTap: () => Navigator.of(context).maybePop(),
        child: const Center(
          child: Icon(
            CupertinoIcons.back,
            color: AppTheme.primaryOrange,
            size: 26,
          ),
        ),
      ),
      title: Text(
        exercise.name,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      // Brief Phase 3 Part 3 §7 — three-dot menu opens the same
      // bottom sheet as the workout-detail screen. Replace routes
      // through whichever store the current mode is bound to:
      //   - live mode  → WorkoutSessionBloc.ReplaceExercise
      //   - preview    → WorkoutDetailBloc.ReplaceExercise (writes
      //                  the swap through to the workout template)
      // Either path preserves logged sets, notes, warmups, drop sets
      // and the rest timer (clarification 7.20).
      actions: [
        IconButton(
          icon: const Icon(
            Icons.more_horiz,
            color: AppTheme.primaryOrange,
          ),
          onPressed: () => _openExerciseOptions(context),
        ),
      ],
    );
  }

  void _openExerciseOptions(BuildContext context) {
    final repo = getIt<ExerciseRepository>();
    final catalog = repo.getExerciseById(exercise.exerciseId);
    final ex = catalog ??
        Exercise(
          id: exercise.exerciseId,
          name: exercise.name,
          sets: exercise.targetSets,
          reps: 10,
          weight: 0,
          muscleGroups: exercise.muscleGroups,
          equipmentType: exercise.equipment,
          rating: 0,
        );
    final mode = widget.mode;
    showExerciseOptionsSheet(
      context,
      exercise: ex,
      onReplace: (newExercise) {
        // Hand replacement to whichever store the screen is bound to:
        // - Live mode → WorkoutSessionBloc.ReplaceExercise via slot.
        //   The slot keeps the same slotId across the swap, so the
        //   screen stays put — no anchor change needed. PR baselines
        //   refresh from the bloc as the new exerciseId loads.
        // - Preview mode → WorkoutDetailBloc.ReplaceExercise (writes
        //   the swap into this detail bloc's state). The preview pops
        //   itself before we get here — we must NOT re-anchor on the
        //   new id, because widget.previewWorkout is the snapshot
        //   from preview-open time and doesn't contain the new
        //   exercise yet. Any rebuild that fires before the route
        //   finishes deactivating would then ask the snapshot for
        //   the new id and blow up.
        final oldRef = mode.isPreview
            ? exercise.exerciseId  // preview keys slots by catalog id
            : exercise.slotId;     // live keys slots by slotId
        mode.onReplaceExercise(context, oldRef, newExercise);
        // Live: slotId is preserved, no re-anchor. Preview: route is
        // popping, the higher detail-screen now reflects the swap.
      },
    );
  }

  Widget _row({
    required SessionSet set,
    required String marker,
    required SetKind kind,
    required bool isCurrent,
    required bool isPr,
    required _Prefill prefill,
    required String focusKey,
  }) {
    final mode = widget.mode;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: _LoggingSetRow(
        exerciseId: exercise.exerciseId,
        set: set,
        marker: marker,
        kind: kind,
        isCurrent: isCurrent,
        isPr: isPr,
        prefill: prefill,
        weightFocus: weightFocusFor(focusKey),
        repsFocus: repsFocusFor(focusKey),
        celebrationController: celebrationFor(set.id),
        onSubmitted: () => mode.onBottomTap(context),
        onDelete: () => mode.onDeleteRow(set.id, kind),
        onWeightChanged: (v) => mode.onWeightChanged(
          setId: set.id,
          kind: kind,
          weight: v,
        ),
        onRepsChanged: (v) => mode.onRepsChanged(
          setId: set.id,
          kind: kind,
          reps: v,
        ),
        // Preview mode locks weight/reps fields — the user can browse
        // hints and add/delete/replace rows, but values are entered
        // only after Start Workout.
        readOnly: mode.isPreview,
      ),
    );
  }

  List<Widget> _buildWarmupRows(BuildContext context, _Prefill prefill) {
    if (exercise.warmups.isEmpty) return const [];
    final firstUnlogged = exercise.firstUnloggedWarmup;
    return [
      for (var i = 0; i < exercise.warmups.length; i++)
        _row(
          set: exercise.warmups[i],
          marker: 'W',
          kind: SetKind.warmup,
          isCurrent: exercise.warmups[i].id == firstUnlogged?.id,
          isPr: false,
          prefill: prefill,
          focusKey: 'warmup_${exercise.warmups[i].id}',
        ),
    ];
  }

  List<Widget> _buildSetRows(
    BuildContext context,
    _Prefill prefill,
    String? currentSetId,
  ) {
    return [
      for (var i = 0; i < exercise.sets.length; i++)
        _row(
          set: exercise.sets[i],
          marker: '${i + 1}',
          kind: SetKind.effective,
          // Warmup pending → no effective row is "current" yet.
          isCurrent: !exercise.hasWarmupPending &&
              exercise.sets[i].id == currentSetId,
          isPr: prSetIds.contains(exercise.sets[i].id),
          prefill: prefill,
          focusKey: exercise.sets[i].id,
        ),
    ];
  }

  List<Widget> _buildDropSetRows(BuildContext context, _Prefill prefill) {
    if (exercise.dropSets.isEmpty) return const [];
    final firstUnlogged = exercise.firstUnloggedDropSet;
    return [
      for (var i = 0; i < exercise.dropSets.length; i++)
        _row(
          set: exercise.dropSets[i],
          marker: 'D',
          kind: SetKind.dropSet,
          isCurrent: !exercise.hasWarmupPending &&
              exercise.firstUnloggedSet == null &&
              exercise.dropSets[i].id == firstUnlogged?.id,
          isPr: false,
          prefill: prefill,
          focusKey: 'drop_${exercise.dropSets[i].id}',
        ),
    ];
  }

  /// Move focus to the WEIGHT field of [setId] **synchronously** so the
  /// IME performs an in-place focus transfer instead of closing and
  /// re-opening the soft keyboard. WEIGHT is the first column in a row,
  /// so this is where the chain should land after Log Set.
  ///
  /// `addPostFrameCallback` would land the focus request a frame too late:
  /// the previous field has already lost focus and the system has begun
  /// dismissing the keyboard, so we'd see a flicker. Calling
  /// `requestFocus()` immediately keeps a focused TextField in the tree at
  /// every moment — the OS treats it as a connection swap.
  void _focusWeight(String setId) {
    weightFocusFor(setId).requestFocus();
  }

  /// Pre-fill order:
  ///   1. Last logged set in *this* session (so set #2 picks up set #1).
  ///   2. Last logged set from history (previous finished session).
  ///   3. Catalog plan (Exercise.weight / Exercise.reps).
  _Prefill _resolvePrefill(SessionExercise ex) {
    final last = ex.lastLoggedSet;
    if (last != null) return (weight: last.weight, reps: last.reps);
    if (historyLastLog != null) {
      return (weight: historyLastLog!.weight, reps: historyLastLog!.reps);
    }
    final repo = getIt<ExerciseRepository>();
    final Exercise? plan = repo.getExerciseById(ex.exerciseId);
    return (weight: plan?.weight, reps: plan?.reps);
  }
}

/// Horizontal padding wrapper for non-Dismissible items in the logging
/// list. Keeps content aligned at 16px from each edge while leaving the
/// ListView itself edge-to-edge so swipe-to-delete backgrounds extend to
/// the screen edge.
class _Hp extends StatelessWidget {
  final Widget child;
  const _Hp({required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _Headers extends StatelessWidget {
  const _Headers();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        // Reserve the same width the row uses for its SET marker so the
        // column headers align with the pills underneath.
        SizedBox(width: 28),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'WEIGHT (lb)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'REPS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// One swipeable, PR-celebrating, draft-dispatching row in the
/// logging list. Encapsulates everything that used to live as nested
/// matryoshka under the scaffold's `_swipeableRow` helper:
///
///   SwipeToDelete → _Hp → PrCelebration → EffectiveSetRow
///
/// All draft mutations (`UpdateSetDraft`, `DeleteSet`) are dispatched
/// from here directly via `context.read<WorkoutSessionBloc>()` — the
/// scaffold no longer has to forward them through callbacks.
class _LoggingSetRow extends StatelessWidget {
  final String exerciseId;
  final SessionSet set;
  final String marker;
  final SetKind kind;
  final bool isCurrent;
  final bool isPr;
  final _Prefill prefill;
  final FocusNode weightFocus;
  final FocusNode repsFocus;
  final AnimationController celebrationController;
  final VoidCallback onSubmitted;
  final VoidCallback onDelete;
  final ValueChanged<double?> onWeightChanged;
  final ValueChanged<int?> onRepsChanged;
  final bool readOnly;

  const _LoggingSetRow({
    required this.exerciseId,
    required this.set,
    required this.marker,
    required this.kind,
    required this.isCurrent,
    required this.isPr,
    required this.prefill,
    required this.weightFocus,
    required this.repsFocus,
    required this.celebrationController,
    required this.onSubmitted,
    required this.onDelete,
    required this.onWeightChanged,
    required this.onRepsChanged,
    this.readOnly = false,
  });

  String get _keyPrefix {
    switch (kind) {
      case SetKind.warmup:
        return 'warmup';
      case SetKind.dropSet:
        return 'drop';
      case SetKind.effective:
        return 'set';
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = _Hp(
      child: PrCelebration(
        controller: celebrationController,
        child: EffectiveSetRow(
          key: ValueKey('${_keyPrefix}_${set.id}'),
          marker: marker,
          isWarmup: kind == SetKind.warmup,
          weight: set.weight,
          reps: set.reps,
          isLogged: set.isLogged,
          isCurrent: isCurrent,
          isPr: isPr,
          prefillWeight: prefill.weight,
          prefillReps: prefill.reps,
          weightFocusNode: weightFocus,
          repsFocusNode: repsFocus,
          onSubmitted: onSubmitted,
          onWeightChanged: onWeightChanged,
          onRepsChanged: onRepsChanged,
          readOnly: readOnly,
        ),
      ),
    );
    // Swipe-to-delete is available in both modes. readOnly only locks
    // the value inputs (preview mode is for browsing & adding planned
    // rows, not entering numbers); the user can still swipe a planned
    // row off if they added it by mistake.
    return SwipeToDelete(
      dismissKey: ValueKey('${_keyPrefix}_dismiss_${set.id}'),
      borderRadius: BorderRadius.zero,
      onDismissed: onDelete,
      child: row,
    );
  }
}
