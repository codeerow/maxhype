import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

class SessionFinishButton extends StatelessWidget {
  final VoidCallback onTap;

  const SessionFinishButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: TapScale(
          scaleDown: 0.96,
          enableHaptic: true,
          onTap: onTap,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.finishMaroon,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Finish',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
