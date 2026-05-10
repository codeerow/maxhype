import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

class ActionChipRow extends StatelessWidget {
  /// Rest duration in seconds; rendered into the leading chip as `M:SS`.
  final int restSeconds;
  final VoidCallback onRestTap;
  final VoidCallback onInstructionTap;
  final VoidCallback onAnalyticsTap;

  const ActionChipRow({
    super.key,
    required this.restSeconds,
    required this.onRestTap,
    required this.onInstructionTap,
    required this.onAnalyticsTap,
  });

  @override
  Widget build(BuildContext context) {
    final mins = restSeconds ~/ 60;
    final secs = restSeconds % 60;
    final restLabel = '$mins:${secs.toString().padLeft(2, '0')}';

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _Chip(
            onTap: onRestTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Rest ',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  restLabel,
                  style: const TextStyle(
                    color: AppTheme.recoveryGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _Chip(
            onTap: onInstructionTap,
            child: const Text(
              'Instruction',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _Chip(
            onTap: onAnalyticsTap,
            child: const Text(
              'Analytics',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  const _Chip({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scaleDown: 0.96,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      ),
    );
  }
}
