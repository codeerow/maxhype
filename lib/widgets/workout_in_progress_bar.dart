import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../screens/workout_session/bloc/workout_session_bloc.dart';
import '../screens/workout_session/bloc/workout_session_state.dart';
import '../screens/workout_session/in_progress_bar_routing.dart';
import '../screens/workout_session/workout_session_screen.dart';
import '../theme/app_theme.dart';
import 'tap_scale.dart';

/// Sticky bar visible across the rest of the app while a workout session
/// is active. Shows the current exercise + elapsed time and routes to the
/// session screen on tap. Naturally hidden whenever the session screen is
/// already on top of the navigator stack — it's hosted in MainScaffold,
/// so when the session screen pushes over MainScaffold, this widget is
/// no longer in the visible tree.
class WorkoutInProgressBar extends StatelessWidget {
  const WorkoutInProgressBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<WorkoutSessionBloc, WorkoutSessionState>(
      buildWhen: (prev, next) {
        if ((prev is SessionActive) != (next is SessionActive)) return true;
        if (prev is SessionActive && next is SessionActive) {
          // Rebuild whenever the would-be resume target changes — covers
          // both `activeExerciseId` flipping and the first incomplete
          // exercise shifting after the previous one is marked done.
          return resumeTargetExerciseId(prev.session) !=
              resumeTargetExerciseId(next.session);
        }
        return false;
      },
      builder: (context, state) {
        if (state is! SessionActive) return const SizedBox.shrink();
        return _ActiveBar(state: state);
      },
    );
  }
}

class _ActiveBar extends StatefulWidget {
  final SessionActive state;
  const _ActiveBar({required this.state});

  @override
  State<_ActiveBar> createState() => _ActiveBarState();
}

class _ActiveBarState extends State<_ActiveBar> {
  /// One-second ticker stream — rebuilds the bar so the elapsed-time
  /// label stays current. Stream-based so a StreamBuilder owns the
  /// subscription: when the bar is offscreen (another route pushed on
  /// top) the StreamBuilder is detached and the listener disappears,
  /// avoiding the "wrong build scope" assertion that an instance-level
  /// Timer.periodic + setState would cause during route transitions.
  late final Stream<DateTime> _ticks;

  @override
  void initState() {
    super.initState();
    _ticks = Stream<DateTime>.periodic(
      const Duration(seconds: 1),
      (_) => DateTime.now(),
    );
  }

  String _format(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final mins = total ~/ 60;
    final secs = total % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  /// Name shown on the bar. When [resumeTargetExerciseId] resolves to
  /// an active exercise, we surface its name so the bar reads as a
  /// shortcut to that exact row. With no active exercise (fresh
  /// session, or right after the user hit Done), we fall back to the
  /// workout title — the tap will land them on the exercise list to
  /// pick what to do next.
  String _exerciseLabel(SessionActive s) {
    final targetSlotId = resumeTargetExerciseId(s.session);
    if (targetSlotId == null) return s.session.workoutName;
    final ex = s.session.exercises.firstWhere(
      (e) => e.slotId == targetSlotId,
      orElse: () => s.session.exercises.first,
    );
    return ex.name;
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.state.session;
    final hasExercises = session.exercises.isNotEmpty;
    final label = hasExercises ? _exerciseLabel(widget.state) : session.workoutName;

    return SafeArea(
      top: false,
      child: TapScale(
        scaleDown: 0.97,
        enableHaptic: true,
        onTap: () => _resume(context),
        child: Padding(
          // Bottom padding hugs the home-bar — keeps a minimal gap so
          // the orange halo doesn't bleed into the nav, but no large
          // dead space between the bar and the tab row.
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
          // Static orange halo via boxShadow — no AnimationController
          // means the bar can't mark itself dirty while another route
          // is mid-transition on top of MainScaffold.
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryOrange.withValues(alpha: 0.28),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  foregroundDecoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.primaryOrange.withValues(alpha: 0.55),
                      width: 1,
                    ),
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        AppTheme.primaryOrange.withValues(alpha: 0.32),
                        AppTheme.cardBackground.withValues(alpha: 0.94),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'WORKOUT IN PROGRESS',
                              style: TextStyle(
                                color: AppTheme.primaryOrange,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppTheme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      StreamBuilder<DateTime>(
                        stream: _ticks,
                        builder: (context, snapshot) {
                          final now = snapshot.data ?? DateTime.now();
                          return Text(
                            _format(now.difference(session.startedAt)),
                            style: const TextStyle(
                              color: AppTheme.primaryOrange,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _resume(BuildContext context) {
    // Brief §5 — tapping the bar must drop the user into the logging
    // screen for the exercise they were last on. We push the session
    // screen first (so the back stack ends up at the exercise list,
    // per clarification 5.14), and the session screen itself stacks
    // the logging screen on top of it.
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => WorkoutSessionScreen.restoredAndOpenActive(),
      ),
    );
  }
}
