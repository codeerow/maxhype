import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// Floating bottom Finish button styled to mirror the "Start Workout" button
/// on the Workout Detail screen — same shape, same shadow, same TapScale —
/// but in destructive red.
class SessionFinishButton extends StatelessWidget {
  final VoidCallback onTap;

  const SessionFinishButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scaleDown: 0.96,
      enableHaptic: true,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.recoveryRed,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: AppTheme.recoveryRed.withValues(alpha: 0.5),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Finish',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
