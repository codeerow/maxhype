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
      elevation: 0,
      centerTitle: true,
      leading: TapScale(
        scaleDown: 0.90,
        onTap: onBack,
        child: const Center(
          child: Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        ),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.headlineSmall,
      ),
      actions: [
        SizedBox(
          width: 56,
          child: TapScale(
            scaleDown: 0.90,
            onTap: onCancel,
            child: const Center(
              child: Icon(Icons.close, color: AppTheme.recoveryRed),
            ),
          ),
        ),
      ],
    );
  }
}
