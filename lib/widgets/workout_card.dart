import 'package:flutter/material.dart';
import '../models/workout.dart';
import '../theme/app_theme.dart';

class WorkoutCard extends StatelessWidget {
  final Workout workout;
  final bool isActive;

  const WorkoutCard({
    super.key,
    required this.workout,
    this.isActive = false,
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

    return Container(
      decoration: BoxDecoration(
        color: isActive
            ? const Color(0xFF3D2121)
            : AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(20),
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
              color: recoveryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: recoveryColor.withOpacity(0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: recoveryColor.withOpacity(0.3),
                  blurRadius: 12,
                  spreadRadius: 0,
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
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
    );
  }
}
