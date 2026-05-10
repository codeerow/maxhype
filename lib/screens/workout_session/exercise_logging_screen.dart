import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../core/service_locator.dart';
import '../../models/exercise.dart';
import '../../models/session/session_exercise.dart';
import '../../models/session/session_set.dart';
import '../../models/session/workout_session.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/workout_session_repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/tap_scale.dart';
import 'bloc/workout_session_bloc.dart';
import 'bloc/workout_session_event.dart';
import 'bloc/workout_session_state.dart';
import 'widgets/action_chip_row.dart';
import 'widgets/add_set_button.dart';
import 'widgets/effective_set_row.dart';
import 'widgets/log_set_button.dart';
import 'widgets/notes_card.dart';
import 'widgets/pr_placeholder_header.dart';
import 'widgets/rest_timer_card.dart';
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

class _LoggingView extends StatefulWidget {
  final String exerciseId;
  const _LoggingView({required this.exerciseId});

  @override
  State<_LoggingView> createState() => _LoggingViewState();
}

class _LoggingViewState extends State<_LoggingView> {
  late final Future<SessionSet?> _historyFuture;

  /// Stable FocusNodes for REPS fields keyed by set id (or 'warmup'). Lets
  /// the Log Set / Done IME action programmatically jump focus to the next
  /// set's REPS field after the previous one is logged.
  final Map<String, FocusNode> _repsFocusNodes = {};

  FocusNode _repsFocusFor(String key) =>
      _repsFocusNodes.putIfAbsent(key, () => FocusNode());

  @override
  void initState() {
    super.initState();
    _historyFuture =
        getIt<WorkoutSessionRepository>().lastLogFor(widget.exerciseId);
  }

  @override
  void dispose() {
    for (final n in _repsFocusNodes.values) {
      n.dispose();
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
            );
          },
        );
      },
    );
  }
}

class _LoggingScaffold extends StatelessWidget {
  final SessionExercise exercise;
  final WorkoutSession session;
  final SessionSet? historyLastLog;
  final FocusNode Function(String key) repsFocusFor;

  const _LoggingScaffold({
    required this.exercise,
    required this.session,
    required this.historyLastLog,
    required this.repsFocusFor,
  });

