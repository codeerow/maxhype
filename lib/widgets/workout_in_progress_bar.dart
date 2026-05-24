import 'dart:async';
import 'dart:ui';

import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../screens/workout_session/bloc/workout_session_bloc.dart';
import '../screens/workout_session/bloc/workout_session_state.dart';
import '../screens/workout_session/workout_session_screen.dart';
import '../theme/app_theme.dart';
import 'animations/animations.dart';
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
      buildWhen: (prev, next) =>
          (prev is SessionActive) != (next is SessionActive) ||
          (prev is SessionActive &&
              next is SessionActive &&
              prev.session.activeExerciseId != next.session.activeExerciseId),
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

class _ActiveBarState extends State<_ActiveBar>
    with SingleTickerProviderStateMixin {
  Timer? _ticker;

  /// Permanent slow-pulse controller — drives the subtle orange halo so the
  /// bar doesn't feel static. Looped via `repeat(reverse: true)`.
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  String _format(Duration d) {
    final total = d.inSeconds < 0 ? 0 : d.inSeconds;
    final mins = total ~/ 60;
    final secs = total % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  String _exerciseLabel(SessionActive s) {
    final ex = s.session.exercises.firstWhere(
      (e) => e.exerciseId == s.session.activeExerciseId,
      orElse: () => s.session.exercises.isNotEmpty
          ? s.session.exercises.first
          : throw StateError('Active session with no exercises'),
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
        child: PulseGlow(
          pulseController: _pulse,
          color: AppTheme.primaryOrange,
          baseAlpha: 0.18,
          pulseAlpha: 0.18,
          baseBlur: 14,
          pulseExtraBlur: 6,
          baseSpread: 0.5,
          pulseExtraSpread: 0.8,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            // ClipRRect renders the rounded corners cleanly (antialiased
            // path clip), so BackdropFilter doesn't bleed beyond the
            // radius and produce jagged edges. The 1-px orange border is
            // painted on top via foregroundDecoration so its stroke sits
            // exactly on the clipped edge.
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
                        // Dense, opaque-leaning fill so the page text
                        // behind the bar doesn't read through.
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
                    Text(
                      _format(DateTime.now().difference(session.startedAt)),
                      style: const TextStyle(
                        color: AppTheme.primaryOrange,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
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
    Navigator.of(context, rootNavigator: true).push(
      CupertinoPageRoute<void>(
        builder: (_) => WorkoutSessionScreen.restored(),
      ),
    );
  }
}
