import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/service_locator.dart';
import '../../models/exercise.dart';
import '../../models/session/session_exercise.dart';
import '../../models/session/workout_session.dart';
import '../../models/workout.dart';
import '../../repositories/exercise_repository.dart';
import '../../theme/app_theme.dart';
import '../workout_detail/widgets/exercise_navigation.dart';
import 'bloc/workout_session_bloc.dart';
import 'bloc/workout_session_event.dart';
import 'bloc/workout_session_state.dart';
import 'exercise_logging_screen.dart';
import 'widgets/cancel_workout_dialog.dart';
import 'widgets/persistent_workout_timer.dart';
import 'widgets/session_app_bar.dart';
import 'widgets/session_exercise_card.dart';
import 'widgets/session_finish_button.dart';
import 'widgets/swipe_to_delete.dart';
import 'widgets/warmup_choice_tile.dart';

/// Workout session main screen.
///
/// Two entry shapes:
///  - `WorkoutSessionScreen.start(workout: ...)` — fresh session.
///  - `WorkoutSessionScreen.restored()` — bloc already in SessionActive
///    (used by app-launch restore path from main.dart).
class WorkoutSessionScreen extends StatelessWidget {
  final Workout? startWorkout;
  final bool restored;

  const WorkoutSessionScreen._({
    this.startWorkout,
    this.restored = false,
  });

  factory WorkoutSessionScreen.start({required Workout workout}) {
    return WorkoutSessionScreen._(startWorkout: workout);
  }

  factory WorkoutSessionScreen.restored() {
    return const WorkoutSessionScreen._(restored: true);
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
      child: const _WorkoutSessionView(),
    );
  }
}

class _WorkoutSessionView extends StatelessWidget {
  const _WorkoutSessionView();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkoutSessionBloc, WorkoutSessionState>(
      listenWhen: (prev, next) =>
          (next is SessionFinished ||
                  next is SessionCancelled ||
                  next is SessionIdle) &&
              prev is! SessionIdle ||
          (prev is SessionLoading && next is SessionIdle),
      listener: (context, state) {
        if (state is SessionFinished ||
            state is SessionCancelled ||
            state is SessionIdle) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).popUntil((r) => r.isFirst);
          }
        }
      },
      builder: (context, state) {
        if (state is SessionActive) {
          return _ActiveSessionScaffold(state: state);
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

class _ActiveSessionScaffold extends StatefulWidget {
  final SessionActive state;
  const _ActiveSessionScaffold({required this.state});

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
  final Map<String, GlobalKey> _cardKeys = {};

  GlobalKey _cardKeyFor(String exerciseId) =>
      _cardKeys.putIfAbsent(exerciseId, () => GlobalKey());

  GlobalKey? get _activeCardKey {
    final id = widget.state.session.activeExerciseId;
    return id == null ? null : _cardKeys[id];
  }

  @override
  void initState() {
    super.initState();
    _scheduleScrollToActive();
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
  }

  @override
  void didPopNext() {
    // Returning from logging screen — re-anchor on the active card.
    _scheduleScrollToActive();
  }

  @override
  void dispose() {
    getIt<RouteObserver<PageRoute<dynamic>>>().unsubscribe(this);
    super.dispose();
  }

  void _scheduleScrollToActive() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _activeCardKey?.currentContext;
      if (ctx == null || !mounted) return;
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
          // Floating Finish button — same shape/shadow as Start Workout on
          // the Workout Detail screen.
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: SafeArea(
              child: SessionFinishButton(
                onTap: () => context
                    .read<WorkoutSessionBloc>()
                    .add(const FinishWorkout()),
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
      CupertinoPageRoute(
        builder: (_) => ExerciseLoggingScreen(
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
