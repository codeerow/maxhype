import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/workout.dart';
import '../theme/app_theme.dart';
import '../screens/workout_detail/workout_detail_screen.dart';
import '../screens/workout_session/bloc/workout_session_bloc.dart';
import '../screens/workout_session/bloc/workout_session_state.dart';
import '../screens/workout_session/workout_session_screen.dart';
import 'tap_scale.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;

  const WorkoutCard({
    super.key,
    required this.workout,
  });

  Color _getRecoveryColor() {
    switch (workout.recoveryInfo.status) {
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
            s is SessionActive && s.session.workoutId == workout.id;
        return isMine(prev) != isMine(next);
      },
      builder: (context, state) {
        final inProgress =
            state is SessionActive && state.session.workoutId == workout.id;

        return TapScale(
          enableHaptic: true,
          onTap: () => _handleTap(context, inProgress),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: inProgress
                        ? AppTheme.recoveryGreen
                        : AppTheme.primaryOrange,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      workout.title,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      workout.subtitle,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${workout.duration} - ${workout.exerciseCount} exercises',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      decoration: BoxDecoration(
                        color: recoveryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: recoveryColor.withValues(alpha: 0.5),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: recoveryColor.withValues(alpha: 0.3),
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
                                workout.recoveryInfo.statusText,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: recoveryColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                workout.recoveryInfo.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontSize: 11,
                                      color: recoveryColor,
                                    ),
                              ),
                            ],
                          ),
                          Text(
                            '${workout.recoveryInfo.percentage.toInt()}%',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: recoveryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (inProgress)
                const Positioned(
                  top: 12,
                  right: 12,
                  child: _InProgressBadge(),
                ),
            ],
          ),
        );
      },
    );
  }

  void _handleTap(BuildContext context, bool inProgress) {
    Navigator.of(context).push(
      CupertinoPageRoute<void>(
        builder: (_) => inProgress
            ? WorkoutSessionScreen.restored()
            : WorkoutDetailScreen(workout: workout),
      ),
    );
  }
}

class _InProgressBadge extends StatelessWidget {
  const _InProgressBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppTheme.primaryOrange.withValues(alpha: 0.6),
          width: 1,
        ),
      ),
      child: const Text(
        'IN PROGRESS',
        style: TextStyle(
          color: AppTheme.primaryOrange,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}
