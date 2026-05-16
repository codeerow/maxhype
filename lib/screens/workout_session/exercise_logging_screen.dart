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

/// Logging screen for a single exercise. Mounts the shared
/// `WorkoutSessionBloc` so any state mutations stay in sync with the main
/// session screen.
class ExerciseLoggingScreen extends StatelessWidget {
  final String exerciseId;
  final WorkoutSessionBloc bloc;

  const ExerciseLoggingScreen({
    super.key,
    required this.exerciseId,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WorkoutSessionBloc>.value(
      value: bloc,
      child: _LoggingView(exerciseId: exerciseId),
    );
  }
}

class _LoggingView extends StatefulWidget {
  final String exerciseId;
  const _LoggingView({required this.exerciseId});

  @override
  State<_LoggingView> createState() => _LoggingViewState();
}

class _LoggingViewState extends State<_LoggingView>
    with TickerProviderStateMixin {
  late final Future<SessionSet?> _historyFuture;

  /// Stable FocusNodes for REPS fields keyed by set id (or 'warmup'). Lets
  /// the Log Set / Done IME action programmatically jump focus to the next
  /// set's REPS field after the previous one is logged.
  final Map<String, FocusNode> _repsFocusNodes = {};

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

  StreamSubscription<PrAchievedSignal>? _prSub;

  @override
  void initState() {
    super.initState();
    _historyFuture =
        getIt<WorkoutSessionRepository>().lastLogFor(widget.exerciseId);

    final bloc = context.read<WorkoutSessionBloc>();
    _prSub = bloc.prSignals.listen(_onPrAchieved);
  }

  void _onPrAchieved(PrAchievedSignal signal) {
    if (signal.exerciseId != widget.exerciseId) return;
    if (!mounted) return;
    setState(() => _prSetIds.add(signal.setId));
    celebrationFor(signal.setId).forward(from: 0);
    getIt<HapticManager>().strongest();
    PrNewLabel.show(context);
  }

  @override
  void dispose() {
    _prSub?.cancel();
    for (final n in _repsFocusNodes.values) {
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
      (e) => e.exerciseId == widget.exerciseId,
    );
    return ex?.completed ?? false;
  }

  @override
  Widget build(BuildContext context) {
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
          (e) => e.exerciseId == widget.exerciseId,
        );
        if (ex == null) {
          // Exercise was removed (e.g., deleted while screen was open) —
          // close ourselves on the next frame.
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
            // History is best-effort pre-fill — show the screen immediately
            // and fill in once the future resolves.
            return _LoggingScaffold(
              exercise: ex,
              session: state.session,
              historyLastLog: snapshot.data,
              repsFocusFor: _repsFocusFor,
              celebrationFor: celebrationFor,
              prSetIds: _prSetIds,
              currentPr: bloc.prFor(widget.exerciseId),
              previousBest: bloc.previousBestFor(widget.exerciseId),
              isFreshPr: _prSetIds.isNotEmpty,
            );
          },
        );
      },
    );
  }
}

class _LoggingScaffold extends StatefulWidget {
  final SessionExercise exercise;
  final WorkoutSession session;
  final SessionSet? historyLastLog;
  final FocusNode Function(String key) repsFocusFor;
  final AnimationController Function(String setId) celebrationFor;
  final Set<String> prSetIds;
  final PersonalRecord? currentPr;
  final PersonalRecord? previousBest;
  final bool isFreshPr;

  const _LoggingScaffold({
    required this.exercise,
    required this.session,
    required this.historyLastLog,
    required this.repsFocusFor,
    required this.celebrationFor,
    required this.prSetIds,
    required this.currentPr,
    required this.previousBest,
    required this.isFreshPr,
  });

  @override
  State<_LoggingScaffold> createState() => _LoggingScaffoldState();
}

class _LoggingScaffoldState extends State<_LoggingScaffold> {
  // Field shorthands so the existing helper methods (_buildSetRows,
  // _onLogSetTap, etc.) can keep using bare names instead of `widget.x`.
  SessionExercise get exercise => widget.exercise;
  WorkoutSession get session => widget.session;
  SessionSet? get historyLastLog => widget.historyLastLog;
  FocusNode Function(String key) get repsFocusFor => widget.repsFocusFor;
  AnimationController Function(String setId) get celebrationFor =>
      widget.celebrationFor;
  Set<String> get prSetIds => widget.prSetIds;
  PersonalRecord? get currentPr => widget.currentPr;
  PersonalRecord? get previousBest => widget.previousBest;
  bool get isFreshPr => widget.isFreshPr;

