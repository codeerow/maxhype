import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// Round "+" icon followed by an "Add Set" label in the accent colour, per
/// the design ref.
class AddSetButton extends StatelessWidget {
  final VoidCallback onTap;
  const AddSetButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scaleDown: 0.96,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: AppTheme.cardBackground,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add,
                color: AppTheme.recoveryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Add Set',
              style: TextStyle(
                color: AppTheme.recoveryGreen,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
