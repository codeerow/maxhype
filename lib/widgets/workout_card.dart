import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/workout.dart';
import '../models/workout_completion.dart';
import '../theme/app_theme.dart';
import '../screens/workout_detail/workout_detail_screen.dart';
import '../screens/workout_session/bloc/workout_session_bloc.dart';
import '../screens/workout_session/bloc/workout_session_state.dart';
import '../screens/workout_session/workout_session_screen.dart';
import 'app_toast.dart';
import 'tap_scale.dart';

/// Tri-state home workout card (milestone Phase 3 Part 3, Item 1):
///
///   - Ready — the existing recovery layout with the orange border.
///   - In Progress — solid-orange "IN PROGRESS" badge in the corner.
///   - Completed (this ISO week) — orange checkmark + "Completed · N mins"
///     line in place of the recovery block.
///
/// When a completion lands fresh (the user just finished the workout
/// and the carousel just slid onto this card), the border and the
/// Completed footer pulse for a moment to make the new state pop. The
/// pulse is one-shot; the card settles back into a steady completed
/// look once it finishes.
class WorkoutCard extends StatefulWidget {
  final Workout workout;

  /// Latest completion record for this workout if it sits inside the
  /// current ISO week (clarification 1.2). null in every other case —
  /// no recent completion, or the user is mid-session on this workout.
  final WorkoutCompletion? completionThisWeek;

