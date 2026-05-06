import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../models/exercise.dart';
import '../../models/session/session_exercise.dart';
import '../../models/session/session_set.dart';
import '../../models/session/workout_session.dart';
import '../../repositories/exercise_repository.dart';
import '../../core/service_locator.dart';
import '../../theme/app_theme.dart';
import '../../widgets/tap_scale.dart';
import 'bloc/workout_session_bloc.dart';
import 'bloc/workout_session_event.dart';
import 'bloc/workout_session_state.dart';
import 'widgets/action_chip_row.dart';
import 'widgets/add_set_button.dart';
import 'widgets/log_set_button.dart';
import 'widgets/notes_field.dart';
import 'widgets/pr_placeholder_header.dart';
import 'widgets/rest_timer_card.dart';
import 'widgets/set_row.dart';
import 'widgets/swipe_to_delete.dart';

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

class _LoggingView extends StatelessWidget {
  final String exerciseId;
  const _LoggingView({required this.exerciseId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WorkoutSessionBloc, WorkoutSessionState>(
      listenWhen: (prev, next) =>
          next is SessionActive &&
          (next).exerciseJustClosed &&
          (prev is! SessionActive || !prev.exerciseJustClosed),
      listener: (context, state) {
        if (state is SessionActive && state.exerciseJustClosed) {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      },
      builder: (context, state) {
        if (state is! SessionActive) {
          return const Scaffold(
            backgroundColor: AppTheme.backgroundColor,
            body: SizedBox.shrink(),
          );
        }
        final ex = state.session.exercises.firstWhere(
          (e) => e.exerciseId == exerciseId,
          orElse: () => throw StateError('Exercise $exerciseId not in session'),
        );
        return _LoggingScaffold(exercise: ex, session: state.session);
      },
    );
  }
}

class _LoggingScaffold extends StatelessWidget {
  final SessionExercise exercise;
  final WorkoutSession session;
  const _LoggingScaffold({required this.exercise, required this.session});

  @override
  Widget build(BuildContext context) {
    final allLogged = exercise.sets.isNotEmpty &&
        exercise.sets.every((s) => s.isLogged);
    final hasPendingSet = exercise.sets.any((s) => !s.isLogged);
    final isFinalSet = !allLogged && exercise.sets.length == 1
        ? false // single set: still 'Log Set' until logged
        : !hasPendingSet
            ? true
            : exercise.sets.where((s) => !s.isLogged).length == 1;

    final ghostReps = _resolveGhostReps(exercise);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const PrPlaceholderHeader(),
                ActionChipRow(
                  restSeconds: 120,
                  onRestTap: () => _toast(context, 'Rest timer comes online with logging'),
                  onInstructionTap: () =>
                      _toast(context, 'Instructions — coming in Part 2'),
                  onAnalyticsTap: () =>
                      _toast(context, 'Analytics — coming in Part 2'),
                ),
                const SizedBox(height: 16),
                _SectionLabel(text: 'WARMUP'),
                const SizedBox(height: 6),
                _Headers(),
                const SizedBox(height: 4),
                _buildWarmupRow(context, ghostReps),
                const SizedBox(height: 14),
                const Divider(
                  color: AppTheme.textSecondary,
                  height: 1,
                  thickness: 0.4,
                ),
                const SizedBox(height: 14),
                _SectionLabel(text: 'SET'),
                const SizedBox(height: 6),
                _Headers(),
                const SizedBox(height: 4),
                ..._buildSetRows(context, ghostReps),
                const SizedBox(height: 12),
                AddSetButton(
                  onTap: () => context
                      .read<WorkoutSessionBloc>()
                      .add(AddSet(exercise.exerciseId)),
                ),
                const SizedBox(height: 22),
                _SectionLabel(text: 'NOTES'),
                const SizedBox(height: 6),
                NotesField(
                  initialValue: exercise.notes,
                  onChanged: (s) => context.read<WorkoutSessionBloc>().add(
                        UpdateNotes(
                          exerciseId: exercise.exerciseId,
                          notes: s,
                        ),
                      ),
                ),
              ],
            ),
          ),
          if (session.activeRestEndsAt != null &&
              session.activeRestEndsAt!.isAfter(DateTime.now())) ...[
            RestTimerCard(
              endsAt: session.activeRestEndsAt!,
              totalSeconds: session.restDurationSeconds,
              onCompleted: () => context
                  .read<WorkoutSessionBloc>()
                  .add(const CancelRestTimer()),
              onCancel: () => context
                  .read<WorkoutSessionBloc>()
                  .add(const CancelRestTimer()),
            ),
            const SizedBox(height: 8),
          ],
          LogSetButton(
            enabled: _firstUnloggedFilled(exercise) ||
                (allLogged ? false : false),
            isFinalSet: isFinalSet,
            onTap: () => _onLogSetTap(context),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.backgroundColor,
      elevation: 0,
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: TapScale(
          scaleDown: 0.90,
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: AppTheme.cardBackground,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_back,
              color: AppTheme.recoveryGreen,
              size: 20,
            ),
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
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: TapScale(
            scaleDown: 0.85,
            onTap: () => _toast(context, 'Options — coming in Part 2'),
            child: const Icon(
              Icons.more_horiz,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarmupRow(BuildContext context, int? ghostReps) {
    final warmup = exercise.warmupSet;
    if (warmup == null) {
      return const SizedBox.shrink();
    }
    return SwipeToDelete(
      dismissKey: ValueKey('warmup_dismiss_${warmup.id}'),
      onDismissed: () => context.read<WorkoutSessionBloc>().add(
            DeleteSet(
              exerciseId: exercise.exerciseId,
              setId: warmup.id,
              isWarmup: true,
            ),
          ),
      child: SetRow(
        key: ValueKey('warmup_${warmup.id}'),
        marker: 'W',
        isWarmup: true,
        weight: warmup.weight,
        reps: warmup.reps,
        isLogged: warmup.isLogged,
        repsGhost: ghostReps?.toString(),
        onWeightChanged: (v) => context.read<WorkoutSessionBloc>().add(
              UpdateSetDraft(
                exerciseId: exercise.exerciseId,
                setId: warmup.id,
                weight: v,
                isWarmup: true,
                clearWeight: v == null,
              ),
            ),
        onRepsChanged: (v) => context.read<WorkoutSessionBloc>().add(
              UpdateSetDraft(
                exerciseId: exercise.exerciseId,
                setId: warmup.id,
                reps: v,
                isWarmup: true,
                clearReps: v == null,
              ),
            ),
      ),
    );
  }

  List<Widget> _buildSetRows(BuildContext context, int? ghostReps) {
    return [
      for (var i = 0; i < exercise.sets.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SwipeToDelete(
            dismissKey: ValueKey('set_dismiss_${exercise.sets[i].id}'),
            onDismissed: () => context.read<WorkoutSessionBloc>().add(
                  DeleteSet(
                    exerciseId: exercise.exerciseId,
                    setId: exercise.sets[i].id,
                  ),
                ),
            child: SetRow(
              key: ValueKey('set_${exercise.sets[i].id}'),
              marker: '${i + 1}',
              weight: exercise.sets[i].weight,
              reps: exercise.sets[i].reps,
              isLogged: exercise.sets[i].isLogged,
              repsGhost: ghostReps?.toString(),
              onWeightChanged: (v) => context.read<WorkoutSessionBloc>().add(
                    UpdateSetDraft(
                      exerciseId: exercise.exerciseId,
                      setId: exercise.sets[i].id,
                      weight: v,
                      clearWeight: v == null,
                    ),
                  ),
              onRepsChanged: (v) => context.read<WorkoutSessionBloc>().add(
                    UpdateSetDraft(
                      exerciseId: exercise.exerciseId,
                      setId: exercise.sets[i].id,
                      reps: v,
                      clearReps: v == null,
                    ),
                  ),
            ),
          ),
        ),
    ];
  }

  bool _firstUnloggedFilled(SessionExercise ex) {
    for (final s in ex.sets) {
      if (!s.isLogged) return s.isFilled;
    }
    return false;
  }

  void _onLogSetTap(BuildContext context) {
    final bloc = context.read<WorkoutSessionBloc>();
    SessionSet? target;
    for (final s in exercise.sets) {
      if (!s.isLogged) {
        target = s;
        break;
      }
    }
    if (target == null) return; // all logged: button shouldn't be enabled
    if (!target.isFilled) return;

    bloc.add(LogSet(
      exerciseId: exercise.exerciseId,
      setId: target.id,
      weight: target.weight!,
      reps: target.reps!,
    ));

    // If this was the last unlogged set, mark the exercise complete and pop.
    final remaining =
        exercise.sets.where((s) => !s.isLogged && s.id != target!.id).length;
    if (remaining == 0) {
      bloc.add(MarkExerciseDone(exercise.exerciseId));
    } else {
      bloc.add(const StartRestTimer(duration: Duration(seconds: 120)));
    }
  }

  /// Last-session ghost: with no history wired in Part 1, fall back to the
  /// original planned reps from the catalog. Returns null if the exercise
  /// isn't in the catalog (e.g., it was already replaced and we don't have
  /// `Exercise.reps` available — fine; ghost just stays empty).
  int? _resolveGhostReps(SessionExercise ex) {
    final repo = getIt<ExerciseRepository>();
    final Exercise? full = repo.getExerciseById(ex.exerciseId);
    return full?.reps;
  }

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.cardBackground,
        duration: const Duration(seconds: 1),
      ),
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
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 1.4,
      ),
    );
  }
}

class _Headers extends StatelessWidget {
  const _Headers();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        SizedBox(
          width: 22,
          child: Text(
            'SET',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'WEIGHT (lb)',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
        SizedBox(width: 24),
        Expanded(
          child: Text(
            'REPS',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.0,
            ),
          ),
        ),
        SizedBox(width: 32),
      ],
    );
  }
}
