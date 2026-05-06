import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

class AddSetButton extends StatelessWidget {
  final VoidCallback onTap;
  const AddSetButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TapScale(
      scaleDown: 0.97,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: AppTheme.textSecondary.withValues(alpha: 0.4),
            width: 1.2,
            style: BorderStyle.solid,
          ),
        ),
        child: const Center(
          child: Text(
            '+ Add Set',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
