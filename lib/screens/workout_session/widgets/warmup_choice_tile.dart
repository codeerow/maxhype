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
      scaleDown: 0.98,
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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in WarmupType.values)
              ListTile(
                title: Text(
                  t.displayName,
                  style: TextStyle(
                    color: t == current
                        ? AppTheme.recoveryGreen
                        : AppTheme.textPrimary,
                    fontWeight:
                        t == current ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                trailing: t == current
                    ? const Icon(Icons.check, color: AppTheme.recoveryGreen)
                    : null,
                onTap: () {
                  onSelected(t);
                  Navigator.of(ctx).pop();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
