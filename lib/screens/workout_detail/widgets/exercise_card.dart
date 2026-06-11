import 'package:flutter/material.dart';
import '../../../models/exercise.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';
import 'mini_muscle_atlas.dart';

/// Exercise card used by the Workout Detail screen and (wrapped) by the
/// Session main screen. Compact variants for other surfaces (e.g., the
/// Replace sheet) live in their own widgets — see [ReplaceExerciseTile].
class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback? onTap;
  final VoidCallback? onOptionsPressed;

  /// Subtitle override. If null, falls back to "{N} sets". The session
  /// screen passes its own session-aware string here ("{N} sets · {M} done
  /// · {Equipment}").
  final String? subtitleOverride;

  /// Optional widget rendered in the bottom-left of the card, before the
  /// thumbnail. The session card uses this slot for a vertical
  /// active-accent bar / completion checkmark without duplicating layout.
  final Widget? leadingAccent;

  /// When true, renders the persistent "PERSONAL RECORD" pill above the
  /// title. The title stays vertically centred relative to the thumbnail
  /// — the pill sits in the whitespace above it without shifting layout.
  final bool isPrAchieved;

  const ExerciseCard({
    super.key,
    required this.exercise,
    this.onTap,
    this.onOptionsPressed,
    this.subtitleOverride,
    this.leadingAccent,
    this.isPrAchieved = false,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = subtitleOverride ?? '${exercise.sets} sets';

    final content = Row(
      children: [
        if (leadingAccent != null) ...[
          leadingAccent!,
          const SizedBox(width: 8),
        ],
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
        // One stack, fixed to the 90px thumbnail height. Title is always
        // centered; PR pill is anchored to the top of the same column so
        // it sits in the whitespace above the title without shifting it.
        Expanded(
          child: SizedBox(
            height: 90,
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
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
                if (isPrAchieved)
                  const Positioned(
                    left: 0,
                    top: 0,
                    child: _PrCardPill(),
                  ),
              ],
            ),
          ),
        ),
        // 3-dots button
        if (onOptionsPressed != null)
          TapScale(
            scaleDown: TapScalePreset.icon.scale,
            onTap: onOptionsPressed,
            child: const SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: Icon(Icons.more_horiz,
                    color: AppTheme.primaryOrange, size: 18),
              ),
            ),
          ),
      ],
    );

    if (onTap != null) {
      return TapScale(
        scaleDown: TapScalePreset.surface.scale,
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

/// Compact persistent PR pill rendered above the exercise title when the
/// user has set a personal record for the exercise during the current
/// session.
class _PrCardPill extends StatelessWidget {
  const _PrCardPill();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.primaryOrange.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: AppTheme.primaryOrange.withValues(alpha: 0.55),
          width: 1,
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('🔥', style: TextStyle(fontSize: 11)),
          SizedBox(width: 6),
          Text(
            'PERSONAL RECORD',
            style: TextStyle(
              color: AppTheme.primaryOrange,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(width: 6),
          Text('🔥', style: TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}
