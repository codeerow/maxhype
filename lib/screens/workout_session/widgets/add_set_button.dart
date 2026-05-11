import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

/// Round "+" icon followed by an "Add Set" label in the accent colour.
///
/// Tap = +1 set. Long-press opens a Cupertino picker for adding multiple
/// sets at once (3 / 5 / 10).
class AddSetButton extends StatelessWidget {
  final VoidCallback onAddOne;
  final ValueChanged<int> onAddMany;

  const AddSetButton({
    super.key,
    required this.onAddOne,
    required this.onAddMany,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: () => _showPicker(context),
      child: TapScale(
        scaleDown: 0.96,
        onTap: onAddOne,
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
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Add multiple sets'),
        actions: [
          for (final count in const [3, 5, 10])
            CupertinoActionSheetAction(
              onPressed: () {
                Navigator.of(ctx).pop();
                onAddMany(count);
              },
              child: Text('Add $count sets'),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
