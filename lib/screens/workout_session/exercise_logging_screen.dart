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
        getIt<WorkoutSessionRepository>().lastLogFor(widget.exerciseId);

    final bloc = context.read<WorkoutSessionBloc>();
    _prSub = bloc.prSignals.listen(_onPrSignal);
  }

  void _onPrSignal(PrSignal signal) {
    switch (signal) {
      case PrAchievedSignal():
        _onPrAchieved(signal);
      case PrRevokedSignal():
        _onPrRevoked(signal);
    }
  }

  void _onPrAchieved(PrAchievedSignal signal) {
    if (signal.exerciseId != widget.exerciseId) return;
    if (!mounted) return;
    setState(() => _prSetIds.add(signal.setId));
    celebrationFor(signal.setId).forward(from: 0);
    getIt<HapticManager>().strongest();
    PrNewLabel.show(context);
  }

  void _onPrRevoked(PrRevokedSignal signal) {
    if (signal.exerciseId != widget.exerciseId) return;
    if (!mounted) return;
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
              weightFocusFor: _weightFocusFor,
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
  final FocusNode Function(String key) weightFocusFor;
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
    required this.weightFocusFor,
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
    if (warmup == null) return const SizedBox.shrink();
    return _LoggingSetRow(
      exerciseId: exercise.exerciseId,
      set: warmup,
      marker: 'W',
      isWarmup: true,
      isCurrent: !warmup.isLogged,
      isPr: false,
      prefill: prefill,
      weightFocus: weightFocusFor('warmup'),
      repsFocus: repsFocusFor('warmup'),
      celebrationController: celebrationFor(warmup.id),
      onSubmitted: () => _onLogSetTap(context),
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
          child: _LoggingSetRow(
            exerciseId: exercise.exerciseId,
            set: exercise.sets[i],
            marker: '${i + 1}',
            isWarmup: false,
            // Warmup pending → no effective row is "current" yet.
            isCurrent: !exercise.hasWarmupPending &&
                exercise.sets[i].id == currentSetId,
            isPr: prSetIds.contains(exercise.sets[i].id),
            prefill: prefill,
            weightFocus: weightFocusFor(exercise.sets[i].id),
            repsFocus: repsFocusFor(exercise.sets[i].id),
            celebrationController: celebrationFor(exercise.sets[i].id),
            onSubmitted: () => _onLogSetTap(context),
          ),
        ),
    ];
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
        _focusWeight(remainingEffective.first.id);
      }
      return;
    }

    if (remainingEffective.isEmpty) {
      bloc.add(MarkExerciseDone(exercise.exerciseId));
    } else {
      bloc.add(const StartRestTimer());
      _focusWeight(remainingEffective.first.id);
    }
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
  final bool isWarmup;
  final bool isCurrent;
  final bool isPr;
  final _Prefill prefill;
  final FocusNode weightFocus;
  final FocusNode repsFocus;
  final AnimationController celebrationController;
  final VoidCallback onSubmitted;

  const _LoggingSetRow({
    required this.exerciseId,
    required this.set,
    required this.marker,
    required this.isWarmup,
    required this.isCurrent,
    required this.isPr,
    required this.prefill,
    required this.weightFocus,
    required this.repsFocus,
    required this.celebrationController,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<WorkoutSessionBloc>();
    return SwipeToDelete(
      dismissKey: ValueKey(
        isWarmup ? 'warmup_dismiss_${set.id}' : 'set_dismiss_${set.id}',
      ),
      borderRadius: BorderRadius.zero,
      onDismissed: () => bloc.add(
        DeleteSet(
          exerciseId: exerciseId,
          setId: set.id,
          isWarmup: isWarmup,
        ),
      ),
      child: _Hp(
        child: PrCelebration(
          controller: celebrationController,
          child: EffectiveSetRow(
            key: ValueKey(isWarmup ? 'warmup_${set.id}' : 'set_${set.id}'),
            marker: marker,
            isWarmup: isWarmup,
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
            onWeightChanged: (v) => bloc.add(UpdateSetDraft(
              exerciseId: exerciseId,
              setId: set.id,
              weight: v,
              isWarmup: isWarmup,
              clearWeight: v == null,
            )),
            onRepsChanged: (v) => bloc.add(UpdateSetDraft(
              exerciseId: exerciseId,
              setId: set.id,
              reps: v,
              isWarmup: isWarmup,
              clearReps: v == null,
            )),
          ),
        ),
      ),
    );
  }
}
