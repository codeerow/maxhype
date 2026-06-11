import 'package:flutter/material.dart';

import '../../../models/equipment_type.dart';
import '../../../models/exercise.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// Compact tile used by the Replace Exercise sheet.
///
/// Visually distinct from [ExerciseCard]:
///  * smaller thumbnail (44×56) so ~10 tiles fit per screen,
///  * subtitle is the equipment label (sets count is irrelevant for picking
///    a swap),
///  * no muscle-atlas badge — the sheet already filters by muscle group,
///    so the badge would be redundant noise,
///  * no overflow `···` menu — tapping the tile selects the swap.
///
/// If Replace evolves further (e.g., favorite/popular bookmarks, rating,
/// category chips), additions land here without touching the workout-detail
/// or session cards.
class ReplaceExerciseTile extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const ReplaceExerciseTile({
    super.key,
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scaleDown: TapScalePreset.surface.scale,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 44,
                height: 56,
                color: AppTheme.cardBackground,
                alignment: Alignment.center,
                child: Text(
                  exercise.name.isNotEmpty ? exercise.name[0] : '?',
                  style: const TextStyle(
                    color: AppTheme.primaryOrange,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    exercise.equipmentType.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