  @override
  Widget build(BuildContext context) {
    final prefill = _resolvePrefill(exercise);
    final firstUnlogged = exercise.firstUnloggedSet;

    final restActive = session.activeRestEndsAt != null &&
        session.activeRestEndsAt!.isAfter(DateTime.now());

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          // Scrolling area with the rest-timer card overlaid on top.
          // List rows scroll under the (transparent-background) timer
          // until they reach the bottom of this Stack, which sits
          // exactly above the Log Set button.
          Expanded(
            child: Stack(
              children: [
                ListView(
                  // Edge-to-edge horizontally so swipe-to-delete bleeds
                  // off the screen edge. Bottom padding reserves room
                  // for the rest-timer card to overlay the last rows,
                  // plus a small breathing-room tail in both states.
                  padding: EdgeInsets.fromLTRB(
                    0,
                    8,
                    0,
                    (restActive ? _kRestCardReserve : 0) + 16,
                  ),
                  children: [
                    if (currentPr != null)
                      PrHeader(
                        pr: currentPr!,
                        previousBest: previousBest,
                        isFresh: isFreshPr,
                      ),
                    ActionChipRow(
                      restSeconds: session.restDurationSeconds,
                      onRestTap: () =>
                          AppToast.show(context, 'Rest timer adjusts in card'),
                      onInstructionTap: () => AppToast.show(
                          context, 'Instructions — coming in Part 2'),
                      onAnalyticsTap: () => AppToast.show(
                          context, 'Analytics — coming in Part 2'),
                    ),
                    const SizedBox(height: 18),
                    const _Hp(child: _SectionTitle(text: 'Warmup')),
                    const SizedBox(height: 8),
                    const _Hp(child: _Headers()),
                    const SizedBox(height: 4),
                    _buildWarmupRow(context, prefill),
                    const SizedBox(height: 18),
                    const _Hp(child: _SectionTitle(text: 'Effective sets')),
                    const _Hp(
                      child: Divider(
                        color: AppTheme.textSecondary,
                        height: 18,
                        thickness: 0.4,
                      ),
                    ),
                    const _Hp(child: _Headers()),
                    const SizedBox(height: 4),
                    ..._buildSetRows(context, prefill, firstUnlogged?.id),
                    const SizedBox(height: 8),
                    _Hp(
                      child: AddSetButton(
                        onAddOne: () => context
                            .read<WorkoutSessionBloc>()
                            .add(AddSet(exercise.exerciseId)),
                        onAddMany: (count) {
                          final bloc = context.read<WorkoutSessionBloc>();
                          for (var i = 0; i < count; i++) {
                            bloc.add(AddSet(exercise.exerciseId));
                          }
                        },
                      ),
                    ),
                    const SizedBox(height: 22),
                    _Hp(
                      child: NotesCard(
                        initialValue: exercise.notes,
                        onChanged: (s) =>
                            context.read<WorkoutSessionBloc>().add(
                                  UpdateNotes(
                                    exerciseId: exercise.exerciseId,
                                    notes: s,
                                  ),
                                ),
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
                      endsAt: session.activeRestEndsAt!,
                      totalSeconds: session.restDurationSeconds,
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
            enabled: exercise.currentTarget?.isFilled ?? false,
            isFinalSet: exercise.isOnFinalEffectiveSet,
            onTap: () => _onLogSetTap(context),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      leading: TapScale(
        scaleDown: 0.90,
        onTap: () => Navigator.of(context).maybePop(),
        child: const Center(
          child: Icon(
            CupertinoIcons.back,
            color: AppTheme.textPrimary,
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
    );
  }

  Widget _buildWarmupRow(BuildContext context, _Prefill prefill) {
    final warmup = exercise.warmupSet;
    if (warmup == null) {
      return const SizedBox.shrink();
    }
    return _swipeableRow(
      context: context,
      set: warmup,
      marker: 'W',
      isWarmup: true,
      isCurrent: !warmup.isLogged,
      prefill: prefill,
    );
  }

  List<Widget> _buildSetRows(
    BuildContext context,
    _Prefill prefill,
    String? currentSetId,
  ) {
    return [
      for (var i = 0; i < exercise.sets.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _swipeableRow(
            context: context,
            set: exercise.sets[i],
            marker: '${i + 1}',
            // Warmup pending → no effective row is "current" yet.
            isCurrent: !exercise.hasWarmupPending &&
                exercise.sets[i].id == currentSetId,
            prefill: prefill,
          ),
        ),
    ];
  }

  /// Single source of truth for building a swipeable [EffectiveSetRow].
  /// Used by both warmup row and effective set rows so wiring stays consistent.
  Widget _swipeableRow({
    required BuildContext context,
    required SessionSet set,
    required String marker,
    required bool isCurrent,
    required _Prefill prefill,
    bool isWarmup = false,
  }) {
    return SwipeToDelete(
      dismissKey: ValueKey(
        isWarmup ? 'warmup_dismiss_${set.id}' : 'set_dismiss_${set.id}',
      ),
      borderRadius: BorderRadius.zero,
      onDismissed: () => context.read<WorkoutSessionBloc>().add(
            DeleteSet(
              exerciseId: exercise.exerciseId,
              setId: set.id,
              isWarmup: isWarmup,
            ),
          ),
      child: _Hp(
        child: PrCelebration(
          controller: celebrationFor(set.id),
          child: EffectiveSetRow(
            key: ValueKey(isWarmup ? 'warmup_${set.id}' : 'set_${set.id}'),
            marker: marker,
            isWarmup: isWarmup,
            weight: set.weight,
            reps: set.reps,
            isLogged: set.isLogged,
            isCurrent: isCurrent,
            isPr: !isWarmup && prSetIds.contains(set.id),
            prefillWeight: prefill.weight,
            prefillReps: prefill.reps,
            repsFocusNode: repsFocusFor(isWarmup ? 'warmup' : set.id),
            onSubmitted: () => _onLogSetTap(context),
            onWeightChanged: (v) => context.read<WorkoutSessionBloc>().add(
                  UpdateSetDraft(
                    exerciseId: exercise.exerciseId,
                    setId: set.id,
                    weight: v,
                    isWarmup: isWarmup,
                    clearWeight: v == null,
                  ),
                ),
            onRepsChanged: (v) => context.read<WorkoutSessionBloc>().add(
                  UpdateSetDraft(
                    exerciseId: exercise.exerciseId,
                    setId: set.id,
                    reps: v,
                    isWarmup: isWarmup,
                    clearReps: v == null,
                  ),
                ),
          ),
        ),
      ),
    );
  }

  void _onLogSetTap(BuildContext context) {
    final bloc = context.read<WorkoutSessionBloc>();
    final target = exercise.currentTarget;
    if (target == null || !target.isFilled) return;

    final isWarmup = exercise.isCurrentTargetWarmup;
    bloc.add(LogSet(
      exerciseId: exercise.exerciseId,
      setId: target.id,
      weight: target.weight!,
      reps: target.reps!,
      isWarmup: isWarmup,
    ));

    // Compute the next set we'd jump to so the IME can chain into it. We
    // figure this out *before* dispatching MarkExerciseDone (that pops the
    // screen, so jumping focus would be pointless then).
    final remainingEffective =
        exercise.sets.where((s) => !s.isLogged && s.id != target.id).toList();

    if (isWarmup) {
      bloc.add(const StartRestTimer());
      if (remainingEffective.isNotEmpty) {
        _focusReps(remainingEffective.first.id);
      }
      return;
    }

    if (remainingEffective.isEmpty) {
      bloc.add(MarkExerciseDone(exercise.exerciseId));
    } else {
      bloc.add(const StartRestTimer());
      _focusReps(remainingEffective.first.id);
    }
  }

  /// Move focus to the REPS field of [setId] **synchronously** so the IME
  /// performs an in-place focus transfer instead of closing and re-opening
  /// the soft keyboard.
  ///
  /// `addPostFrameCallback` would land the focus request a frame too late:
  /// the previous field has already lost focus and the system has begun
  /// dismissing the keyboard, so we'd see a flicker. Calling
  /// `requestFocus()` immediately keeps a focused TextField in the tree at
  /// every moment — the OS treats it as a connection swap.
  void _focusReps(String setId) {
    repsFocusFor(setId).requestFocus();
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
        SizedBox(
          width: 50,
          child: Text(
            'SET',
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
      ],
    );
  }
}
