import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';

/// Standard swipe-to-delete wrapper used for set rows, warmup row, and
/// exercise cards. Solid red background + delete icon, native Flutter
/// Dismissible behavior — no custom animation.
class SwipeToDelete extends StatelessWidget {
  final Key dismissKey;
  final Widget child;
  final VoidCallback onDismissed;
  final BorderRadius borderRadius;

  const SwipeToDelete({
    super.key,
    required this.dismissKey,
    required this.child,
    required this.onDismissed,
    this.borderRadius = const BorderRadius.all(Radius.circular(10)),
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: dismissKey,
      direction: DismissDirection.endToStart,
      background: Container(
        decoration: BoxDecoration(
          color: AppTheme.recoveryRed,
          borderRadius: borderRadius,
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      onDismissed: (_) => onDismissed(),
      child: child,
    );
  }
}
