import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/exercise.dart';
import '../../../widgets/tap_scale.dart';

class ExerciseOptionsSheet extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onReplaceExercise;

  const ExerciseOptionsSheet({
    super.key,
    required this.exercise,
    required this.onReplaceExercise,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TapScale(
                    scaleDown: 0.90,
                    onTap: () => Navigator.of(context).pop(),
                    child: const Icon(
                      Icons.close,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(
              color: AppTheme.textSecondary,
              height: 1,
              thickness: 0.5,
            ),
            // Options
            _buildOption(
              context,
              icon: Icons.swap_horiz,
              title: 'Replace exercise',
              onTap: () {
                Navigator.of(context).pop();
                onReplaceExercise();
              },
            ),
            _buildOption(
              context,
              icon: Icons.favorite_border,
              title: 'Favorite for this routine',
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Favorite - Coming soon!'),
                    backgroundColor: AppTheme.primaryOrange,
                  ),
                );
              },
            ),
            _buildOption(
              context,
              icon: Icons.block,
              title: 'Exclude from generation',
              textColor: AppTheme.recoveryRed,
              onTap: () {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Exclude - Coming soon!'),
                    backgroundColor: AppTheme.recoveryRed,
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return TapScale(
      scaleDown: 0.98,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: textColor ?? AppTheme.textPrimary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: textColor,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