  @override
  Widget build(BuildContext context) {
    // "Final" = the next tap on Log Set will mark the whole exercise done.
    // That's the case when there's exactly one non-logged effective set left
    // AND the warmup is either absent or already logged (warmup never
    // completes the exercise on its own).
    final pendingEffective =
        exercise.sets.where((s) => !s.isLogged).length;
    final warmupPending =
        exercise.warmupSet != null && !exercise.warmupSet!.isLogged;
    final isFinalSet = !warmupPending && pendingEffective == 1;

    final prefill = _resolvePrefill(exercise);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      resizeToAvoidBottomInset: true,
      appBar: _buildAppBar(context),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              // Vertical-only padding: edge-to-edge horizontally lets the
              // swipe-to-delete background bleed off the screen edge instead
              // of being clipped at the row content's margin. Non-Dismissible
              // items wear their own horizontal padding via _Hp.
              padding: const EdgeInsets.fromLTRB(0, 8, 0, 24),
              children: [
                const _Hp(child: PrPlaceholderHeader()),
                ActionChipRow(
                  restSeconds: 120,
                  onRestTap: () =>
                      _toast(context, 'Rest timer comes online with logging'),
                  onInstructionTap: () =>
                      _toast(context, 'Instructions — coming in Part 2'),
                  onAnalyticsTap: () =>
                      _toast(context, 'Analytics — coming in Part 2'),
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
                ..._buildSetRows(context, prefill),
                const SizedBox(height: 8),
                _Hp(
                  child: AddSetButton(
                    onTap: () => context
                        .read<WorkoutSessionBloc>()
                        .add(AddSet(exercise.exerciseId)),
                  ),
                ),
                const SizedBox(height: 22),
                _Hp(
                  child: NotesCard(
                    initialValue: exercise.notes,
                    onChanged: (s) => context.read<WorkoutSessionBloc>().add(
                          UpdateNotes(
                            exerciseId: exercise.exerciseId,
                            notes: s,
                          ),
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
              onAdjust: (delta) => context
                  .read<WorkoutSessionBloc>()
                  .add(AdjustRestTimer(delta)),
            ),
            const SizedBox(height: 8),
          ],
          LogSetButton(
            enabled: _firstUnloggedFilled(exercise),
            isFinalSet: isFinalSet,
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
    return SwipeToDelete(
      dismissKey: ValueKey('warmup_dismiss_${warmup.id}'),
      borderRadius: BorderRadius.zero,
      onDismissed: () => context.read<WorkoutSessionBloc>().add(
            DeleteSet(
              exerciseId: exercise.exerciseId,
              setId: warmup.id,
              isWarmup: true,
            ),
          ),
      // Dismissible itself spans edge-to-edge so the red background and the
      // delete icon swipe in from the screen edge; pills sit at 16px inset.
      child: _Hp(
        child: EffectiveSetRow(
          key: ValueKey('warmup_${warmup.id}'),
          marker: 'W',
          isWarmup: true,
          weight: warmup.weight,
          reps: warmup.reps,
          isLogged: warmup.isLogged,
          isCurrent: !warmup.isLogged,
          prefillWeight: prefill.weight,
          prefillReps: prefill.reps,
          repsFocusNode: repsFocusFor('warmup'),
          onSubmitted: () => _onLogSetTap(context),
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
      ),
    );
  }

  List<Widget> _buildSetRows(BuildContext context, _Prefill prefill) {
    // The "current" effective set is the first non-logged one — but only if
    // warmup is already done. While warmup is pending, it owns the current
    // state and effective sets stay dark.
    final warmupPending =
        exercise.warmupSet != null && !exercise.warmupSet!.isLogged;
    int? currentIndex;
    if (!warmupPending) {
      for (var i = 0; i < exercise.sets.length; i++) {
        if (!exercise.sets[i].isLogged) {
          currentIndex = i;
          break;
        }
      }
    }
    return [
      for (var i = 0; i < exercise.sets.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: SwipeToDelete(
            dismissKey: ValueKey('set_dismiss_${exercise.sets[i].id}'),
            borderRadius: BorderRadius.zero,
            onDismissed: () => context.read<WorkoutSessionBloc>().add(
                  DeleteSet(
                    exerciseId: exercise.exerciseId,
                    setId: exercise.sets[i].id,
                  ),
                ),
            child: _Hp(
              child: EffectiveSetRow(
                key: ValueKey('set_${exercise.sets[i].id}'),
                marker: '${i + 1}',
                weight: exercise.sets[i].weight,
                reps: exercise.sets[i].reps,
                isLogged: exercise.sets[i].isLogged,
                isCurrent: currentIndex == i,
                prefillWeight: prefill.weight,
                prefillReps: prefill.reps,
                repsFocusNode: repsFocusFor(exercise.sets[i].id),
                onSubmitted: () => _onLogSetTap(context),
                onWeightChanged: (v) =>
                    context.read<WorkoutSessionBloc>().add(
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
        ),
    ];
  }

  /// The set that the Log Set / Done button currently targets — warmup if
  /// it's still pending, otherwise the first non-logged effective set.
  SessionSet? _currentTarget(SessionExercise ex) {
    final w = ex.warmupSet;
    if (w != null && !w.isLogged) return w;
    for (final s in ex.sets) {
      if (!s.isLogged) return s;
    }
    return null;
  }

  bool _isWarmupTarget(SessionExercise ex) {
    final w = ex.warmupSet;
    return w != null && !w.isLogged;
  }

  bool _firstUnloggedFilled(SessionExercise ex) {
    final t = _currentTarget(ex);
    return t?.isFilled ?? false;
  }

  void _onLogSetTap(BuildContext context) {
    final bloc = context.read<WorkoutSessionBloc>();
    final target = _currentTarget(exercise);
    if (target == null) return;
    if (!target.isFilled) return;

    final isWarmup = _isWarmupTarget(exercise);
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
      bloc.add(const StartRestTimer(duration: Duration(seconds: 120)));
      // Warmup just logged → focus first effective set's REPS.
      if (remainingEffective.isNotEmpty) {
        _focusReps(context, remainingEffective.first.id);
      }
      return;
    }

    if (remainingEffective.isEmpty) {
      bloc.add(MarkExerciseDone(exercise.exerciseId));
    } else {
      bloc.add(const StartRestTimer(duration: Duration(seconds: 120)));
      _focusReps(context, remainingEffective.first.id);
    }
  }

  /// Move focus to the REPS field of [setId] on the next frame so the
  /// system keyboard stays visible and the user can immediately type.
  void _focusReps(BuildContext context, String setId) {
    final node = repsFocusFor(setId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!node.canRequestFocus) return;
      node.requestFocus();
    });
  }

  /// Pre-fill order:
  ///   1. Last logged set in *this* session (so set #2 picks up set #1).
  ///   2. Last logged set from history (previous finished session).
  ///   3. Catalog plan (Exercise.weight / Exercise.reps).
  _Prefill _resolvePrefill(SessionExercise ex) {
    SessionSet? lastInSession;
    for (final s in ex.sets) {
      if (s.isLogged) lastInSession = s;
    }
    if (lastInSession != null) {
      return _Prefill(
        weight: lastInSession.weight,
        reps: lastInSession.reps,
      );
    }
    if (historyLastLog != null) {
      return _Prefill(
        weight: historyLastLog!.weight,
        reps: historyLastLog!.reps,
      );
    }
    final repo = getIt<ExerciseRepository>();
    final Exercise? plan = repo.getExerciseById(ex.exerciseId);
    return _Prefill(weight: plan?.weight, reps: plan?.reps);
  }

  void _toast(BuildContext context, String msg) {
    AppToast.show(context, msg);
  }
}

class _Prefill {
  final double? weight;
  final int? reps;
  const _Prefill({this.weight, this.reps});
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
    return Row(
      children: const [
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
