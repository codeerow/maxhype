import 'package:flutter/material.dart';
import '../../../models/exercise.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';
import 'mini_muscle_atlas.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onTap;
  final VoidCallback? onOptionsPressed;

  /// Compact density used by the Replace sheet so ~10 items fit on screen
  /// instead of ~6. Shrinks the thumbnail and tightens the typography while
  /// keeping the layout otherwise identical.
  final bool compact;

  /// Optional subtitle override. If null, falls back to "{N} sets" derived
  /// from the exercise's planned sets count. The session screen passes a
  /// session-aware string here ("{N} sets · {M} done · {Equipment}").
  final String? subtitleOverride;

  /// Optional widget to render in the bottom-left of the card, between the
  /// thumbnail and content. Used by the session card to show a vertical
  /// active-accent bar / completion checkmark without duplicating layout.
  final Widget? leadingAccent;

  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.onOptionsPressed,
    this.compact = false,
    this.subtitleOverride,
    this.leadingAccent,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = subtitleOverride ?? '${exercise.sets} sets';

    final thumbWidth = compact ? 44.0 : 70.0;
    final thumbHeight = compact ? 56.0 : 90.0;
    final initialFontSize = compact ? 22.0 : 36.0;
    final atlasShown = !compact;

    final content = Row(
      children: [
        if (leadingAccent != null) ...[
          leadingAccent!,
          const SizedBox(width: 8),
        ],
        // Exercise image with muscle atlas overlay
        SizedBox(
          width: thumbWidth,
          height: thumbHeight,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 8 : 12),
                child: Container(
                  width: thumbWidth,
                  height: thumbHeight,
                  color: AppTheme.cardBackground,
                  child: Center(
                    child: Text(
                      exercise.name[0],
                      style: TextStyle(
                        fontSize: initialFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryOrange,
                      ),
                    ),
                  ),
                ),
              ),
              if (atlasShown)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: MiniMuscleAtlas(muscleGroups: exercise.muscleGroups),
                ),
            ],
          ),
        ),
        SizedBox(width: compact ? 10 : 12),
        // Text
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                exercise.name,
                style: compact
                    ? const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      )
                    : Theme.of(context).textTheme.headlineSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: compact ? 1 : 2),
              Text(
                subtitle,
                style: compact
                    ? const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      )
                    : Theme.of(context).textTheme.bodyMedium,
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
