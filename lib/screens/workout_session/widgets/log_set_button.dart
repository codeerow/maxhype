import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

class LogSetButton extends StatelessWidget {
  final bool enabled;
  final bool isAwaitingDoneConfirmation;
  final VoidCallback onTap;

  const LogSetButton({
    super.key,
    required this.enabled,
    required this.isAwaitingDoneConfirmation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final label = isAwaitingDoneConfirmation ? 'Done' : 'Log Set';
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Opacity(
          opacity: enabled ? 1.0 : 0.5,
          child: TapScale(
            scaleDown: 0.96,
            enableHaptic: true,
            onTap: enabled ? onTap : null,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: AppTheme.primaryOrange,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryOrange.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
