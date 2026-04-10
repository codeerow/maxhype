import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WorkoutProgressBar extends StatelessWidget {
  final double progress;

  const WorkoutProgressBar({
    super.key,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: progress,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.textSecondary,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}
