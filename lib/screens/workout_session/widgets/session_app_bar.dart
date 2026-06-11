import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

class SessionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final VoidCallback onBack;
  final VoidCallback onCancel;

  const SessionAppBar({
    super.key,
    required this.title,
    required this.onBack,
    required this.onCancel,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppTheme.backgroundColor,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      leading: TapScale(
        scaleDown: TapScalePreset.icon.scale,
        onTap: onBack,
        child: const Center(
          child: Icon(
            CupertinoIcons.back,
            color: AppTheme.primaryOrange,
            size: 26,
          ),
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
      ),
      actions: [
        SizedBox(
          width: 56,
          child: TapScale(
            scaleDown: TapScalePreset.icon.scale,
            onTap: onCancel,
            child: const Center(
              child: Icon(
                CupertinoIcons.xmark,
                color: AppTheme.recoveryRed,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
