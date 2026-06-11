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
      scaleDown: TapScalePreset.cta.scale,
      enableHaptic: true,
      onTap: onTap,
      child: Container(
        width: 220,
        height: 52,
        decoration: BoxDecoration(
          color: AppTheme.recoveryRed,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppTheme.recoveryRed.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        alignment: Alignment.center,
        child: const Text(
          'Finish',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
