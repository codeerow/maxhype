import 'dart:async';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/battery_optimization.dart';
import '../../core/haptic_manager.dart';
import '../../core/service_locator.dart';
import '../../main.dart' show MyApp;
import '../../models/exercise.dart';
import '../../models/session/session_exercise.dart';
import '../../models/session/workout_session.dart';
import '../../models/workout.dart';
import '../../repositories/exercise_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/animations/animations.dart';
import '../../widgets/app_toast.dart';
import '../workout_detail/widgets/exercise_navigation.dart';
import 'bloc/workout_session_bloc.dart';
import 'bloc/workout_session_event.dart';
import 'bloc/workout_session_state.dart';
import 'exercise_logging_screen.dart';
import 'in_progress_bar_routing.dart';
import 'widgets/cancel_workout_dialog.dart';
import 'widgets/persistent_workout_timer.dart';
import 'widgets/session_app_bar.dart';
import 'widgets/session_exercise_card.dart';
import 'widgets/session_finish_button.dart';
import 'widgets/swipe_to_delete.dart';
import 'widgets/warmup_choice_tile.dart';

/// Workout session main screen.
///
/// Entry shapes:
///  - `WorkoutSessionScreen.start(workout: ...)` — fresh session.
///  - `WorkoutSessionScreen.restored()` — bloc already in SessionActive
///    (used by app-launch restore path from main.dart).
///  - `WorkoutSessionScreen.restoredAndOpenActive()` — same restore
///    path, plus on first frame push the logging screen for the
///    resume-target exercise. Used by the "WORKOUT IN PROGRESS" bar
///    so a tap drops the user back into the row they were logging
///    (brief Phase 3 Part 3 §5).
class WorkoutSessionScreen extends StatelessWidget {
  final Workout? startWorkout;
  final bool restored;
  final bool autoOpenActive;

  const WorkoutSessionScreen._({
    this.startWorkout,
    this.restored = false,
    this.autoOpenActive = false,
  });

  factory WorkoutSessionScreen.start({required Workout workout}) {
    return WorkoutSessionScreen._(startWorkout: workout);
  }

  factory WorkoutSessionScreen.restored() {
    return const WorkoutSessionScreen._(restored: true);
  }

  factory WorkoutSessionScreen.restoredAndOpenActive() {
    return const WorkoutSessionScreen._(
      restored: true,
      autoOpenActive: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bloc = getIt<WorkoutSessionBloc>();
    if (startWorkout != null) {
      final current = bloc.state;
      // Resume the existing session if it matches the workout we were asked
      // to start. Only dispatch StartSession when there's no active session,
      // or it belongs to a different workout — in which case the bloc replaces
      // the session.
      final shouldStart = current is! SessionActive ||
          current.session.workoutId != startWorkout!.id;
      if (shouldStart) {
        bloc.add(StartSession(startWorkout!));
      }
    }
    return BlocProvider<WorkoutSessionBloc>.value(
      value: bloc,
      child: _WorkoutSessionView(autoOpenActive: autoOpenActive),
    );
  }
}

class _WorkoutSessionView extends StatelessWidget {
  final bool autoOpenActive;
  const _WorkoutSessionView({this.autoOpenActive = false});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkoutSessionBloc, WorkoutSessionState>(
      listenWhen: _shouldDismissSession,
      listener: _onSessionDismissed,
      builder: (context, state) {
        if (state is SessionActive) {
          return _ActiveSessionScaffold(
            state: state,
            autoOpenActive: autoOpenActive,
          );
        }
        if (state is SessionLoading || state is SessionFinishing) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: Center(
              child: CircularProgressIndicator(
                color: AppTheme.recoveryGreen,
              ),
            ),
          );
        }
        return const Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: SizedBox.shrink(),
        );
      },
    );
  }
}