  const WorkoutCard({
    super.key,
    required this.workout,
    this.completionThisWeek,
  });

  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

/// Process-wide record of workoutIds whose latest completion has
/// already been pulsed. Survives card mount/unmount cycles (e.g., the
/// ListView.builder recycles cards as they scroll in and out of
/// viewport) and survives the second rebuild HomeBloc fires when its
/// RefreshCompletions arrives. Once the user kills the app, this is
/// gone — the next finish in a new session gets its pulse.
final Set<String> _pulsedWorkoutIds = <String>{};

class _WorkoutCardState extends State<WorkoutCard>
    with SingleTickerProviderStateMixin {
  /// Drives the one-shot post-completion pulse. Parks at 1.0 once the
  /// cycle finishes — that's the steady-state Completed look.
  late final AnimationController _pulse;

  /// One pulse cycle, sized to fit inside the carousel's 800-ms hold
  /// on the finished card so the pulse completes just as the
  /// carousel starts sliding on to the next workout.
  static const _pulseCycleDuration = Duration(milliseconds: 720);

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: _pulseCycleDuration,
      value: 1.0,
    );
    _maybeFireFreshPulse(widget.completionThisWeek);
  }

  @override
  void didUpdateWidget(WorkoutCard old) {
    super.didUpdateWidget(old);
    _maybeFireFreshPulse(widget.completionThisWeek);
  }

  /// Trigger the pulse cycle when [completion] is *fresh* (within a
  /// few seconds of now) and this workoutId hasn't been pulsed in
  /// this app session yet. Returning to the home tab, scrolling the
  /// card off-screen and back, or HomeBloc re-emitting after
  /// RefreshCompletions all rebuild the card — without the
  /// process-wide guard each of those would replay the pulse.
  void _maybeFireFreshPulse(WorkoutCompletion? completion) {
    if (completion == null) {
      // No completion in the current ISO week — drop the workout from
      // the "already pulsed" set so the *next* finish (could be later
      // today, could be next week) gets its pulse.
      _pulsedWorkoutIds.remove(widget.workout.id);
      _pulse.value = 1.0;
      return;
    }
    if (_pulsedWorkoutIds.contains(widget.workout.id)) {
      _pulse.value = 1.0;
      return;
    }
    final age = DateTime.now().difference(completion.completedAt);
    if (age.inSeconds > 5) {
      // Completion arrived via initial load on a fresh app launch,
      // not a live finish. Mark as already-pulsed so a later
      // RefreshCompletions doesn't fire one.
      _pulsedWorkoutIds.add(widget.workout.id);
      _pulse.value = 1.0;
      return;
    }
    _pulsedWorkoutIds.add(widget.workout.id);
    _runPulseCycle();
  }

  Future<void> _runPulseCycle() async {
    if (!mounted) return;
    await _pulse.forward(from: 0.0);
    if (mounted) _pulse.value = 1.0;
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Color _getRecoveryColor() {
    switch (widget.workout.recoveryInfo.status) {
      case RecoveryStatus.ready:
        return AppTheme.recoveryGreen;
      case RecoveryStatus.almostReady:
        return AppTheme.recoveryYellow;
      case RecoveryStatus.notReady:
        return AppTheme.recoveryRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    final recoveryColor = _getRecoveryColor();

    return BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
      buildWhen: (prev, next) {
        bool isMine(WorkoutSessionState s) =>
            s is SessionActive && s.session.workoutId == widget.workout.id;
        return isMine(prev) != isMine(next);
      },
      builder: (context, state) {
        final inProgress = state is SessionActive &&
            state.session.workoutId == widget.workout.id;
        // In-progress wins over completed when both could apply — a
        // workout being actively logged shouldn't read as "done".
        final isCompletedThisWeek =
            !inProgress && widget.completionThisWeek != null;

        return TapScale(
          enableHaptic: true,
          onTap: () => _handleTap(context, inProgress),
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) {
              // pulseT goes 0→1 several times then parks at 1.0.
              // brightness goes 0..0.55 so the bright moment sits a
              // little before the cycle peak (sin curve), giving a
              // breath-like rise-and-fall rather than a hard flash.
              final t = isCompletedThisWeek ? _pulse.value : 1.0;
              final pulseStrength = isCompletedThisWeek
                  ? (1.0 - (2 * t - 1).abs()).clamp(0.0, 1.0)
                  : 0.0;
              return _buildCard(
                context: context,
                child: child!,
                inProgress: inProgress,
                isCompletedThisWeek: isCompletedThisWeek,
                recoveryColor: recoveryColor,
                pulseStrength: pulseStrength,
              );
            },
            child: Column(
              // Anchor the card's content block toward the bottom of
              // the fixed-height (220) card, matching the web prototype
              // layout the customer linked. The Spacer above the title
              // pushes the whole text group down, giving the card the
              // "premium / lower-balanced" feel they asked for.
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  widget.workout.title,
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                // Completed cards get a weekday line directly under the
                // title — orange, bold — same as the web app.
                if (isCompletedThisWeek &&
                    widget.completionThisWeek != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _weekdayLabel(widget.completionThisWeek!.completedAt),
                    style: const TextStyle(
                      color: AppTheme.primaryOrange,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  widget.workout.subtitle,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  '${widget.workout.duration} - ${widget.workout.exerciseCount} exercises',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                if (isCompletedThisWeek)
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final t = _pulse.value;
                      final pulseStrength =
                          (1.0 - (2 * t - 1).abs()).clamp(0.0, 1.0);
                      return _CompletedFooter(
                        completion: widget.completionThisWeek!,
                        pulseStrength: pulseStrength,
                      );
                    },
                  )
                else
                  _RecoveryFooter(
                    info: widget.workout.recoveryInfo,
                    color: recoveryColor,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({
    required BuildContext context,
    required Widget child,
    required bool inProgress,
    required bool isCompletedThisWeek,
    required Color recoveryColor,
    required double pulseStrength,
  }) {
    final orange = AppTheme.primaryOrange;
    final borderColor = inProgress
        ? AppTheme.recoveryGreen
        : isCompletedThisWeek
            ? Color.lerp(orange, Colors.white, 0.18 * pulseStrength)!
            : orange;
    final borderWidth = isCompletedThisWeek ? 2.0 + (1.5 * pulseStrength) : 2.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: borderWidth,
            ),
            boxShadow: isCompletedThisWeek && pulseStrength > 0
                ? [
                    BoxShadow(
                      color: orange.withValues(
                        alpha: 0.35 * pulseStrength,
                      ),
                      blurRadius: 20 + 18 * pulseStrength,
                      spreadRadius: 1.5 * pulseStrength,
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(20),
          child: child,
        ),
        if (inProgress)
          const Positioned(
            top: 12,
            right: 12,
            child: _InProgressBadge(),
          ),
      ],
    );
  }

  void _handleTap(BuildContext context, bool inProgress) {
    // One-active-workout rule: when another workout is active, block
    // navigation at the card-tap level instead of letting the user
    // browse into a second workout and bouncing them at the Start
    // button (customer feedback — the previous flow let the user
    // wander into Workout B's exercise list before the blocker fired).
    final sessionState = context.read<WorkoutSessionBloc>().state;
    if (sessionState is SessionActive &&
        sessionState.session.workoutId != widget.workout.id) {
      AppToast.showPremium(
        context,
        'Finish your current workout first',
        accent: AppTheme.primaryOrange,
        bottomOffset: 64,
      );
      return;
    }
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => inProgress
            ? WorkoutSessionScreen.restored()
            : WorkoutDetailScreen(workout: widget.workout),
      ),
    );
  }
}

class _RecoveryFooter extends StatelessWidget {
  final RecoveryInfo info;
  final Color color;

  const _RecoveryFooter({required this.info, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                info.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: color,
                    ),
              ),
            ],
          ),
          Text(
            '${info.percentage.toInt()}%',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// "✓ Completed · 17 mins" inline footer with an orange checkmark,
/// replacing the recovery block on workout cards finished this ISO
/// week. Customer-requested compact variant — no bordered pill, no
/// fill, just an inline row. The [pulseStrength] (0..1) brightens the
/// icon + text colour for the post-completion pulse cycle.
class _CompletedFooter extends StatelessWidget {
  final WorkoutCompletion completion;
  final double pulseStrength;

  const _CompletedFooter({
    required this.completion,
    this.pulseStrength = 0.0,
  });

  String _formatDuration(int seconds) {
    final mins = (seconds / 60).round();
    final clamped = mins < 1 ? 1 : mins;
    return clamped == 1 ? '1 min' : '$clamped mins';
  }

  @override
  Widget build(BuildContext context) {
    final orange = AppTheme.primaryOrange;
    final brightOrange =
        Color.lerp(orange, Colors.white, 0.25 * pulseStrength)!;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle, color: brightOrange, size: 18),
        const SizedBox(width: 8),
        Text(
          'Completed',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: brightOrange,
            letterSpacing: 0.3,
          ),
        ),
        Text(
          ' · ${_formatDuration(completion.durationSeconds)}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// English weekday name (Monday … Sunday) — used as the orange line
/// under the title on a completed card, mirroring the web prototype.
String _weekdayLabel(DateTime instant) {
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  // DateTime.weekday is 1..7 (Mon..Sun) — perfect 0-indexed lookup.
  return names[instant.weekday - 1];
}

class _InProgressBadge extends StatelessWidget {
  const _InProgressBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange,
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'IN PROGRESS',
        style: TextStyle(
          color: Colors.black,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
