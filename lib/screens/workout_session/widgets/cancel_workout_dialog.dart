import 'package:flutter/cupertino.dart';

/// Native iOS-style confirmation dialog for cancelling a workout. Returns
/// true if the user confirmed.
Future<bool> showCancelWorkoutDialog(BuildContext context) async {
  final result = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => CupertinoAlertDialog(
      title: const Text('Cancel workout'),
      content: const Text('Are you sure you want to cancel the workout?'),
      actions: [
        CupertinoDialogAction(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('No'),
        ),
        CupertinoDialogAction(
          isDestructiveAction: true,
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Yes'),
        ),
      ],
    ),
  );
  return result ?? false;
}