/// True for the one-shot transition that means "the session screen
/// should pop and, if applicable, show a finish/cancel toast".
///
/// Three legitimate sources:
///  - Finish: Active → Finishing → Finished → Idle
///  - Cancel: Active → Cancelled → Idle
///  - Restore-with-nothing: Loading → Idle
///
/// We fire on the *first* terminal state of each flow (Finished /
/// Cancelled), so the trailing Idle is ignored and the listener runs
/// once per dismiss. The Loading→Idle case has no Finished/Cancelled
/// to ride on, so we fire on Idle there.
bool _shouldDismissSession(
  WorkoutSessionState prev,
  WorkoutSessionState next,
) {
  if (next is SessionFinished || next is SessionCancelled) return true;
  if (next is SessionIdle && prev is SessionLoading) return true;
  return false;
}

void _onSessionDismissed(BuildContext context, WorkoutSessionState state) {
  if (Navigator.of(context).canPop()) {
    Navigator.of(context).popUntil((r) => r.isFirst);
  }
  // Toast on the root overlay so it survives the popUntil above —
  // the session screen's own overlay is gone by the next frame.
  // We grab the OverlayState directly: the root Navigator's *context*
  // sits above the overlay, so Overlay.of(rootCtx) returns null and
  // the toast would silently no-op.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final overlay = MyApp.rootNavKey.currentState?.overlay;
    if (overlay == null) return;
    if (state is SessionFinished) {
      AppToast.showPremiumOnOverlay(
        overlay,
        'Workout Completed!',
        accent: AppTheme.primaryOrange,
      );
      getIt<HapticManager>().strongest();
    } else if (state is SessionCancelled) {
      AppToast.showPremiumOnOverlay(
        overlay,
        'Workout Cancelled',
        accent: AppTheme.primaryOrange,
      );
    }
  });
}

class _ActiveSessionScaffold extends StatefulWidget {
  final SessionActive state;
  final bool autoOpenActive;
  const _ActiveSessionScaffold({
    required this.state,
    this.autoOpenActive = false,
  });

  @override
  State<_ActiveSessionScaffold> createState() => _ActiveSessionScaffoldState();
}

