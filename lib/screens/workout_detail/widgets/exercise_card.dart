import 'package:flutter/material.dart';
import '../../../models/exercise.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';
import 'mini_muscle_atlas.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onTap;
  final VoidCallback? onOptionsPressed;

  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.onOptionsPressed,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = '${exercise.sets} sets';

    final content = Row(
      children: [
        // Exercise image with muscle atlas overlay
        SizedBox(
          width: 70,
          height: 90,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 70,
                  height: 90,
                  color: AppTheme.cardBackground,
                  child: Center(
                    child: Text(
                      exercise.name[0],
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: MiniMuscleAtlas(muscleGroups: exercise.muscleGroups),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        // Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                exercise.name,
                style: Theme.of(context).textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // 3-dots button
        if (onOptionsPressed != null)
          TapScale(
            scaleDown: 0.90,
            onTap: onOptionsPressed,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Icon(Icons.more_horiz,
                    color: AppTheme.textSecondary, size: 18),
              ),
            ),
          ),
      ],
    );

    if (onTap != null) {
      return TapScale(
        scaleDown: 0.97,
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}
