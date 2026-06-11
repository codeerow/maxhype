import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../models/session/session_warmup_type.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/tap_scale.dart';

class WarmupChoiceTile extends StatelessWidget {
  final WarmupType current;
  final ValueChanged<WarmupType> onSelected;

  const WarmupChoiceTile({
    super.key,
    required this.current,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasChoice = current != WarmupType.none;

    return TapScale(
      scaleDown: TapScalePreset.surface.scale,
      onTap: () => _showPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.recoveryGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.directions_run,
                color: AppTheme.recoveryGreen,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasChoice ? current.displayName : 'Choose warm-up',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Treadmill · Stationary Bike · Elliptical',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (ctx) => CupertinoActionSheet(
        title: const Text('Choose warm-up'),
        actions: [
          for (final t in WarmupType.values)
            CupertinoActionSheetAction(
              isDefaultAction: t == current,
              onPressed: () {
                onSelected(t);
                Navigator.of(ctx).pop();
              },
              child: Text(t.displayName),
            ),
        ],
        cancelButton: CupertinoActionSheetAction(
          isDestructiveAction: false,
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
      ),
    );
  }
}