class _ActiveSessionScaffoldState extends State<_ActiveSessionScaffold>
    with RouteAware {
  /// Stable per-exercise GlobalKeys. Used for two things:
  ///  1. Keeping the same widget identity across active ↔ completed
  ///     transitions so the SessionExerciseCard's State is not rebuilt
  ///     (which would swallow the completion scale-in animation).
  ///  2. Scrolling a specific card into view via Scrollable.ensureVisible.
  ///
  /// Keys are pruned in [didUpdateWidget] whenever the exercise list
  /// changes, so a deleted or replaced exercise doesn't leave a stale
  /// GlobalKey behind. Without that cleanup, a replaced exercise that
  /// later got swapped back into the same session would attach a key
  /// that's still bound to the old card's render tree and trip the
  /// "Multiple widgets used the same GlobalKey" assertion.
  final Map<String, GlobalKey> _cardKeys = {};

  /// Pending scroll request — held while the route's push transition
  /// finishes. Calling Scrollable.ensureVisible while the screen is still
  /// transitioning interleaves with ListView's first-frame layout pass and
  /// can leave intermediate items un-painted until the user scrolls.
  Timer? _scrollTimer;

  GlobalKey _cardKeyFor(String exerciseId) =>
      _cardKeys.putIfAbsent(exerciseId, GlobalKey.new);

  GlobalKey? get _activeCardKey {
    final id = widget.state.session.activeExerciseId;
    return id == null ? null : _cardKeys[id];
  }

  StreamSubscription<dynamic>? _prSub;

  @override
  void initState() {
    super.initState();
    _scheduleScrollToActive();
    // First-time-on-Android: ask the user to whitelist us from battery
    // optimization. If they decline, kicks off a foreground service that
    // keeps us alive for this workout. iOS path is a no-op.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      BatteryOptimization.instance.ensureCovered(context);
    });

    // Re-render exercise cards when a PR fires so the persistent
    // "PERSONAL RECORD" pill appears on the right card.
    _prSub = context.read<WorkoutSessionBloc>().prSignals.listen((_) {
      if (mounted) setState(() {});
    });

    // Brief §5 — when the user tapped the WORKOUT IN PROGRESS bar,
    // the exercise list flashes briefly (this scaffold), then we
    // push the logging screen for the right exercise. We wait for
    // this route's incoming Cupertino transition to finish before
    // stacking the logging screen on top, so the nested push doesn't
    // race the in-flight TransitionRoute animation.
    if (widget.autoOpenActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final route = ModalRoute.of(context);
        route?.didPush().whenComplete(() {
          if (mounted) _autoOpenResumeTarget();
        });
      });
    }
  }

  /// Push the logging screen for the resume-target exercise. When
  /// [resumeTargetExerciseId] returns null (no active exercise — the
  /// user hasn't logged anything yet, or just finished one), we stay
  /// on the exercise list and let them pick the next row to open.
  Future<void> _autoOpenResumeTarget() async {
    final session = widget.state.session;
    final targetId = resumeTargetExerciseId(session);
    if (targetId == null) return;
    final target = session.exercises.firstWhere(
      (e) => e.exerciseId == targetId,
      orElse: () => session.exercises.first,
    );
    await _openLogging(context, target);
  }

  @override
  void dispose() {
    _prSub?.cancel();
    _scrollTimer?.cancel();
    getIt<RouteObserver<PageRoute<dynamic>>>().unsubscribe(this);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) {
      getIt<RouteObserver<PageRoute<dynamic>>>().subscribe(this, route);
    }
  }

  @override
  void didUpdateWidget(covariant _ActiveSessionScaffold old) {
    super.didUpdateWidget(old);
    final oldId = old.state.session.activeExerciseId;
    final newId = widget.state.session.activeExerciseId;
    if (oldId != newId && newId != null) {
      _scheduleScrollToActive();
    }
    // Prune GlobalKeys for exercises that have left the session
    // (delete / replace). Without this the map keeps growing and an
    // exercise re-added later (e.g., replaced back) attaches a key
    // that's still associated with the old render tree, tripping
    // "Multiple widgets used the same GlobalKey".
    final liveIds = widget.state.session.exercises
        .map((e) => e.exerciseId)
        .toSet();
    _cardKeys.removeWhere((id, _) => !liveIds.contains(id));
  }

  @override
  void didPopNext() {
    // Returning from logging screen — re-anchor on the active card.
    _scheduleScrollToActive();
  }

  /// Defer scroll-to-active until after the Cupertino transition has
  /// settled. Triggering `Scrollable.ensureVisible` during the inbound
  /// transition causes the ListView's children to enter a half-laid-out
  /// state where some exercise cards stay invisible until the user scrolls
  /// manually.
  void _scheduleScrollToActive() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(AppDurations.screenSettle, () {
      if (!mounted) return;
      final ctx = _activeCardKey?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.3,
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    final session = widget.state.session;
    return BlocListener<WorkoutSessionBloc, WorkoutSessionState>(
      listenWhen: (_, next) => next is SessionFinishBlockedEmpty,
      listener: (context, _) {
        // Customer feedback: position the finish-guard pill the same
        // way as the "Workout Completed!" toast — low on the screen,
        // attached to / slightly overlapping the Finish button area.
        // No extra lift; the toast lands on the same baseline as the
        // celebration toast (`bottomOffset: 0`).
        AppToast.showPremium(
          context,
          'Complete at least one set first',
          accent: AppTheme.primaryOrange,
        );
        getIt<HapticManager>().medium();
      },
      child: _buildScaffold(context, session),
    );
  }

  Widget _buildScaffold(BuildContext context, WorkoutSession session) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: SessionAppBar(
        title: session.workoutName,
        onBack: () => Navigator.of(context).maybePop(),
        onCancel: () => _confirmCancel(context),
      ),
      body: Stack(
        children: [
          // Main content — bottom padding leaves room for the floating button.
          Column(
            children: [
              const SizedBox(height: 4),
              PersistentWorkoutTimer(startedAt: session.startedAt),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                  children: [
                    const _SectionLabel(text: 'WARM-UP'),
                    const SizedBox(height: 8),
                    WarmupChoiceTile(
                      current: session.warmup,
                      onSelected: (t) => context
                          .read<WorkoutSessionBloc>()
                          .add(SetWarmup(t)),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      '${session.exercises.length} exercises',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._buildExerciseList(context, session),
                  ],
                ),
              ),
            ],
          ),
          // Floating Finish button — compact 80×32 pill centred along
          // the screen's horizontal axis, matching Start Workout on the
          // Workout Detail screen.
          Positioned(
            bottom: 24,
            left: 0,
            right: 0,
            child: Center(
              child: SafeArea(
                child: SessionFinishButton(
                  onTap: () => context
                      .read<WorkoutSessionBloc>()
                      .add(const FinishWorkout()),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExerciseList(
    BuildContext context,
    WorkoutSession session,
  ) {
    final widgets = <Widget>[];
    for (var i = 0; i < session.exercises.length; i++) {
      final ex = session.exercises[i];
      widgets.add(
        SwipeToDelete(
          dismissKey: ValueKey('exercise_dismiss_${ex.exerciseId}'),
          borderRadius: BorderRadius.circular(14),
          onDismissed: () => context
              .read<WorkoutSessionBloc>()
              .add(DeleteExercise(ex.exerciseId)),
          child: SessionExerciseCard(
            // Stable GlobalKey per exerciseId — survives active/completed
            // transitions so the card's State (and its animation
            // controllers) is preserved across rebuilds.
            key: _cardKeyFor(ex.exerciseId),
            exercise: ex,
            isActive:
                session.activeExerciseId == ex.exerciseId && !ex.completed,
            hasPr: context
                .read<WorkoutSessionBloc>()
                .hasFreshPr(ex.exerciseId),
            onTap: () => _openLogging(context, ex),
            onOptions: () => _showOptionsMenu(context, ex),
          ),
        ),
      );
      if (i != session.exercises.length - 1) {
        widgets.add(const SizedBox(height: 10));
      }
    }
    return widgets;
  }

  Future<void> _openLogging(BuildContext context, SessionExercise ex) async {
    final bloc = context.read<WorkoutSessionBloc>();
    // iOS-style horizontal slide: enters from the right, exits to the right
    // on pop. CupertinoPageRoute also enables interactive swipe-back from
    // the left edge for free.
    await Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => ExerciseLoggingScreen.live(
          exerciseId: ex.exerciseId,
          bloc: bloc,
        ),
      ),
    );
  }

  Future<void> _confirmCancel(BuildContext context) async {
    final ok = await showCancelWorkoutDialog(context);
    if (!ok) return;
    if (!context.mounted) return;
    context.read<WorkoutSessionBloc>().add(const CancelWorkout());
  }

  Future<void> _showOptionsMenu(
    BuildContext context,
    SessionExercise ex,
  ) {
    final bloc = context.read<WorkoutSessionBloc>();
    return showExerciseOptionsSheet(
      context,
      exercise: _exerciseFromSession(ex),
      onReplace: (newExercise) {
        bloc.add(
          ReplaceExercise(
            oldExerciseId: ex.exerciseId,
            newExercise: newExercise,
          ),
        );
      },
    );
  }

  /// The Replace sheet expects a full Exercise. Prefer the catalog entry —
  /// it carries rating, image, etc. — but fall back to the SessionExercise
  /// snapshot (name + equipment + muscleGroups) for items that have already
  /// been replaced once and are no longer in the catalog under this id.
  Exercise _exerciseFromSession(SessionExercise ex) {
    final repo = getIt<ExerciseRepository>();
    final found = repo.getExerciseById(ex.exerciseId);
    if (found != null) return found;
    return Exercise(
      id: ex.exerciseId,
      name: ex.name,
      sets: ex.targetSets,
      reps: 10,
      weight: 0,
      muscleGroups: ex.muscleGroups,
      equipmentType: ex.equipment,
      rating: 0,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.2,
      ),
    );
  }
}
