import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/service_locator.dart';
import '../../models/exercise.dart';
import '../../models/muscle_group.dart';
import '../../models/session/session_exercise.dart';
import '../../models/session/workout_session.dart';
import '../../models/workout.dart';
import '../../repositories/exercise_repository.dart';
import '../../theme/app_theme.dart';
import '../workout_detail/widgets/exercise_options_sheet.dart';
import '../workout_detail/widgets/replace_exercise_sheet.dart';
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

class _ActiveSessionScaffold extends StatelessWidget {
  final SessionActive state;
  const _ActiveSessionScaffold({required this.state});

  @override
  Widget build(BuildContext context) {
    final session = state.session;
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
            key: ValueKey('exercise_card_${ex.exerciseId}'),
            exercise: ex,
            isActive:
                session.activeExerciseId == ex.exerciseId && !ex.completed,
            justCompleted: state.justCompletedExerciseId == ex.exerciseId,
            justLogged: state.justLoggedExerciseId == ex.exerciseId,
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
  ) async {
    final bloc = context.read<WorkoutSessionBloc>();
    final fullExercise = _resolveExerciseForReplace(ex);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => ExerciseOptionsSheet(
        exercise: fullExercise,
        onReplaceExercise: () async {
          await Navigator.of(context).push(
            PageRouteBuilder(
              pageBuilder: (_, anim, __) => ReplaceExerciseSheet(
                currentExercise: fullExercise,
                onExerciseSelected: (newExercise) {
                  bloc.add(
                    ReplaceExercise(
                      oldExerciseId: ex.exerciseId,
                      newExercise: newExercise,
                    ),
                  );
                },
              ),
              transitionsBuilder: (_, anim, __, child) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.05),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                  ),
                  child: child,
                ),
              ),
              transitionDuration: const Duration(milliseconds: 220),
            ),
          );
        },
      ),
    );
  }

  /// The Replace sheet expects a full Exercise. Look it up in the catalog;
  /// if missing (e.g., it was already replaced), synthesize a stand-in with
  /// `chest` as a safe muscle filter so the sheet still shows alternatives.
  Exercise _resolveExerciseForReplace(SessionExercise ex) {
    final repo = getIt<ExerciseRepository>();
    final found = repo.getExerciseById(ex.exerciseId);
    if (found != null) return found;
    return Exercise(
      id: ex.exerciseId,
      name: ex.name,
      sets: ex.targetSets,
      reps: 10,
      weight: 0,
      muscleGroups: const [MuscleGroup.chest],
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
